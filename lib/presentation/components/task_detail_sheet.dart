import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../providers/momentum_provider.dart';
import '../providers/task_provider.dart';
import 'momentum_ui.dart';
import 'task_row.dart';

const kProjects = [
  'Inbox',
  'Work',
  'Personal',
  'Health',
  'Finance',
  'Learning',
  'Engineering',
  'Client',
];
const kPriorities = ['High', 'Medium', 'Low'];
const kEstimates = [10, 15, 25, 30, 45, 60, 90, 120];

Future<void> showTaskDetail(BuildContext context, String taskId) =>
    showMomentumSheet(context, (_) => TaskDetailSheet(taskId: taskId));

/// Archive with an undo toast. Shared by the sheet and swipe gestures.
void archiveWithUndo(BuildContext context, WidgetRef ref, TaskModel task) {
  final actions = ref.read(taskActionsProvider);
  actions.setArchived(task.id, true);
  showMomentumToast(
    context,
    'Archived “${task.title}”',
    actionLabel: 'Undo',
    onAction: () => actions.setArchived(task.id, false),
  );
}

/// Asks for a date then a time; null if cancelled.
Future<DateTime?> pickDueDate(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(now) ? now : initial,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 5),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({super.key, required this.taskId});
  final String taskId;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  final _subCtrl = TextEditingController();
  TextEditingController? _notesCtrl;
  TextEditingController? _titleCtrl;
  bool _editingTitle = false;

  @override
  void dispose() {
    _subCtrl.dispose();
    _notesCtrl?.dispose();
    _titleCtrl?.dispose();
    super.dispose();
  }

  TaskActions get _actions => ref.read(taskActionsProvider);

  void _update(TaskModel t) => _actions.updateTask(t);

  void _setSubs(TaskModel t, List<Subtask> subs) =>
      _update(t.copyWith(subtasks: subs));

  Future<void> _editDue(TaskModel t) async {
    final due = await pickDueDate(context, t.dueDate);
    if (due != null) _update(t.copyWith(dueDate: due));
  }

  Future<void> _editPriority(TaskModel t) async {
    final m = context.m;
    final p = await showOptionSheet<String>(
      context,
      title: 'Priority',
      selected: t.priority,
      options: [for (final p in kPriorities) (p, p, m.priorityColor(p))],
    );
    if (p != null) _update(t.copyWith(priority: p));
  }

  Future<void> _editProject(TaskModel t) async {
    final m = context.m;
    final p = await showOptionSheet<String>(
      context,
      title: 'Project',
      selected: t.category,
      options: [for (final p in kProjects) (p, p, m.projectColor(p))],
    );
    if (p != null) _update(t.copyWith(category: p));
  }

  Future<void> _editEstimate(TaskModel t) async {
    final e = await showOptionSheet<int>(
      context,
      title: 'Estimate',
      selected: t.estimateMinutes,
      options: [
        for (final e in kEstimates)
          (
            e < 60
                ? '$e min'
                : '${e ~/ 60}h${e % 60 == 0 ? '' : ' ${e % 60}m'}',
            e,
            null,
          ),
      ],
    );
    if (e != null) _update(t.copyWith(estimateMinutes: e));
  }

  void _saveTitle(TaskModel t) {
    final v = _titleCtrl!.text.trim();
    setState(() => _editingTitle = false);
    if (v.isNotEmpty && v != t.title) _update(t.copyWith(title: v));
  }

  Future<void> _confirmDelete(TaskModel t) async {
    final m = context.m;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: m.isDark ? const Color(0xFF14141C) : m.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusCard)),
        title: Text('Delete for good?',
            style: AppTypography.heading2.copyWith(color: m.ink)),
        content: Text(
          'This removes “${t.title}” everywhere. Archive keeps it out of the '
          'way without losing it.',
          style: AppTypography.body.copyWith(color: m.inkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: m.inkSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: m.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _actions.deleteTask(t.id);
    Navigator.pop(context);
    showMomentumToast(context, 'Task deleted');
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final tasks =
        ref.watch(allTasksProvider).valueOrNull ?? const <TaskModel>[];
    final task = tasks.where((t) => t.id == widget.taskId).firstOrNull;
    if (task == null) {
      return const SizedBox(height: 200);
    }
    _notesCtrl ??= TextEditingController(text: task.description ?? '');
    _titleCtrl ??= TextEditingController(text: task.title);
    final prioLabel = switch (task.priority.toLowerCase()) {
      'high' => 'High priority',
      'medium' => 'Medium',
      _ => 'Low',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.isArchived) ...[
            TagChip('ARCHIVED', color: m.inkSecondary),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(-11, -9),
                child: CheckDot(
                  done: task.isCompleted,
                  size: 26,
                  onTap: (c) => toggleTaskWithXp(context, ref, task, c),
                ),
              ),
              Expanded(
                child: _editingTitle
                    ? TextField(
                        controller: _titleCtrl,
                        autofocus: true,
                        onSubmitted: (_) => _saveTitle(task),
                        onTapOutside: (_) => _saveTitle(task),
                        cursorColor: m.violet,
                        style: AppTypography.heading2
                            .copyWith(color: m.ink, fontSize: 21),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    : GestureDetector(
                        onTap: () => setState(() {
                          _titleCtrl!.text = task.title;
                          _editingTitle = true;
                        }),
                        child: Text(task.title,
                            style: AppTypography.heading2.copyWith(
                              color: m.ink,
                              fontSize: 21,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: [
            GestureDetector(
              onTap: () => _editProject(task),
              child:
                  TagChip(task.category, color: m.projectColor(task.category)),
            ),
            GestureDetector(
              onTap: () => _editPriority(task),
              child: TagChip(prioLabel,
                  color: m.priorityColor(task.priority), dot: true),
            ),
          ]),
          const SizedBox(height: 18),
          GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _MetaTile(
                'DUE',
                DateFormat('EEE d MMM · HH:mm').format(task.dueDate),
                onTap: () => _editDue(task),
                warn:
                    !task.isCompleted && task.dueDate.isBefore(DateTime.now()),
              ),
              _MetaTile(
                'ESTIMATE',
                task.estimateLabel.isEmpty ? 'Set…' : task.estimateLabel,
                onTap: () => _editEstimate(task),
              ),
              _MetaTile(
                'STATUS',
                task.isCompleted
                    ? 'Done${task.completedAt == null ? '' : ' · ${DateFormat('d MMM').format(task.completedAt!)}'}'
                    : 'Open',
              ),
              _MetaTile('SYNC', task.isPending ? 'Pending' : 'Synced'),
            ],
          ),
          const SizedBox(height: 22),
          SectionLabel(
            'Subtasks ${task.subtasks.isEmpty ? '' : task.subtaskLabel}',
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < task.subtasks.length; i++)
            Row(
              children: [
                CheckDot(
                  done: task.subtasks[i].done,
                  size: 18,
                  square: true,
                  onTap: (_) {
                    final subs = [...task.subtasks];
                    subs[i] = subs[i].copyWith(done: !subs[i].done);
                    _setSubs(task, subs);
                  },
                ),
                Expanded(
                  child: Text(
                    task.subtasks[i].title,
                    style: AppTypography.caption.copyWith(
                      fontSize: 13,
                      color: task.subtasks[i].done ? m.inkTertiary : m.ink,
                      decoration: task.subtasks[i].done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon:
                      Icon(Icons.close_rounded, size: 16, color: m.inkTertiary),
                  onPressed: () =>
                      _setSubs(task, [...task.subtasks]..removeAt(i)),
                ),
              ],
            ),
          _InlineField(
            controller: _subCtrl,
            hint: 'Add a subtask…',
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              _setSubs(task, [...task.subtasks, Subtask(title: v.trim())]);
              _subCtrl.clear();
            },
          ),
          const SizedBox(height: 22),
          const SectionLabel('Notes'),
          const SizedBox(height: 8),
          _InlineField(
            controller: _notesCtrl!,
            hint: 'Anything worth remembering…',
            multiline: true,
            onSubmitted: (v) {
              if (v != (task.description ?? '')) {
                _update(task.copyWith(description: v));
              }
            },
          ),
          const SizedBox(height: 24),
          if (task.isArchived)
            MButton(
              label: 'Restore to tasks',
              expand: true,
              icon: const Icon(Icons.unarchive_outlined),
              onPressed: () {
                _actions.setArchived(task.id, false);
                Navigator.pop(context);
                showMomentumToast(context, 'Restored');
              },
            )
          else
            MButton(
              label: 'Start focus',
              expand: true,
              kind: MButtonKind.ai,
              icon: const Icon(Icons.adjust_rounded),
              onPressed: task.isCompleted
                  ? null
                  : () {
                      ref.read(focusProvider.notifier).start(taskId: task.id);
                      ref.read(mainTabProvider.notifier).state = 2;
                      Navigator.pop(context);
                      showMomentumToast(context, 'Focus session started');
                    },
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: MButton(
                label: 'Duplicate',
                kind: MButtonKind.secondary,
                onPressed: () {
                  _actions.addTask(task.copyWith(
                    title: '${task.title} (copy)',
                    isCompleted: false,
                    isArchived: false,
                  ));
                  Navigator.pop(context);
                  showMomentumToast(context, 'Duplicated');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: task.isArchived
                  ? MButton(
                      label: 'Delete',
                      kind: MButtonKind.destructive,
                      onPressed: () => _confirmDelete(task),
                    )
                  : MButton(
                      label: 'Archive',
                      kind: MButtonKind.secondary,
                      onPressed: () {
                        Navigator.pop(context);
                        archiveWithUndo(context, ref, task);
                      },
                    ),
            ),
          ]),
          if (!task.isArchived)
            Center(
              child: TextButton(
                onPressed: () => _confirmDelete(task),
                child: Text('Delete permanently',
                    style: AppTypography.caption.copyWith(
                        color: m.danger, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile(this.label, this.value, {this.onTap, this.warn = false});
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: m.ink.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
        border:
            Border.all(color: warn ? m.danger.withValues(alpha: .4) : m.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: AppTypography.label.copyWith(
                        fontSize: 9, color: warn ? m.danger : m.inkTertiary)),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(fontWeight: FontWeight.w600, color: m.ink)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.edit_outlined, size: 13, color: m.inkTertiary),
        ],
      ),
    );
    return onTap == null ? tile : Pressable(onTap: onTap, child: tile);
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    this.multiline = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Focus(
      onFocusChange: (f) {
        if (!f && multiline) onSubmitted(controller.text);
      },
      child: TextField(
        controller: controller,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 8 : 1,
        textInputAction:
            multiline ? TextInputAction.newline : TextInputAction.done,
        onSubmitted: onSubmitted,
        style: AppTypography.body.copyWith(color: m.ink, height: 1.5),
        cursorColor: m.violet,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.body.copyWith(color: m.inkTertiary),
          filled: true,
          fillColor: m.ink.withValues(alpha: .04),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
            borderSide: BorderSide(color: m.stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
            borderSide: BorderSide(color: m.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
            borderSide: BorderSide(color: m.violet.withValues(alpha: .7)),
          ),
        ),
      ),
    );
  }
}
