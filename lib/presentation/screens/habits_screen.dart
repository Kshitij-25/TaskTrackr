import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import '../providers/momentum_provider.dart';
import 'home_screen.dart' show HabitToggle;

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  Future<void> _addHabit(BuildContext context, WidgetRef ref) async {
    final m = context.m;
    final name = TextEditingController();
    final goal = TextEditingController();
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.body.copyWith(color: m.inkTertiary),
          filled: true,
          fillColor: m.ink.withValues(alpha: .05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
            borderSide: BorderSide.none,
          ),
        );
    await showMomentumSheet(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New habit',
                style: AppTypography.heading2.copyWith(color: m.ink)),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              autofocus: true,
              style: AppTypography.bodyStrong.copyWith(color: m.ink),
              decoration: deco('Stretch for ten minutes'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: goal,
              style: AppTypography.body.copyWith(color: m.ink),
              decoration: deco('Daily · 10m'),
            ),
            const SizedBox(height: 18),
            MButton(
              label: 'Add habit',
              expand: true,
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                ref.read(habitActionsProvider).add(name.text, goal.text);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
    // Controllers are left to GC: disposing here races the sheet's exit
    // animation, which still renders the fields.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final habits = ref.watch(habitsProvider);
    final heat = ref.watch(habitHeatmapProvider);
    final logged = habits.where((h) => h.doneToday).length;
    final best = habits.fold<int>(0, (a, h) => h.streak > a ? h.streak : a);
    final total = heat.fold<int>(0, (a, b) => a + b);
    final maxPerDay = habits.isEmpty ? 1 : habits.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        MomentumTokens.gutter,
        MediaQuery.paddingOf(context).top + 14,
        MomentumTokens.gutter,
        130,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Habits',
                  style: AppTypography.heading1.copyWith(color: m.ink)),
            ),
            MButton(
              label: 'New',
              small: true,
              kind: MButtonKind.secondary,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _addHabit(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$logged of ${habits.length} logged today · best streak $best day${best == 1 ? '' : 's'}',
          style: AppTypography.caption.copyWith(color: m.inkSecondary),
        ),
        const SizedBox(height: 18),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel('Last 18 weeks',
                  trailing: Text('$total completions',
                      style: AppTypography.label
                          .copyWith(fontSize: 10, color: m.inkSecondary))),
              const SizedBox(height: 14),
              // 18 columns (weeks) × 7 rows (days).
              LayoutBuilder(builder: (context, c) {
                const cols = 18;
                const gap = 3.0;
                final cell = (c.maxWidth - gap * (cols - 1)) / cols;
                return Row(
                  children: [
                    for (var w = 0; w < cols; w++) ...[
                      Column(
                        children: [
                          for (var d = 0; d < 7; d++) ...[
                            _HeatCell(
                              size: cell,
                              level: _level(heat[w * 7 + d], maxPerDay),
                            ),
                            if (d < 6) const SizedBox(height: gap),
                          ],
                        ],
                      ),
                      if (w < cols - 1) const SizedBox(width: gap),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: MomentumTokens.sectionGap),
        if (habits.isEmpty)
          MomentumEmptyState(
            title: 'No habits yet',
            message: 'Small daily wins compound. Start with one.',
            actionLabel: 'Add a habit',
            onAction: () => _addHabit(context, ref),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            child: Column(
              children: [
                for (final h in habits)
                  Dismissible(
                    key: ValueKey(h.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child:
                          Icon(Icons.delete_outline_rounded, color: m.danger),
                    ),
                    onDismissed: (_) {
                      final actions = ref.read(habitActionsProvider)
                        ..remove(h.id);
                      showMomentumToast(
                        context,
                        'Habit removed',
                        actionLabel: 'Undo',
                        onAction: () => actions.restore(h.id),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          HabitToggle(
                              habit: h, child: HabitRing(done: h.doneToday)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.name,
                                    style: AppTypography.bodyStrong.copyWith(
                                      fontSize: 14,
                                      color: h.doneToday
                                          ? m.ink.withValues(alpha: .5)
                                          : m.ink,
                                    )),
                                const SizedBox(height: 2),
                                Text(h.goal,
                                    style: AppTypography.caption.copyWith(
                                        fontSize: 11.5, color: m.inkTertiary)),
                                const SizedBox(height: 8),
                                Row(children: [
                                  for (final v in h.week) ...[
                                    Container(
                                      width: 16,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: v
                                            ? m.violet.withValues(alpha: .8)
                                            : m.ink.withValues(alpha: .1),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                ]),
                              ],
                            ),
                          ),
                          Column(children: [
                            Text('${h.streak}',
                                style: AppTypography.heading2
                                    .copyWith(color: m.amber, fontSize: 20)),
                            Text('STREAK',
                                style: AppTypography.label.copyWith(
                                    fontSize: 8.5, color: m.inkTertiary)),
                          ]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static int _level(int count, int max) {
    if (count == 0) return 0;
    final r = count / max;
    if (r >= 1) return 4;
    if (r >= .66) return 3;
    if (r >= .33) return 2;
    return 1;
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.size, required this.level});
  final double size;
  final int level;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final colors = [
      m.ink.withValues(alpha: .055),
      m.violet.withValues(alpha: .22),
      m.violet.withValues(alpha: .45),
      m.violet.withValues(alpha: .78),
      m.amber,
    ];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[level],
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
