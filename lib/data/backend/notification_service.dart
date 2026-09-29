import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart'
    hide NotificationSettings;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';
import '../models/user_model.dart';

/// Everything [NotificationService.syncSchedules] needs to plan reminders.
class ScheduleInputs {
  const ScheduleInputs({
    required this.tasks,
    required this.settings,
    required this.streak,
    required this.activeToday,
  });

  final List<TaskModel> tasks;
  final NotificationSettings settings;
  final int streak;
  final bool activeToday;
}

class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  /// Tapping an overdue reminder (or its Reschedule action) → task id.
  void Function(String taskId)? onReschedule;

  /// Evening wrap-up "Roll over" action.
  void Function()? onRollover;

  /// Plain tap on a task reminder.
  void Function(String taskId)? onOpenTask;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  final _readyCompleter = Completer<void>();

  /// Completes once local notifications are initialised.
  Future<void> get ready => _readyCompleter.future;

  // Fixed ids. Task reminders use a hashed range above these.
  static const _idBriefing = 1001;
  static const _idWrapUp = 1002;
  static const _idStreakRisk = 2001;
  static const _idMilestone = 2002;
  static const _idWeekly = 3001;
  static const _idFocus = 4001;
  static const _idEngagement = 9999;

  static const _milestones = [7, 14, 30, 60, 100];

  Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      final name = DateTime.now().timeZoneName;
      tz.setLocalLocation(_resolveLocation(name));
    } catch (_) {
      // Falls back to UTC offsets via TZDateTime.from(DateTime) below.
    }

    final settings = await _fcm.requestPermission();
    log('Notification permission: ${settings.authorizationStatus}');

    final iosCategory = DarwinNotificationCategory(
      'task_actions',
      actions: [
        DarwinNotificationAction.plain('reschedule', 'Move to tomorrow'),
        DarwinNotificationAction.plain('rollover', 'Roll over'),
      ],
    );

    await _local.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          notificationCategories: [iosCategory],
        ),
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );
    _ready = true;
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();

    FirebaseMessaging.onMessage.listen(_showRemote);
    try {
      // Throws on simulators and before APNs has issued a token; push is
      // optional, local reminders don't depend on it.
      log('FCM Token: ${await _fcm.getToken()}');
    } catch (e) {
      log('FCM token unavailable: $e');
    }
  }

  tz.Location _resolveLocation(String abbreviation) {
    final offset = DateTime.now().timeZoneOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      final zone = loc.currentTimeZone;
      if (zone.offset == offset.inMilliseconds &&
          zone.abbreviation == abbreviation) {
        return loc;
      }
    }
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == offset.inMilliseconds) return loc;
    }
    return tz.UTC;
  }

  Future<void> _showRemote(RemoteMessage message) async {
    await _local.show(
      message.notification.hashCode,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_reminders',
          'Todo Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ───────────────────────── Planning ─────────────────────────────────────

  String? _lastSignature;

  /// Cancels and re-plans every scheduled reminder from the current state.
  /// Cheap to call on every task change: it no-ops when nothing relevant moved.
  Future<void> syncSchedules(ScheduleInputs input) async {
    if (!_ready) return;
    final s = input.settings;
    final open =
        input.tasks.where((t) => !t.isCompleted && !t.isArchived).toList();

    final signature = [
      s.toMap().toString(),
      input.streak,
      input.activeToday,
      DateFormat('yyyyMMddHH').format(DateTime.now()),
      for (final t in open) '${t.id}@${t.dueDate.millisecondsSinceEpoch}',
    ].join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    final pending = await _local.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id != _idFocus) await _local.cancel(p.id);
    }
    _budget.clear();

    // 1. Per-task reminders (grouped when several share an hour).
    if (s.dueSoon || s.overdue) {
      final groups = <String, List<TaskModel>>{};
      for (final t in open) {
        groups
            .putIfAbsent(
                DateFormat('yyyy-MM-dd HH').format(t.dueDate), () => [])
            .add(t);
      }
      for (final entry in groups.entries) {
        final tasks = entry.value;
        if (tasks.length > 1 && s.dueSoon) {
          final first = tasks.first;
          await _schedule(
            id: _taskId(entry.key),
            title: '${tasks.length} tasks due soon',
            body: tasks.map((t) => t.title).take(3).join(' · '),
            at: first.dueDate.subtract(const Duration(minutes: 30)),
            priority: Priority.high,
            type: 'due_soon',
          );
        }
        for (final t in tasks) {
          await _scheduleTask(t,
              dueSoon: s.dueSoon && tasks.length == 1, overdue: s.overdue);
        }
      }
    }

    final now = DateTime.now();
    final todayTasks = input.tasks
        .where((t) =>
            !t.isArchived &&
            t.dueDate.year == now.year &&
            t.dueDate.month == now.month &&
            t.dueDate.day == now.day)
        .toList();

    // 2. Morning briefing, 08:00.
    if (s.morningBriefing) {
      final at = _nextAt(8);
      final day = input.tasks.where((t) =>
          !t.isCompleted &&
          !t.isArchived &&
          t.dueDate.year == at.year &&
          t.dueDate.month == at.month &&
          t.dueDate.day == at.day);
      final overdue = open.where((t) => t.dueDate.isBefore(at)).length;
      if (day.isNotEmpty || overdue > 0) {
        await _schedule(
          id: _idBriefing,
          title: 'Morning briefing',
          body: '${day.length} task${day.length == 1 ? '' : 's'} today'
              '${overdue > 0 ? ' · $overdue overdue' : ''}. Start strong.',
          at: at,
          priority: Priority.defaultPriority,
          type: 'briefing',
        );
      }
    }

    // 3. Evening wrap-up, 20:00 (opt-in).
    if (s.eveningWrapUp && todayTasks.isNotEmpty) {
      final done = todayTasks.where((t) => t.isCompleted).length;
      await _schedule(
        id: _idWrapUp,
        title: 'Evening wrap-up',
        body: 'You completed $done of ${todayTasks.length} today.'
            '${done < todayTasks.length ? ' Roll the rest over to tomorrow?' : ' Clean sweep.'}',
        at: _nextAt(20),
        priority: Priority.low,
        type: 'wrapup',
        payload: 'rollover',
        quietHours: false,
      );
    }

    // 4. Streak at risk, 21:00 today if nothing logged yet.
    if (s.streakAtRisk && input.streak > 0 && !input.activeToday) {
      final at = DateTime(now.year, now.month, now.day, 21);
      if (at.isAfter(now)) {
        await _schedule(
          id: _idStreakRisk,
          title: 'Streak at risk',
          body: 'Your ${input.streak}-day streak ends at midnight. '
              'One task or habit keeps it alive.',
          at: at,
          priority: Priority.high,
          type: 'streak_at_risk',
          quietHours: false,
        );
      }
    }

    // 5. Weekly review, Sunday 19:00.
    if (s.weeklyReview) {
      var days = (DateTime.sunday - now.weekday) % 7;
      if (days == 0 && now.hour >= 19) days = 7;
      final at = DateTime(now.year, now.month, now.day + days, 19);
      final weekStart = at.subtract(const Duration(days: 7));
      final done = input.tasks
          .where((t) =>
              t.isCompleted && (t.completedAt ?? t.dueDate).isAfter(weekStart))
          .length;
      await _schedule(
        id: _idWeekly,
        title: 'Weekly review ready',
        body: 'You completed $done task${done == 1 ? '' : 's'} this week. '
            'See where the momentum came from.',
        at: at,
        priority: Priority.low,
        type: 'weekly_review',
      );
    }
  }

  Future<void> _scheduleTask(TaskModel t,
      {required bool dueSoon, required bool overdue}) async {
    final time = DateFormat.jm();
    if (dueSoon) {
      await _schedule(
        id: _taskId(t.id),
        title: '${t.title} in 30 min',
        body: 'Due at ${time.format(t.dueDate)} · ${t.priority} priority',
        at: t.dueDate.subtract(const Duration(minutes: 30)),
        priority: Priority.high,
        type: 'due_soon',
        payload: 'task:${t.id}',
      );
    }
    if (overdue) {
      await _schedule(
        id: _taskId(t.id) + 1,
        title: 'Past due: ${t.title}',
        body:
            'Was due at ${time.format(t.dueDate)} · tap to move it to tomorrow',
        at: t.dueDate.add(const Duration(minutes: 15)),
        priority: Priority.max,
        type: 'overdue',
        payload: 'task:${t.id}',
      );
    }
  }

  /// Keep task ids clear of the fixed ids above.
  int _taskId(String key) =>
      100000 + (key.hashCode & 0x3fffffff) * 2 % 900000000;

  DateTime _nextAt(int hour) {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, hour);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  // ───────────────────────── Immediate / focus ────────────────────────────

  Future<void> scheduleFocusEnd(DateTime at) async {
    if (!_ready) return;
    await _local.cancel(_idFocus);
    await _local.zonedSchedule(
      _idFocus,
      'Focus session complete',
      'Nice work. Take five, then go again.',
      tz.TZDateTime.from(at, tz.local),
      _details(Priority.high),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelFocusEnd() async {
    if (_ready) await _local.cancel(_idFocus);
  }

  Future<void> celebrateStreakMilestone(int streak) async {
    if (!_ready || !_milestones.contains(streak)) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notif.streakMilestone') ?? true)) return;
    final key = 'milestone_shown_$streak';
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    await _local.show(
      _idMilestone,
      '$streak-day streak',
      "That's a habit now. Keep the chain going.",
      _details(Priority.low),
    );
  }

  /// Mirrors the Firestore settings locally so background code can read them.
  Future<void> cacheSettings(NotificationSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif.streakMilestone', s.streakMilestone);
    await prefs.setBool('evening_wrapup_enabled', s.eveningWrapUp);
  }

  // ───────────────────────── Plumbing ─────────────────────────────────────

  /// Per-firing-day budget for non-critical notifications (max 3/day).
  final Map<String, int> _budget = {};

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required Priority priority,
    required String type,
    String? payload,
    bool quietHours = true,
  }) async {
    var fireAt = quietHours ? _adjustForQuietHours(at) : at;
    if (!fireAt.isAfter(DateTime.now())) return;

    if (type != 'overdue') {
      final day = DateFormat('yyyy-MM-dd').format(fireAt);
      final used = _budget[day] ?? 0;
      if (used >= 3 || !await _engaged(priority)) return;
      _budget[day] = used + 1;
    }

    await _local.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fireAt, tz.local),
      _details(priority, actions: payload != null),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  NotificationDetails _details(Priority priority, {bool actions = false}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_advanced',
          'Reminders',
          channelDescription: 'Task, streak and focus reminders',
          importance: priority == Priority.max
              ? Importance.max
              : priority == Priority.high
                  ? Importance.high
                  : Importance.defaultImportance,
          priority: priority,
          groupKey: 'com.kshitijcodecraft.tasktrackr.TASK_GROUP',
          actions: actions
              ? const [
                  AndroidNotificationAction('reschedule', 'Move to tomorrow',
                      showsUserInterface: true),
                ]
              : null,
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: 'task_group',
          categoryIdentifier: actions ? 'task_actions' : null,
        ),
      );

  DateTime _adjustForQuietHours(DateTime time) {
    if (time.hour >= 22)
      return DateTime(time.year, time.month, time.day + 1, 8);
    if (time.hour < 8) return DateTime(time.year, time.month, time.day, 8);
    return time;
  }

  /// If the user hasn't tapped a notification in two weeks, ask once and
  /// then only send high-priority ones.
  Future<bool> _engaged(Priority priority) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTap = prefs.getString('last_notif_tap');
    if (lastTap == null) {
      await prefs.setString('last_notif_tap', DateTime.now().toIso8601String());
      return true;
    }
    if (DateTime.now().difference(DateTime.parse(lastTap)).inDays <= 14) {
      return true;
    }
    if (!(prefs.getBool('asked_engagement') ?? false)) {
      await prefs.setBool('asked_engagement', true);
      await _local.zonedSchedule(
        _idEngagement,
        'Still want these reminders?',
        'Open TaskTrackr to keep them, or turn them down in Notifications.',
        tz.TZDateTime.from(
            DateTime.now().add(const Duration(hours: 1)), tz.local),
        _details(Priority.defaultPriority),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    return priority.value >= Priority.high.value;
  }

  Future<void> _handleResponse(NotificationResponse r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_notif_tap', DateTime.now().toIso8601String());
    await prefs.setBool('asked_engagement', false);

    final payload = r.payload ?? '';
    final action = r.actionId;
    if (action == 'rollover' || (action == null && payload == 'rollover')) {
      onRollover?.call();
    } else if (payload.startsWith('task:')) {
      final id = payload.substring(5);
      if (action == 'reschedule') {
        onReschedule?.call(id);
      } else {
        onOpenTask?.call(id);
      }
    }
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    log('Handling a background message: ${message.messageId}');
  }
}
