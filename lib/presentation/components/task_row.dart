import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../providers/momentum_provider.dart';
import '../providers/task_provider.dart';
import 'momentum_ui.dart';
import 'rewards.dart';
import 'task_detail_sheet.dart';

/// Completes / reopens a task, banks XP and fires the burst + haptic.
Future<void> toggleTaskWithXp(
  BuildContext context,
  WidgetRef ref,
  TaskModel task,
  Offset burstAt,
) async {
  final nowDone = !task.isCompleted;
  if (nowDone) {
    rewardWin(context, ref, XpSource.task,
        message: 'Nice — streak safe for today', burstAt: burstAt);
  } else {
    ref.read(momentumProvider.notifier).revoke(XpSource.task);
  }
  // Not awaited: the local cache updates instantly, the server when online.
  await ref
      .read(taskActionsProvider)
      .toggleTaskCompletion(task.id, nowDone)
      .catchError((Object e) {
    if (context.mounted) showMomentumToast(context, 'Could not update: $e');
  });
}

/// Swipe right to complete, left to archive (with undo). Additive — every
/// action is also reachable from the detail sheet.
class SwipeableTask extends ConsumerWidget {
  const SwipeableTask({super.key, required this.task, required this.child});
  final TaskModel task;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    Widget bg(Alignment a, IconData icon, String label, Color c) => Container(
          alignment: a,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: c.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(MomentumTokens.radiusRow),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: c, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTypography.label.copyWith(color: c, fontSize: 10)),
            ],
          ),
        );

    return Dismissible(
      key: ValueKey('swipe-${task.id}'),
      background: bg(
        Alignment.centerLeft,
        task.isCompleted ? Icons.replay_rounded : Icons.check_rounded,
        task.isCompleted
            ? 'REOPEN'
            : xpLabel(ref, XpSource.task, fallback: 'DONE'),
        m.success,
      ),
      secondaryBackground:
          bg(Alignment.centerRight, Icons.archive_outlined, 'ARCHIVE', m.amber),
      confirmDismiss: (dir) async {
        await HapticFeedback.selectionClick();
        if (dir == DismissDirection.startToEnd) {
          final box = context.findRenderObject() as RenderBox?;
          final at = box == null
              ? Offset.zero
              : box.localToGlobal(Offset(40, box.size.height / 2));
          await toggleTaskWithXp(context, ref, task, at);
        } else {
          archiveWithUndo(context, ref, task);
        }
        // The stream updates the list; never let Dismissible remove it itself.
        return false;
      },
      child: child,
    );
  }
}

class TaskRow extends ConsumerWidget {
  const TaskRow({super.key, required this.task, this.showDue = false});

  final TaskModel task;
  final bool showDue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final done = task.isCompleted;
    final prio = m.priorityColor(task.priority);

    final body = _body(context, ref, m, done, prio);
    return task.isArchived ? body : SwipeableTask(task: task, child: body);
  }

  Widget _body(BuildContext context, WidgetRef ref, MomentumTokens m, bool done,
      Color prio) {
    return Pressable(
      onTap: () => showTaskDetail(context, task.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MomentumTokens.radiusRow),
          color: Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckDot(
              done: done,
              onTap: (c) => toggleTaskWithXp(context, ref, task, c),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 11, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: AppMotion.of(
                          context, const Duration(milliseconds: 300)),
                      style: AppTypography.bodyStrong.copyWith(
                        color: done ? m.ink.withValues(alpha: .34) : m.ink,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: m.ink.withValues(alpha: .34),
                      ),
                      child: Text(task.title),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TagChip(task.category,
                            color: m.projectColor(task.category)),
                        if (task.estimateLabel.isNotEmpty)
                          _Meta(task.estimateLabel),
                        if (showDue) _Meta(_dueLabel(task.dueDate)),
                        if (task.subtasks.isNotEmpty)
                          _Meta('◧ ${task.subtaskLabel}'),
                        if (task.isPending) _Meta('PENDING', color: m.amber),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Priority = dot plus label elsewhere; never colour alone.
            Padding(
              padding: const EdgeInsets.only(top: 19),
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.standard),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? m.ink.withValues(alpha: .16) : prio,
                  boxShadow: done || !m.isDark
                      ? null
                      : [BoxShadow(color: prio, blurRadius: 10)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dueLabel(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$h:$mi';
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTypography.label.copyWith(
          fontSize: 10.5,
          letterSpacing: .4,
          color: color ?? context.m.inkTertiary,
        ),
      );
}
