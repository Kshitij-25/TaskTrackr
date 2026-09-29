import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/task_model.dart';
import 'momentum_provider.dart' show dayKey;
import 'task_provider.dart';
import 'theme_provider.dart';

/// Working day ends here; the planner fits today's estimates before it.
const planDayEndHour = 22;
const _defaultEstimate = 30;

enum PlanKind { move, rollover, focusFirst }

class PlanMove {
  const PlanMove({
    required this.kind,
    required this.title,
    required this.why,
    this.task,
    this.to,
  });

  final PlanKind kind;
  final String title;
  final String why;
  final TaskModel? task;
  final DateTime? to;
}

class DayPlan {
  const DayPlan({
    required this.headline,
    required this.moves,
    required this.overbookedMinutes,
  });

  final String headline;
  final List<PlanMove> moves;
  final int overbookedMinutes;

  bool get hasAdvice => moves.isNotEmpty;
}

int _minutes(TaskModel t) => t.estimateMinutes ?? _defaultEstimate;

int _prioRank(TaskModel t) =>
    switch (t.priority.toLowerCase()) { 'high' => 0, 'medium' => 1, _ => 2 };

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fmtMinutes(int m) =>
    m < 60 ? '$m minutes' : '${m ~/ 60}h${m % 60 == 0 ? '' : ' ${m % 60}m'}';

/// Rule-based day planner. Runs on-device, so it works offline and never
/// sends task data anywhere.
final dayPlanProvider = Provider<DayPlan?>((ref) {
  final tasks = ref.watch(taskListProvider).value;
  if (tasks == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final open = tasks.where((t) => !t.isCompleted).toList();
  final overdue = open.where((t) => t.dueDate.isBefore(today)).toList();
  final dueToday = open.where((t) => _sameDay(t.dueDate, now)).toList();

  final dayEnd = DateTime(now.year, now.month, now.day, planDayEndHour);
  final available = dayEnd.isAfter(now) ? dayEnd.difference(now).inMinutes : 0;
  final load = dueToday.fold<int>(0, (a, t) => a + _minutes(t));
  final over = load - available;

  final moves = <PlanMove>[];

  if (overdue.isNotEmpty) {
    moves.add(PlanMove(
      kind: PlanKind.rollover,
      title: 'Roll ${overdue.length} overdue task'
          '${overdue.length == 1 ? '' : 's'} into today',
      why: 'Stale due dates hide what actually matters. '
          'Bring them forward, then decide.',
    ));
  }

  if (over > 0) {
    // Load per upcoming day, to find the lightest landing spots.
    final loadByDay = <String, int>{};
    for (final t in open) {
      loadByDay.update(dayKey(t.dueDate), (v) => v + _minutes(t),
          ifAbsent: () => _minutes(t));
    }
    final candidates = [...dueToday]
      ..removeWhere((t) => t.priority.toLowerCase() == 'high')
      ..sort((a, b) {
        final p = _prioRank(b).compareTo(_prioRank(a));
        return p != 0 ? p : _minutes(b).compareTo(_minutes(a));
      });

    var freed = 0;
    for (final t in candidates) {
      if (freed >= over || moves.length >= 3) break;
      final days = List.generate(5, (i) => today.add(Duration(days: i + 1)));
      days.sort((a, b) =>
          (loadByDay[dayKey(a)] ?? 0).compareTo(loadByDay[dayKey(b)] ?? 0));
      final target = days.first;
      final to = DateTime(target.year, target.month, target.day, t.dueDate.hour,
          t.dueDate.minute);
      loadByDay.update(dayKey(target), (v) => v + _minutes(t),
          ifAbsent: () => _minutes(t));
      freed += _minutes(t);
      moves.add(PlanMove(
        kind: PlanKind.move,
        task: t,
        to: to,
        title: 'Move “${t.title}” to ${DateFormat('EEEE').format(to)}',
        why: '${t.priority} priority, ${_fmtMinutes(_minutes(t))}, and '
            '${DateFormat('EEEE').format(to)} is your lightest day.',
      ));
    }
  }

  final firstHigh = ([...dueToday]..sort((a, b) {
          final p = _prioRank(a).compareTo(_prioRank(b));
          return p != 0 ? p : a.dueDate.compareTo(b.dueDate);
        }))
      .where((t) => t.priority.toLowerCase() == 'high')
      .firstOrNull;
  if (firstHigh != null && moves.length < 3) {
    moves.add(PlanMove(
      kind: PlanKind.focusFirst,
      task: firstHigh,
      title: 'Start with “${firstHigh.title}”',
      why: 'Highest priority on today’s list — a 25-minute focus block '
          'gets it moving.',
    ));
  }

  final String headline;
  if (over > 0) {
    headline = 'Today is ${_fmtMinutes(over)} overbooked. '
        '${moves.any((m) => m.kind == PlanKind.move) ? 'I can move the lowest-priority work and protect the rest.' : 'Everything left is high priority — pick one and protect it.'}';
  } else if (overdue.isNotEmpty) {
    headline = '${overdue.length} task${overdue.length == 1 ? ' is' : 's are'} '
        'past due. Clear the backlog before it grows.';
  } else if (firstHigh != null) {
    headline = 'Your day fits with ${_fmtMinutes(-over)} to spare. '
        'Lead with the high-priority task.';
  } else {
    headline = '';
  }

  return DayPlan(
    headline: headline,
    moves: moves,
    overbookedMinutes: over > 0 ? over : 0,
  );
});

/// "Not now" hides the card for the rest of the day.
final planDismissedProvider = StateNotifierProvider<PlanDismissed, bool>((ref) {
  return PlanDismissed(ref.watch(sharedPreferencesProvider));
});

class PlanDismissed extends StateNotifier<bool> {
  PlanDismissed(this._prefs)
      : super(_prefs.getString(_k) == dayKey(DateTime.now()));

  static const _k = 'plan.dismissed';
  final SharedPreferences _prefs;

  void dismiss() {
    _prefs.setString(_k, dayKey(DateTime.now()));
    state = true;
  }
}
