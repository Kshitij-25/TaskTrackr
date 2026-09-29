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

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  static const routeName = '/calendar';

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateUtils.dateOnly(DateTime.now());

  void _shiftMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final tasks =
        ref.watch(taskListProvider).valueOrNull ?? const <TaskModel>[];
    final byDay = <DateTime, List<TaskModel>>{};
    for (final t in tasks) {
      byDay.putIfAbsent(DateUtils.dateOnly(t.dueDate), () => []).add(t);
    }
    final dayTasks = [...?byDay[_selected]]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final load = dayTasks
        .where((t) => !t.isCompleted)
        .fold<int>(0, (a, t) => a + (t.estimateMinutes ?? 30));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: m.isDark ? Colors.white : m.ink,
        foregroundColor: m.isDark ? const Color(0xFF0B0B12) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusRow)),
        onPressed: () => showAddTaskSheet(context, day: _selected),
        child: const Icon(Icons.add_rounded),
      ),
      body: Stack(children: [
        const Positioned.fill(child: AuroraBackground()),
        ListView(
          padding: EdgeInsets.fromLTRB(
            MomentumTokens.gutter,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
            MomentumTokens.gutter,
            120,
          ),
          children: [
            GlassCard(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(children: [
                Row(children: [
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(DateFormat('MMMM yyyy').format(_month),
                        style: AppTypography.heading2.copyWith(color: m.ink)),
                  ),
                  IconButton(
                    onPressed: () => _shiftMonth(-1),
                    icon:
                        Icon(Icons.chevron_left_rounded, color: m.inkSecondary),
                  ),
                  IconButton(
                    onPressed: () => _shiftMonth(1),
                    icon: Icon(Icons.chevron_right_rounded,
                        color: m.inkSecondary),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(d,
                            style: AppTypography.label
                                .copyWith(color: m.inkTertiary)),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                _MonthGrid(
                  month: _month,
                  selected: _selected,
                  byDay: byDay,
                  onPick: (d) => setState(() => _selected = d),
                ),
              ]),
            ),
            const SizedBox(height: MomentumTokens.sectionGap),
            SectionLabel(
              DateFormat('EEEE d MMMM').format(_selected),
              trailing: Text(
                dayTasks.isEmpty
                    ? 'FREE'
                    : '${dayTasks.length} TASKS · ${load ~/ 60}H ${load % 60}M',
                style: AppTypography.label.copyWith(
                  fontSize: 10,
                  color: load > 12 * 60 ? m.danger : m.inkSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (dayTasks.isEmpty)
              MomentumEmptyState(
                title: 'A free day',
                message: 'Nothing is due. Protect it, or plan something.',
                actionLabel: 'Add to this day',
                onAction: () => showAddTaskSheet(context, day: _selected),
              )
            else
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  for (final t in dayTasks) TaskRow(task: t, showDue: true),
                ]),
              ),
          ],
        ),
      ]),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.onPick,
  });

  final DateTime month;
  final DateTime selected;
  final Map<DateTime, List<TaskModel>> byDay;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = DateTime(month.year, month.month).weekday - 1;
    final weeks = ((offset + days) / 7).ceil();
    final today = DateUtils.dateOnly(DateTime.now());

    return Column(children: [
      for (var w = 0; w < weeks; w++)
        Row(children: [
          for (var d = 0; d < 7; d++)
            Expanded(
              child: Builder(builder: (_) {
                final n = w * 7 + d - offset + 1;
                if (n < 1 || n > days) return const SizedBox(height: 46);
                final date = DateTime(month.year, month.month, n);
                final isSel = date == selected;
                final isToday = date == today;
                final list = byDay[date] ?? const [];
                final open = list.where((t) => !t.isCompleted).length;
                final done = list.length - open;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(date),
                  child: SizedBox(
                    height: 46,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: AppMotion.of(context, AppMotion.standard),
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSel
                                ? LinearGradient(colors: [m.amber, m.violet])
                                : null,
                            border: isToday && !isSel
                                ? Border.all(color: m.violet)
                                : null,
                          ),
                          child: Text('$n',
                              style: AppTypography.caption.copyWith(
                                fontWeight: isSel || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSel ? const Color(0xFF0B0B12) : m.ink,
                              )),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < open.clamp(0, 3); i++)
                              _dot(m.violet),
                            for (var i = 0;
                                i < done.clamp(0, 3 - open.clamp(0, 3));
                                i++)
                              _dot(m.ink.withValues(alpha: .25)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ]),
    ]);
  }

  Widget _dot(Color c) => Container(
        width: 4,
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
