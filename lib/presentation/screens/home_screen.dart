import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/backend/authenticator.dart';
import '../../data/models/task_model.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../components/add_task_sheet.dart';
import '../components/momentum_ui.dart';
import '../components/plan_card.dart';
import '../components/rewards.dart';
import '../components/task_detail_sheet.dart';
import '../components/task_row.dart';
import '../providers/momentum_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Today — every block answers "what keeps the streak alive today?"
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  static const routeName = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final now = DateTime.now();
    final tasks = ref.watch(taskListProvider).value ?? const <TaskModel>[];
    final user = ref.watch(userProfileProvider).value;
    final name =
        (user?.displayName ?? const Authenticator().displayName).trim();
    final first = name.isEmpty ? 'there' : name.split(' ').first;

    final today = tasks
        .where((t) =>
            isSameDay(t.dueDate, now) ||
            (!t.isCompleted && t.dueDate.isBefore(now)))
        .toList();
    final open = today.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => _prioRank(a).compareTo(_prioRank(b)));
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final summary = open.isEmpty
        ? (today.isEmpty
            ? 'A clear day — capture something'
            : 'You are clear for today')
        : '${open.length} task${open.length == 1 ? '' : 's'} left'
            '${open.first.estimateLabel.isEmpty ? '' : ' · ${open.first.estimateLabel} to your first win'}';

    final schedule = tasks.where((t) => isSameDay(t.dueDate, now)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        MomentumTokens.gutter,
        MediaQuery.paddingOf(context).top + 14,
        MomentumTokens.gutter,
        130,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEE d MMMM').format(now).toUpperCase(),
                      style:
                          AppTypography.label.copyWith(color: m.inkTertiary)),
                  const SizedBox(height: 6),
                  Text('$greeting, $first',
                      style: AppTypography.heading1.copyWith(color: m.ink)),
                  const SizedBox(height: 4),
                  Text(summary,
                      style: AppTypography.caption
                          .copyWith(color: m.inkSecondary, fontSize: 13)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ref.read(mainTabProvider.notifier).state = 4,
              child: LevelAvatar(
                name: name,
                photoUrl: user?.photoURL,
                level: ref.watch(gamificationProvider) == GamificationMode.off
                    ? null
                    : ref.watch(momentumProvider).level,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const MomentumHud(),
        const SizedBox(height: 14),
        _QuickCapture(),
        const PlanCard(),
        const SizedBox(height: MomentumTokens.sectionGap),
        SectionLabel(
          "Today's focus",
          trailing: GestureDetector(
            onTap: () => ref.read(mainTabProvider.notifier).state = 1,
            child: Text('All tasks',
                style: AppTypography.caption
                    .copyWith(color: m.cyan, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        if (open.isEmpty)
          MomentumEmptyState(
            title: today.isEmpty
                ? 'Nothing planned yet'
                : 'Inbox zero at ${DateFormat('HH:mm').format(now)}',
            message: today.isEmpty
                ? 'Capture one thing that would make today count.'
                : 'Every task for today is done. The streak is safe.',
            actionLabel: 'Add a task',
            onAction: () => showAddTaskSheet(context),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final t in open.take(3)) TaskRow(task: t),
              ],
            ),
          ),
        if (schedule.isNotEmpty) ...[
          const SizedBox(height: MomentumTokens.sectionGap),
          const SectionLabel('Schedule'),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                for (final t in schedule) _ScheduleRow(task: t),
              ],
            ),
          ),
        ],
        const SizedBox(height: MomentumTokens.sectionGap),
        SectionLabel(
          'Habits',
          trailing: GestureDetector(
            onTap: () => ref.read(mainTabProvider.notifier).state = 3,
            child: Text('All habits',
                style: AppTypography.caption
                    .copyWith(color: m.cyan, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        const _HabitStrip(),
      ],
    );
  }

  static int _prioRank(TaskModel t) =>
      switch (t.priority.toLowerCase()) { 'high' => 0, 'medium' => 1, _ => 2 };
}

/// Streak + level + XP. The spine of the app.
class MomentumHud extends ConsumerWidget {
  const MomentumHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final s = ref.watch(momentumProvider);
    final gamOn = ref.watch(gamificationProvider) != GamificationMode.off;
    final now = DateTime.now();
    final week = List.generate(
      7,
      (i) => s.activeOn(DateTime(now.year, now.month, now.day - (6 - i))),
    );

    return GlassCard(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText('${s.streak}',
                  style: AppTypography.display.copyWith(fontSize: 44)),
              Text('DAY STREAK',
                  style: AppTypography.label
                      .copyWith(fontSize: 9.5, color: m.inkTertiary)),
            ],
          ),
          const SizedBox(width: 18),
          Container(width: 1, height: 58, color: m.stroke),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gamOn) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text('Level ${s.level} · ${s.levelName}',
                            style: AppTypography.bodyStrong
                                .copyWith(color: m.ink, fontSize: 13.5)),
                      ),
                      Text('${s.xp} / $xpPerLevel',
                          style: AppTypography.label.copyWith(
                              fontSize: 10,
                              letterSpacing: .3,
                              color: m.inkTertiary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  XpBar(progress: s.progress),
                ] else
                  Text(
                    s.activeToday
                        ? 'Streak safe for today'
                        : 'Finish a task, habit or focus session to keep it',
                    style: AppTypography.bodyStrong
                        .copyWith(color: m.ink, fontSize: 13.5),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: AppMotion.of(
                              context, const Duration(milliseconds: 300)),
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: week[i]
                                ? m.amber.withValues(alpha: .85)
                                : m.ink.withValues(alpha: .1),
                          ),
                        ),
                      ),
                      if (i < 6) const SizedBox(width: 4),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCapture extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    return Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: () => showAddTaskSheet(context),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: context.m.card(radius: MomentumTokens.radiusRow),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(colors: [m.amber, m.violet]),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Color(0xFF0B0B12), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Add anything…',
                      style: AppTypography.body.copyWith(color: m.inkTertiary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Pressable(
          haptic: true,
          onTap: () => ref.read(mainTabProvider.notifier).state = 2,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: context.m.card(radius: MomentumTokens.radiusRow),
            child: Row(
              children: [
                Icon(Icons.adjust_rounded, size: 18, color: m.violet),
                const SizedBox(width: 6),
                Text('Focus',
                    style: AppTypography.bodyStrong
                        .copyWith(color: m.ink, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.task});
  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final c = task.isCompleted
        ? m.ink.withValues(alpha: .2)
        : m.priorityColor(task.priority);
    return Pressable(
      onTap: () => showTaskDetail(context, task.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Text(DateFormat('HH:mm').format(task.dueDate),
                    style: AppTypography.label.copyWith(
                        fontSize: 11,
                        letterSpacing: .3,
                        color: m.inkSecondary)),
              ),
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: m.isDark && !task.isCompleted
                      ? [BoxShadow(color: c, blurRadius: 12)]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          fontSize: 13.5,
                          color: task.isCompleted ? m.inkTertiary : m.ink,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (task.estimateLabel.isNotEmpty) task.estimateLabel,
                        task.category,
                      ].join(' · '),
                      style: AppTypography.caption
                          .copyWith(fontSize: 11.5, color: m.inkTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitStrip extends ConsumerWidget {
  const _HabitStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final habits = ref.watch(habitsProvider).take(4).toList();
    if (habits.isEmpty) {
      return MomentumEmptyState(
        title: 'No habits yet',
        message: 'Small daily wins compound. Add your first one.',
        actionLabel: 'Open habits',
        onAction: () => ref.read(mainTabProvider.notifier).state = 3,
      );
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          for (final h in habits)
            Expanded(
              child: HabitToggle(
                habit: h,
                child: Column(
                  children: [
                    HabitRing(done: h.doneToday, size: 34),
                    const SizedBox(height: 8),
                    Text(h.short,
                        style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            color: m.ink)),
                    Text('${h.streak}d',
                        style: AppTypography.label.copyWith(
                            fontSize: 9.5, letterSpacing: .3, color: m.amber)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps a habit visual; tap logs it with XP + burst.
class HabitToggle extends ConsumerWidget {
  const HabitToggle({super.key, required this.habit, required this.child});
  final Habit habit;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final done = ref.read(habitActionsProvider).toggleToday(habit.id);
        if (done) {
          final box = context.findRenderObject() as RenderBox?;
          rewardWin(
            context,
            ref,
            XpSource.habit,
            message: 'Habit logged',
            burstAt: box?.localToGlobal(box.size.center(Offset.zero)),
          );
        } else {
          ref.read(momentumProvider.notifier).revoke(XpSource.habit);
        }
      },
      child: child,
    );
  }
}
