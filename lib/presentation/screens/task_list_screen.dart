import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../components/add_task_sheet.dart';
import '../components/momentum_ui.dart';
import '../components/task_row.dart';
import '../providers/task_provider.dart';
import 'home_screen.dart' show isSameDay;

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final _search = TextEditingController();
  String _filter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('today', 'Today'),
    ('high', 'High priority'),
    ('done', 'Completed'),
    ('archived', 'Archived'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _match(TaskModel t, String q, DateTime now) {
    final hit = q.isEmpty ||
        t.title.toLowerCase().contains(q) ||
        t.category.toLowerCase().contains(q) ||
        (t.description ?? '').toLowerCase().contains(q);
    if (!hit) return false;
    return switch (_filter) {
      'today' => isSameDay(t.dueDate, now),
      'high' => t.priority.toLowerCase() == 'high',
      'done' => t.isCompleted,
      _ => true,
    };
  }

  String _groupFor(TaskModel t, DateTime now) {
    if (t.isArchived) return 'ARCHIVED · TAP TO RESTORE';
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    final diff = d.difference(today).inDays;
    if (diff < 0) return t.isCompleted ? 'EARLIER' : 'OVERDUE';
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff < 7) return DateFormat('EEEE').format(d).toUpperCase();
    return 'LATER';
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final now = DateTime.now();
    final async = ref.watch(taskListProvider);
    final tasks = async.value ?? const <TaskModel>[];
    final archived = ref.watch(archivedTasksProvider);
    final q = _search.text.trim().toLowerCase();
    final pool = (_filter == 'archived' ? archived : tasks)
        .where((t) => _match(t, q, now))
        .toList();

    final groups = <String, List<TaskModel>>{};
    for (final t in pool) {
      groups.putIfAbsent(_groupFor(t, now), () => []).add(t);
    }
    const order = ['OVERDUE', 'TODAY', 'TOMORROW'];
    final keys = groups.keys.toList()
      ..sort((a, b) {
        int rank(String k) {
          final i = order.indexOf(k);
          if (i >= 0) return i;
          if (k == 'LATER') return 50;
          if (k == 'EARLIER') return 60;
          return 10 + groups[k]!.first.dueDate.difference(now).inDays;
        }

        return rank(a).compareTo(rank(b));
      });

    final doneCount = tasks.where((t) => t.isCompleted).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        MomentumTokens.gutter,
        MediaQuery.paddingOf(context).top + 14,
        MomentumTokens.gutter,
        130,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text('Tasks', style: AppTypography.heading1.copyWith(color: m.ink)),
        const SizedBox(height: 4),
        Text('${pool.length} of ${tasks.length} shown · $doneCount done',
            style: AppTypography.caption.copyWith(color: m.inkSecondary)),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          cursorColor: m.violet,
          style: AppTypography.body.copyWith(color: m.ink),
          decoration: InputDecoration(
            hintText: 'Search tasks, projects…',
            hintStyle: AppTypography.body.copyWith(color: m.inkTertiary),
            prefixIcon:
                Icon(Icons.search_rounded, color: m.inkTertiary, size: 20),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: m.inkTertiary, size: 18),
                    onPressed: () => setState(_search.clear),
                  ),
            filled: true,
            fillColor: m.isDark ? m.glass : m.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (k, label) in _filters) ...[
                FilterPill(
                  label: label,
                  selected: _filter == k,
                  onTap: () => setState(() => _filter = k),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (async.isLoading && tasks.isEmpty)
          const _Skeleton()
        else if (keys.isEmpty)
          q.isNotEmpty
              ? MomentumEmptyState(
                  title: 'Nothing matches',
                  message:
                      'No task or project for “${_search.text.trim()}”. Try a shorter term — or capture it as a new task.',
                  actionLabel:
                      'Add “${_search.text.trim().length > 22 ? _search.text.trim().substring(0, 22) : _search.text.trim()}”',
                  onAction: () =>
                      showAddTaskSheet(context, initial: _search.text.trim()),
                )
              : MomentumEmptyState(
                  title: tasks.isEmpty ? 'A clean slate' : 'Nothing here',
                  message: tasks.isEmpty
                      ? 'Capture the first thing on your mind.'
                      : 'No tasks in this filter.',
                  actionLabel: 'Add a task',
                  onAction: () => showAddTaskSheet(context),
                )
        else
          for (final k in keys) ...[
            SectionLabel(k,
                trailing: Text('${groups[k]!.length}',
                    style: AppTypography.label.copyWith(color: m.inkTertiary))),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final t in groups[k]!)
                    TaskRow(task: t, showDue: k == 'TODAY'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
      ],
    );
  }
}

/// Skeleton rows with a 1.4s shimmer.
class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    if (AppMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final g = LinearGradient(
          begin: Alignment(-1 + _c.value * 3, 0),
          end: Alignment(_c.value * 3, 0),
          colors: [
            m.ink.withValues(alpha: .05),
            m.ink.withValues(alpha: .12),
            m.ink.withValues(alpha: .05),
          ],
        );
        Widget bar(double w, double h) => Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                  gradient: g, borderRadius: BorderRadius.circular(6)),
            );
        return GlassCard(
          child: Column(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration:
                          BoxDecoration(gradient: g, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(180, 12),
                        const SizedBox(height: 8),
                        bar(90, 9)
                      ],
                    ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}
