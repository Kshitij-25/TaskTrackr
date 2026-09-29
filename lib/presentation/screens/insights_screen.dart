import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import '../providers/momentum_provider.dart';
import '../providers/task_provider.dart';

/// Real numbers only: completions (by completion date), XP, focus minutes
/// and habit consistency over the last 7 days, plus project mix.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});
  static const routeName = '/insights';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final tasks = ref.watch(taskListProvider).value ?? const <TaskModel>[];
    final momentum = ref.watch(momentumProvider);
    final focus = ref.watch(focusProvider);
    final habits = ref.watch(habitsProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    DateTime doneOn(TaskModel t) =>
        DateUtils.dateOnly(t.completedAt ?? t.dueDate);

    final done = tasks.where((t) => t.isCompleted).toList();
    final perDay = [
      for (final d in days) done.where((t) => doneOn(t) == d).length,
    ];
    final weekDone = perDay.fold<int>(0, (a, b) => a + b);
    final prevStart = days.first.subtract(const Duration(days: 7));
    final prevDone = done
        .where((t) =>
            !doneOn(t).isBefore(prevStart) && doneOn(t).isBefore(days.first))
        .length;
    final focusWeek = [
      for (final d in days) focus.minutesByDay[dayKey(d)] ?? 0,
    ].fold<int>(0, (a, b) => a + b);
    final weekXp = momentum.lastWeek.fold<int>(0, (a, b) => a + b);
    final habitSlots = habits.length * 7;
    final habitHits =
        habits.fold<int>(0, (a, h) => a + h.week.where((v) => v).length);
    final open = tasks.where((t) => !t.isCompleted).toList();
    final overdue = open.where((t) => t.dueDate.isBefore(today)).length;
    final onTime = done
        .where(
            (t) => t.completedAt != null && !t.completedAt!.isAfter(t.dueDate))
        .length;
    final withStamp = done.where((t) => t.completedAt != null).length;

    final projects = <String, int>{};
    for (final t in tasks) {
      projects.update(t.category, (v) => v + 1, ifAbsent: () => 1);
    }
    final projectList = projects.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final best = perDay.indexOf(perDay.reduce((a, b) => a > b ? a : b));
    final maxDay = perDay.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final delta = weekDone - prevDone;

    final tip = overdue > 0
        ? '$overdue task${overdue == 1 ? ' is' : 's are'} overdue. Open Today → Review plan to roll them forward in one tap.'
        : focusWeek < 50
            ? 'Only ${focusWeek}m of focus this week. Two 25-minute sessions a day compounds fast.'
            : habitSlots > 0 && habitHits / habitSlots < .5
                ? 'Habits landed ${(habitHits / habitSlots * 100).round()}% of the time. Drop one and keep the rest perfect.'
                : 'Your best day was ${DateFormat('EEEE').format(days[best])}. Put the hardest work there next week.';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Insights')),
      body: Stack(children: [
        const Positioned.fill(child: AuroraBackground()),
        ListView(
          padding: EdgeInsets.fromLTRB(
            MomentumTokens.gutter,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
            MomentumTokens.gutter,
            40,
          ),
          children: [
            Row(children: [
              _Stat('$weekDone', 'DONE THIS WEEK', m.amber,
                  sub: delta == 0
                      ? 'same as last week'
                      : '${delta > 0 ? '+' : ''}$delta vs last week'),
              const SizedBox(width: 8),
              _Stat(
                  '${focusWeek ~/ 60}h ${focusWeek % 60}m', 'FOCUS', m.violet),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _Stat('+$weekXp', 'XP THIS WEEK', m.cyan),
              const SizedBox(width: 8),
              _Stat(
                withStamp == 0 ? '—' : '${(onTime / withStamp * 100).round()}%',
                'ON TIME',
                m.success,
              ),
            ]),
            const SizedBox(height: MomentumTokens.sectionGap),
            const SectionLabel('Completions · last 7 days'),
            const SizedBox(height: 10),
            GlassCard(
              child: SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${perDay[i]}',
                                style: AppTypography.label.copyWith(
                                    fontSize: 9.5,
                                    color:
                                        i == best ? m.amber : m.inkTertiary)),
                            const SizedBox(height: 4),
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: (perDay[i] / maxDay)
                                    .clamp(.05, 1)
                                    .toDouble(),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(7),
                                    gradient: i == best && perDay[i] > 0
                                        ? LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [m.amber, m.violet])
                                        : null,
                                    color: i == best && perDay[i] > 0
                                        ? null
                                        : m.ink.withValues(alpha: .14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(DateFormat('E').format(days[i])[0],
                                style: AppTypography.label.copyWith(
                                    fontSize: 9.5, color: m.inkTertiary)),
                          ],
                        ),
                      ),
                      if (i < 6) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              tint: m.violet.withValues(alpha: m.isDark ? .12 : .06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel('Momentum AI · tip', color: m.violet),
                  const SizedBox(height: 8),
                  Text(tip,
                      style: AppTypography.bodyStrong
                          .copyWith(color: m.ink, fontSize: 14, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: MomentumTokens.sectionGap),
            SectionLabel(
                'Habits · ${habitSlots == 0 ? 0 : (habitHits / habitSlots * 100).round()}% this week'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(children: [
                if (habits.isEmpty)
                  Text('No habits yet.',
                      style:
                          AppTypography.body.copyWith(color: m.inkSecondary)),
                for (final h in habits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(h.name,
                            style: AppTypography.caption.copyWith(
                                color: m.ink, fontWeight: FontWeight.w600)),
                      ),
                      for (final v in h.week)
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(left: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: v
                                ? m.violet.withValues(alpha: .8)
                                : m.ink.withValues(alpha: .08),
                          ),
                        ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: MomentumTokens.sectionGap),
            const SectionLabel('Project mix'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(children: [
                if (projectList.isEmpty)
                  Text('Add tasks to see where your time goes.',
                      style:
                          AppTypography.body.copyWith(color: m.inkSecondary)),
                for (final e in projectList)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(e.key,
                                style: AppTypography.caption.copyWith(
                                    color: m.ink, fontWeight: FontWeight.w600)),
                          ),
                          Text(
                              '${e.value} · ${(e.value / tasks.length * 100).round()}%',
                              style: AppTypography.label.copyWith(
                                  fontSize: 10, color: m.inkTertiary)),
                        ]),
                        const SizedBox(height: 6),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: m.ink.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: e.value / tasks.length,
                            child: Container(
                              decoration: BoxDecoration(
                                color: m.projectColor(e.key),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color, {this.sub});
  final String value;
  final String label;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Expanded(
      child: GlassCard(
        radius: MomentumTokens.radiusRow,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    AppTypography.display.copyWith(fontSize: 26, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: AppTypography.label
                    .copyWith(fontSize: 9, color: m.inkTertiary)),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub!,
                  style: AppTypography.caption
                      .copyWith(fontSize: 11, color: m.inkSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
