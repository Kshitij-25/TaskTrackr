import 'dart:async';
import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/backend/notification_service.dart';
import '../../data/repositories/momentum_repository.dart';
import 'auth_user_provider.dart';
import 'theme_provider.dart';

/// XP, levels, streaks, quests, badges, habits and focus sessions.
/// Offline-first: everything is written locally first, then mirrored to
/// Firestore so it follows the user across devices. A streak never breaks
/// because of a failed request.

const xpPerLevel = 1600;
const levelNames = [
  'Drifter',
  'Starter',
  'Builder',
  'Operator',
  'Compounder',
  'Keeper',
  'Flow Architect',
];

String dayKey(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Per-user cloud mirror; null while signed out.
final momentumRepositoryProvider = Provider<MomentumRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  final repo = MomentumRepository(uid);
  ref.onDispose(repo.dispose);
  return repo;
});

String _key(String? uid, String key) => 'm.${uid ?? 'local'}.$key';

Map<String, int> _intMap(Object? m) => (m as Map? ?? const {})
    .map((k, v) => MapEntry(k as String, (v as num).toInt()));

Map<String, int> _maxMerge(Map<String, int> a, Map<String, int> b) {
  final out = Map<String, int>.from(a);
  b.forEach((k, v) {
    if (v > (out[k] ?? 0)) out[k] = v;
  });
  return out;
}

// ───────────────────────────── Gamification mode ───────────────────────────

/// full  — XP, bursts, level-up and badge celebrations.
/// quiet — XP and badges still count, celebrations become a quiet toast.
/// off   — no XP, levels, quests or badges. Streaks still count.
enum GamificationMode { full, quiet, off }

final gamificationProvider =
    StateNotifierProvider<GamificationNotifier, GamificationMode>(
  (ref) => GamificationNotifier(ref.watch(sharedPreferencesProvider)),
);

class GamificationNotifier extends StateNotifier<GamificationMode> {
  GamificationNotifier(this._prefs)
      : super(GamificationMode.values.firstWhere(
          (m) => m.name == _prefs.getString(_k),
          orElse: () => GamificationMode.full,
        ));

  static const _k = 'gamification_mode';
  final SharedPreferences _prefs;

  void set(GamificationMode mode) {
    state = mode;
    _prefs.setString(_k, mode.name);
  }
}

// ───────────────────────────── XP sources, quests, badges ──────────────────

/// What earned the XP. Only real work (task, habit, focus) keeps a streak
/// alive — capturing a task is planning, not doing.
enum XpSource {
  task(40, activity: true),
  habit(25, activity: true),
  focus(120, activity: true),
  capture(15, activity: false);

  const XpSource(this.xp, {required this.activity});
  final int xp;
  final bool activity;
}

class QuestDef {
  const QuestDef(this.id, this.title, this.xp, {this.daily = false});
  final String id;
  final String title;
  final int xp;

  /// Daily quests reset at midnight; others pay out once, ever.
  final bool daily;
}

const questDaily5 =
    QuestDef('daily5', 'Complete 5 tasks today', 150, daily: true);
const questStreak40 = QuestDef('streak40', 'Hold the streak for 40 days', 500);
const quests = [questDaily5, questStreak40];

class BadgeDef {
  const BadgeDef(this.id, this.label, this.how);
  final String id;
  final String label;
  final String how;
}

const badges = [
  BadgeDef('first_light', 'First Light', 'Complete your first task'),
  BadgeDef('week_one', 'Week One', 'Reach a 7-day streak'),
  BadgeDef('century', 'Century', 'Complete 100 tasks'),
  BadgeDef('deep_diver', 'Deep Diver', 'Focus 100 minutes in one day'),
  BadgeDef('level_5', 'Level 5', 'Reach level 5'),
  BadgeDef('habit_keeper', 'Habit Keeper', 'Hold any habit for 21 days'),
  BadgeDef('marathon', 'Marathon', 'Reach a 30-day streak'),
  BadgeDef('zero_inbox', 'Zero Inbox', 'Finish every open task'),
];

BadgeDef badgeById(String id) => badges.firstWhere((b) => b.id == id);

enum CelebrationKind { level, badge, quest }

/// The most recent thing worth celebrating. The shell shows it according to
/// the gamification mode, then clears it.
class Celebration {
  const Celebration(this.kind, this.title, this.subtitle);
  final CelebrationKind kind;
  final String title;
  final String subtitle;
}

// ───────────────────────────── State ───────────────────────────────────────

class MomentumState {
  const MomentumState({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.bestStreak = 0,
    this.xpByDay = const {},
    this.activityByDay = const {},
    this.tasksByDay = const {},
    this.tasksDone = 0,
    this.claimed = const {},
    this.unlocked = const {},
    this.celebration,
  });

  factory MomentumState.fromJson(Map<String, dynamic> j) {
    final xpByDay = _intMap(j['xpByDay']);
    return MomentumState(
      xp: (j['xp'] as num?)?.toInt() ?? 0,
      level: (j['level'] as num?)?.toInt() ?? 1,
      bestStreak: (j['bestStreak'] as num?)?.toInt() ?? 0,
      tasksDone: (j['tasksDone'] as num?)?.toInt() ?? 0,
      xpByDay: xpByDay,
      // v1 had no activity log: its streak was any-XP days, so seed from that
      // once rather than breaking existing streaks on upgrade.
      activityByDay: j.containsKey('activityByDay')
          ? _intMap(j['activityByDay'])
          : xpByDay.map((k, v) => MapEntry(k, v > 0 ? 1 : 0)),
      tasksByDay: _intMap(j['tasksByDay']),
      claimed: Set<String>.from(j['claimed'] as List? ?? const []),
      unlocked: Map<String, String>.from(j['unlocked'] as Map? ?? const {}),
    );
  }

  final int xp;
  final int level;
  final int streak;
  final int bestStreak;
  final int tasksDone;

  /// dayKey → XP earned that day (charts).
  final Map<String, int> xpByDay;

  /// dayKey → completed tasks + logged habits + finished focus sessions.
  /// This, not XP, is what keeps the streak alive.
  final Map<String, int> activityByDay;

  /// dayKey → tasks completed that day (daily quest).
  final Map<String, int> tasksByDay;

  /// Paid-out quest keys: 'streak40', or 'daily5:20260929' for daily ones.
  final Set<String> claimed;

  /// Badge id → dayKey it was earned. Kept forever once earned.
  final Map<String, String> unlocked;

  final Celebration? celebration;

  String get levelName => levelNames[level % levelNames.length];
  double get progress => (xp / xpPerLevel).clamp(0, 1).toDouble();
  int get totalXp => (level - 1) * xpPerLevel + xp;

  bool activeOn(DateTime d) => (activityByDay[dayKey(d)] ?? 0) > 0;
  bool get activeToday => activeOn(_today());
  int get tasksToday => tasksByDay[dayKey(_today())] ?? 0;

  bool isClaimed(QuestDef q) =>
      claimed.contains(q.daily ? '${q.id}:${dayKey(_today())}' : q.id);

  /// XP for each of the last 7 days, oldest first.
  List<int> get lastWeek {
    final t = _today();
    return List.generate(
        7, (i) => xpByDay[dayKey(t.subtract(Duration(days: 6 - i)))] ?? 0);
  }

  Map<String, dynamic> toJson() => {
        'v': 2,
        'xp': xp,
        'level': level,
        'bestStreak': bestStreak,
        'tasksDone': tasksDone,
        'xpByDay': xpByDay,
        'activityByDay': activityByDay,
        'tasksByDay': tasksByDay,
        'claimed': claimed.toList(),
        'unlocked': unlocked,
      };

  /// Higher value / union wins everywhere, so neither device loses progress.
  MomentumState merge(MomentumState o) {
    final useOther = o.totalXp > totalXp;
    return MomentumState(
      xp: useOther ? o.xp : xp,
      level: useOther ? o.level : level,
      bestStreak: o.bestStreak > bestStreak ? o.bestStreak : bestStreak,
      tasksDone: o.tasksDone > tasksDone ? o.tasksDone : tasksDone,
      xpByDay: _maxMerge(xpByDay, o.xpByDay),
      activityByDay: _maxMerge(activityByDay, o.activityByDay),
      tasksByDay: _maxMerge(tasksByDay, o.tasksByDay),
      claimed: {...claimed, ...o.claimed},
      unlocked: {...o.unlocked, ...unlocked},
    );
  }

  MomentumState copyWith({
    int? xp,
    int? level,
    int? streak,
    int? bestStreak,
    int? tasksDone,
    Map<String, int>? xpByDay,
    Map<String, int>? activityByDay,
    Map<String, int>? tasksByDay,
    Set<String>? claimed,
    Map<String, String>? unlocked,
    Celebration? celebration,
    bool clearCelebration = false,
  }) =>
      MomentumState(
        xp: xp ?? this.xp,
        level: level ?? this.level,
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        tasksDone: tasksDone ?? this.tasksDone,
        xpByDay: xpByDay ?? this.xpByDay,
        activityByDay: activityByDay ?? this.activityByDay,
        tasksByDay: tasksByDay ?? this.tasksByDay,
        claimed: claimed ?? this.claimed,
        unlocked: unlocked ?? this.unlocked,
        celebration:
            clearCelebration ? null : (celebration ?? this.celebration),
      );
}

final momentumProvider =
    StateNotifierProvider<MomentumNotifier, MomentumState>((ref) {
  return MomentumNotifier(
    ref.watch(sharedPreferencesProvider),
    ref.watch(currentUidProvider),
    ref.watch(momentumRepositoryProvider),
    () => ref.read(gamificationProvider),
  );
});

class MomentumNotifier extends StateNotifier<MomentumState> {
  MomentumNotifier(this._prefs, this._uid, this._cloud, this._mode)
      : super(const MomentumState()) {
    final raw = _prefs.getString(_key(_uid, 'momentum'));
    if (raw != null) {
      state = MomentumState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    _refreshStreak();
    _pull();
  }

  final SharedPreferences _prefs;
  final String? _uid;
  final MomentumRepository? _cloud;
  final GamificationMode Function() _mode;

  bool get _xpOn => _mode() != GamificationMode.off;

  Future<void> _pull() async {
    final remote = await _cloud?.fetch();
    final stats = remote?['stats'];
    if (!mounted || stats is! Map) return;
    state =
        state.merge(MomentumState.fromJson(Map<String, dynamic>.from(stats)));
    _refreshStreak();
    _save();
  }

  /// Records the work and banks its XP. Returns the XP actually granted
  /// (0 when gamification is off) so callers can word their toast.
  int award(XpSource source) {
    final today = dayKey(_today());
    if (source.activity) {
      state = state.copyWith(
        activityByDay: Map.of(state.activityByDay)
          ..update(today, (v) => v + 1, ifAbsent: () => 1),
      );
    }
    if (source == XpSource.task) {
      state = state.copyWith(
        tasksDone: state.tasksDone + 1,
        tasksByDay: Map.of(state.tasksByDay)
          ..update(today, (v) => v + 1, ifAbsent: () => 1),
      );
    }
    final granted = _xpOn ? source.xp : 0;
    if (granted > 0) _addXp(granted);

    final before = state.streak;
    _refreshStreak();
    if (state.streak > before) {
      NotificationService().celebrateStreakMilestone(state.streak);
    }
    _evaluate();
    _save();
    return granted;
  }

  /// Undo (e.g. un-completing a task). Never drops a level, never takes back
  /// a paid quest or an earned badge.
  void revoke(XpSource source) {
    final today = dayKey(_today());
    int dec(int v) => v > 0 ? v - 1 : 0;
    if (source.activity) {
      state = state.copyWith(
        activityByDay: Map.of(state.activityByDay)
          ..update(today, dec, ifAbsent: () => 0),
      );
    }
    if (source == XpSource.task) {
      state = state.copyWith(
        tasksDone: dec(state.tasksDone),
        tasksByDay: Map.of(state.tasksByDay)
          ..update(today, dec, ifAbsent: () => 0),
      );
    }
    if (_xpOn) {
      final byDay = Map.of(state.xpByDay);
      byDay[today] = ((byDay[today] ?? 0) - source.xp).clamp(0, 1 << 30);
      state = state.copyWith(
        xp: (state.xp - source.xp).clamp(0, xpPerLevel),
        xpByDay: byDay,
      );
    }
    _refreshStreak();
    _save();
  }

  /// Unlock a badge whose condition lives outside this notifier
  /// (habit streaks, focus minutes, the task list).
  void unlock(String badgeId) {
    if (state.unlocked.containsKey(badgeId)) return;
    _unlock(badgeId);
    _save();
  }

  void clearCelebration() => state = state.copyWith(clearCelebration: true);

  void _addXp(int amount) {
    final today = dayKey(_today());
    var xp = state.xp + amount;
    var level = state.level;
    var levelled = false;
    while (xp >= xpPerLevel) {
      xp -= xpPerLevel;
      level += 1;
      levelled = true;
    }
    state = state.copyWith(
      xp: xp,
      level: level,
      xpByDay: Map.of(state.xpByDay)
        ..update(today, (v) => v + amount, ifAbsent: () => amount),
      celebration: levelled
          ? Celebration(CelebrationKind.level, 'Level $level',
              '${levelNames[level % levelNames.length]} unlocked')
          : null,
    );
  }

  /// Pays out finished quests and unlocks badges this notifier can judge.
  void _evaluate() {
    if (!_xpOn) return;
    final today = dayKey(_today());

    void pay(QuestDef q) {
      final key = q.daily ? '${q.id}:$today' : q.id;
      if (state.claimed.contains(key)) return;
      state = state.copyWith(claimed: {...state.claimed, key});
      _addXp(q.xp);
      // A level-up from the payout outranks the quest banner.
      if (state.celebration?.kind != CelebrationKind.level) {
        state = state.copyWith(
          celebration: Celebration(CelebrationKind.quest, 'Quest complete',
              '${q.title} · +${q.xp} XP'),
        );
      }
    }

    if (state.tasksToday >= 5) pay(questDaily5);
    if (state.streak >= 40) pay(questStreak40);

    if (state.tasksDone >= 1) _unlock('first_light');
    if (state.bestStreak >= 7) _unlock('week_one');
    if (state.tasksDone >= 100) _unlock('century');
    if (state.level >= 5) _unlock('level_5');
    if (state.bestStreak >= 30) _unlock('marathon');
  }

  void _unlock(String id) {
    if (state.unlocked.containsKey(id)) return;
    final b = badgeById(id);
    state = state.copyWith(
      unlocked: {...state.unlocked, id: dayKey(_today())},
      celebration: state.celebration?.kind == CelebrationKind.level
          ? null
          : Celebration(CelebrationKind.badge, b.label, b.how),
    );
  }

  void _refreshStreak() {
    var d = _today();
    // Today still counts as "alive" until midnight even before any work.
    if (!state.activeOn(d)) d = d.subtract(const Duration(days: 1));
    var streak = 0;
    while (state.activeOn(d)) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    state = state.copyWith(
      streak: streak,
      bestStreak: streak > state.bestStreak ? streak : state.bestStreak,
    );
  }

  void _save() {
    final json = state.toJson();
    _prefs.setString(_key(_uid, 'momentum'), jsonEncode(json));
    _cloud?.save('stats', json);
  }
}

// ───────────────────────────── Habits ──────────────────────────────────────

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.short,
    required this.goal,
    this.log = const {},
    this.deleted = false,
  });

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'],
        name: j['name'],
        short: j['short'],
        goal: j['goal'] ?? 'Daily',
        log: Set<String>.from(j['log'] ?? const []),
        deleted: j['deleted'] ?? false,
      );

  final String id;
  final String name;
  final String short;
  final String goal;

  /// dayKeys this habit was logged on.
  final Set<String> log;

  /// Tombstone so a delete on one device isn't undone by another's merge.
  final bool deleted;

  bool get doneToday => log.contains(dayKey(_today()));

  int get streak {
    var d = _today();
    if (!log.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (log.contains(dayKey(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Last 7 days, oldest first.
  List<bool> get week {
    final t = _today();
    return List.generate(
        7, (i) => log.contains(dayKey(t.subtract(Duration(days: 6 - i)))));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'short': short,
        'goal': goal,
        'log': log.toList(),
        if (deleted) 'deleted': true,
      };

  Habit copyWith({Set<String>? log, bool? deleted}) => Habit(
        id: id,
        name: name,
        short: short,
        goal: goal,
        log: log ?? this.log,
        deleted: deleted ?? this.deleted,
      );
}

const _starterHabits = [
  Habit(
      id: 'move',
      name: 'Move for 30 minutes',
      short: 'Move',
      goal: 'Daily · 30m'),
  Habit(
      id: 'read',
      name: 'Read before bed',
      short: 'Read',
      goal: 'Daily · 20 pages'),
  Habit(
      id: 'deep',
      name: 'Two hours of deep work',
      short: 'Deep',
      goal: 'Weekdays · 2h'),
  Habit(
      id: 'water',
      name: 'Eight glasses of water',
      short: 'Water',
      goal: 'Daily · 8×'),
];

/// Visible habits (tombstones filtered out).
final habitsProvider = Provider<List<Habit>>(
  (ref) => ref.watch(_habitStoreProvider).where((h) => !h.deleted).toList(),
);

final habitActionsProvider = Provider<HabitsNotifier>(
  (ref) => ref.watch(_habitStoreProvider.notifier),
);

final _habitStoreProvider =
    StateNotifierProvider<HabitsNotifier, List<Habit>>((ref) {
  return HabitsNotifier(
    ref.watch(sharedPreferencesProvider),
    ref.watch(currentUidProvider),
    ref.watch(momentumRepositoryProvider),
  );
});

class HabitsNotifier extends StateNotifier<List<Habit>> {
  HabitsNotifier(this._prefs, this._uid, this._cloud) : super(_starterHabits) {
    final raw = _prefs.getString(_key(_uid, 'habits'));
    if (raw != null) state = _decode(jsonDecode(raw));
    _pull();
  }

  final SharedPreferences _prefs;
  final String? _uid;
  final MomentumRepository? _cloud;

  static List<Habit> _decode(Object? list) => (list as List)
      .map((e) => Habit.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  Future<void> _pull() async {
    final remote = await _cloud?.fetch();
    final list = remote?['habits'];
    if (!mounted || list is! List) return;
    final byId = {for (final h in state) h.id: h};
    for (final r in _decode(list)) {
      final l = byId[r.id];
      byId[r.id] = l == null
          ? r
          : l.copyWith(
              log: {...l.log, ...r.log}, deleted: l.deleted || r.deleted);
    }
    state = byId.values.toList();
    _save();
  }

  /// Returns the new done state.
  bool toggleToday(String id) {
    final key = dayKey(_today());
    final nowDone = !state.firstWhere((h) => h.id == id).doneToday;
    state = [
      for (final h in state)
        if (h.id == id)
          h.copyWith(
              log: nowDone
                  ? (Set.of(h.log)..add(key))
                  : (Set.of(h.log)..remove(key)))
        else
          h,
    ];
    _save();
    return nowDone;
  }

  void add(String name, String goal) {
    final short = name.trim().split(' ').first;
    state = [
      ...state,
      Habit(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        short: short.length > 6 ? short.substring(0, 6) : short,
        goal: goal.trim().isEmpty ? 'Daily' : goal.trim(),
      ),
    ];
    _save();
  }

  void remove(String id) {
    state = [
      for (final h in state) h.id == id ? h.copyWith(deleted: true) : h,
    ];
    _save();
  }

  void restore(String id) {
    state = [
      for (final h in state) h.id == id ? h.copyWith(deleted: false) : h,
    ];
    _save();
  }

  void _save() {
    final json = state.map((h) => h.toJson()).toList();
    _prefs.setString(_key(_uid, 'habits'), jsonEncode(json));
    _cloud?.save('habits', json);
  }
}

/// Completions per day across all habits for the last 18 weeks (126 cells),
/// oldest first.
final habitHeatmapProvider = Provider<List<int>>((ref) {
  final habits = ref.watch(habitsProvider);
  final t = _today();
  return List.generate(126, (i) {
    final k = dayKey(t.subtract(Duration(days: 125 - i)));
    return habits.where((h) => h.log.contains(k)).length;
  });
});

// ───────────────────────────── Focus timer ─────────────────────────────────

const focusLength = 25 * 60;
final focusXp = XpSource.focus.xp;

class FocusState {
  const FocusState({
    this.left = focusLength,
    this.running = false,
    this.sessionsToday = 0,
    this.minutesToday = 0,
    this.taskId,
    this.minutesByDay = const {},
  });

  final int left;
  final bool running;
  final int sessionsToday;
  final int minutesToday;
  final String? taskId;

  /// dayKey → focus minutes. Feeds Insights.
  final Map<String, int> minutesByDay;

  bool get fresh => left == focusLength && !running;

  FocusState copyWith({
    int? left,
    bool? running,
    int? sessionsToday,
    int? minutesToday,
    String? taskId,
    bool clearTask = false,
    Map<String, int>? minutesByDay,
  }) =>
      FocusState(
        left: left ?? this.left,
        running: running ?? this.running,
        sessionsToday: sessionsToday ?? this.sessionsToday,
        minutesToday: minutesToday ?? this.minutesToday,
        taskId: clearTask ? null : (taskId ?? this.taskId),
        minutesByDay: minutesByDay ?? this.minutesByDay,
      );
}

final focusProvider = StateNotifierProvider<FocusNotifier, FocusState>((ref) {
  return FocusNotifier(
    ref,
    ref.watch(sharedPreferencesProvider),
    ref.watch(currentUidProvider),
    ref.watch(momentumRepositoryProvider),
  );
});

/// Runs off a wall-clock end time, so the countdown stays correct while the
/// app is backgrounded or even killed; a local notification fires at the end.
class FocusNotifier extends StateNotifier<FocusState> {
  FocusNotifier(this._ref, this._prefs, this._uid, this._cloud)
      : super(const FocusState()) {
    _load();
    _pull();
  }

  final Ref _ref;
  final SharedPreferences _prefs;
  final String? _uid;
  final MomentumRepository? _cloud;
  Timer? _timer;
  DateTime? _endsAt;

  /// Fires when a session completes; the UI listens to celebrate.
  void Function()? onComplete;

  String get _runKey => _key(_uid, 'focus.run');

  void _load() {
    final raw = _prefs.getString(_key(_uid, 'focus.days'));
    final byDay = raw == null
        ? <String, int>{}
        : (jsonDecode(raw) as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    final sessions =
        _prefs.getInt(_key(_uid, 'focus.s.${dayKey(_today())}')) ?? 0;
    state = FocusState(
      minutesByDay: byDay,
      minutesToday: byDay[dayKey(_today())] ?? 0,
      sessionsToday: sessions,
    );

    // Resume a session that was running when the app went away.
    final run = _prefs.getString(_runKey);
    if (run != null) {
      final j = jsonDecode(run) as Map<String, dynamic>;
      final taskId = j['taskId'] as String?;
      if (j['endsAt'] != null) {
        _endsAt = DateTime.fromMillisecondsSinceEpoch(j['endsAt'] as int);
        state = state.copyWith(taskId: taskId, running: true);
        _startTicker();
        _tick();
      } else if (j['left'] != null) {
        state = state.copyWith(taskId: taskId, left: j['left'] as int);
      }
    }
  }

  Future<void> _pull() async {
    final remote = await _cloud?.fetch();
    final days = remote?['focusMinutes'];
    if (!mounted || days is! Map) return;
    final merged = Map<String, int>.from(state.minutesByDay);
    days.forEach((k, v) {
      final n = (v as num).toInt();
      if (n > (merged[k] ?? 0)) merged[k] = n;
    });
    state = state.copyWith(
      minutesByDay: merged,
      minutesToday: merged[dayKey(_today())] ?? state.minutesToday,
    );
  }

  void selectTask(String? id) => state =
      id == null ? state.copyWith(clearTask: true) : state.copyWith(taskId: id);

  void start({String? taskId}) {
    if (taskId != null && taskId != state.taskId) {
      state = state.copyWith(taskId: taskId, left: focusLength);
    }
    if (state.left == 0) state = state.copyWith(left: focusLength);
    _endsAt = DateTime.now().add(Duration(seconds: state.left));
    state = state.copyWith(running: true);
    _persistRun();
    NotificationService().scheduleFocusEnd(_endsAt!);
    _startTicker();
  }

  void pause() {
    _timer?.cancel();
    _endsAt = null;
    state = state.copyWith(running: false);
    _persistRun();
    NotificationService().cancelFocusEnd();
  }

  void reset() {
    _timer?.cancel();
    _endsAt = null;
    state = state.copyWith(running: false, left: focusLength);
    _prefs.remove(_runKey);
    NotificationService().cancelFocusEnd();
  }

  /// Call on app resume so the ring jumps to the right place immediately.
  void resync() {
    if (state.running) _tick();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _persistRun() => _prefs.setString(
        _runKey,
        jsonEncode({
          'taskId': state.taskId,
          if (_endsAt != null) 'endsAt': _endsAt!.millisecondsSinceEpoch,
          if (_endsAt == null) 'left': state.left,
        }),
      );

  void _tick() {
    final end = _endsAt;
    if (end == null) return;
    final left = end.difference(DateTime.now()).inSeconds;
    if (left > 0) {
      state = state.copyWith(left: left);
      return;
    }
    _timer?.cancel();
    _endsAt = null;
    _prefs.remove(_runKey);

    final today = dayKey(_today());
    final byDay = Map<String, int>.from(state.minutesByDay)
      ..update(today, (v) => v + focusLength ~/ 60,
          ifAbsent: () => focusLength ~/ 60);
    state = state.copyWith(
      left: 0,
      running: false,
      sessionsToday: state.sessionsToday + 1,
      minutesToday: byDay[today],
      minutesByDay: byDay,
    );
    _prefs
      ..setInt(_key(_uid, 'focus.s.$today'), state.sessionsToday)
      ..setString(_key(_uid, 'focus.days'), jsonEncode(byDay));
    _cloud?.save('focusMinutes', byDay);
    _ref.read(momentumProvider.notifier).award(XpSource.focus);
    onComplete?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Which bottom tab is showing. Lets any screen jump tabs (e.g. "Start focus").
final mainTabProvider = StateProvider<int>((ref) => 0);
