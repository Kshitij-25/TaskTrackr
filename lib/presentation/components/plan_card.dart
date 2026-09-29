import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../providers/momentum_provider.dart';
import '../providers/planner_provider.dart';
import '../providers/task_provider.dart';
import 'momentum_ui.dart';

/// "MOMENTUM AI" card on Today. Backed by the on-device planner.
class PlanCard extends ConsumerWidget {
  const PlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final plan = ref.watch(dayPlanProvider);
    final dismissed = ref.watch(planDismissedProvider);
    if (plan == null || !plan.hasAdvice || dismissed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MomentumTokens.radiusCard),
          border: Border.all(color: m.violet.withValues(alpha: .35)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              m.violet.withValues(alpha: m.isDark ? .16 : .08),
              m.cyan.withValues(alpha: m.isDark ? .08 : .04),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [m.amber, m.violet]),
                ),
              ),
              const SizedBox(width: 8),
              SectionLabel('Momentum AI', color: m.violet),
            ]),
            const SizedBox(height: 10),
            Text(plan.headline,
                style: AppTypography.bodyStrong
                    .copyWith(color: m.ink, fontSize: 14, height: 1.45)),
            const SizedBox(height: 14),
            Row(children: [
              MButton(
                label: 'Review plan',
                small: true,
                kind: MButtonKind.ai,
                onPressed: () =>
                    showMomentumSheet(context, (_) => const _PlanSheet()),
              ),
              const SizedBox(width: 8),
              MButton(
                label: 'Not now',
                small: true,
                kind: MButtonKind.ghost,
                onPressed: () {
                  ref.read(planDismissedProvider.notifier).dismiss();
                  showMomentumToast(context, 'Hidden for today');
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PlanSheet extends ConsumerWidget {
  const _PlanSheet();

  Future<void> _apply(
      BuildContext context, WidgetRef ref, List<PlanMove> moves) async {
    final actions = ref.read(taskActionsProvider);
    var moved = 0;
    var rolled = 0;
    String? focusId;
    for (final mv in moves) {
      switch (mv.kind) {
        case PlanKind.move:
          actions.moveTask(mv.task!, mv.to!).ignore();
          moved++;
        case PlanKind.rollover:
          rolled = await actions.rollOverOverdue();
        case PlanKind.focusFirst:
          focusId = mv.task!.id;
      }
    }
    if (focusId != null) {
      ref.read(focusProvider.notifier).selectTask(focusId);
    }
    ref.read(planDismissedProvider.notifier).dismiss();
    if (!context.mounted) return;
    Navigator.pop(context);
    final parts = [
      if (moved > 0) '$moved moved',
      if (rolled > 0) '$rolled rolled into today',
      if (focusId != null) 'focus set',
    ];
    showMomentumToast(
      context,
      parts.isEmpty ? 'Plan applied' : 'Plan applied · ${parts.join(' · ')}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final plan = ref.watch(dayPlanProvider);
    if (plan == null) return const SizedBox(height: 120);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        SectionLabel('Plan my day', color: m.violet),
        const SizedBox(height: 8),
        Text(plan.headline,
            style: AppTypography.heading2.copyWith(color: m.ink, fontSize: 18)),
        const SizedBox(height: 16),
        for (var i = 0; i < plan.moves.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              radius: MomentumTokens.radiusRow,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: m.violet.withValues(alpha: .18),
                    ),
                    child: Text('${i + 1}',
                        style: AppTypography.label
                            .copyWith(color: m.violet, letterSpacing: 0)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.moves[i].title,
                            style: AppTypography.bodyStrong
                                .copyWith(color: m.ink, fontSize: 13.5)),
                        const SizedBox(height: 4),
                        Text(plan.moves[i].why,
                            style: AppTypography.caption
                                .copyWith(color: m.inkSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: MButton(
              label: 'Accept all',
              onPressed: () => _apply(context, ref, plan.moves),
            ),
          ),
          const SizedBox(width: 8),
          MButton(
            label: 'Later',
            kind: MButtonKind.ghost,
            onPressed: () => Navigator.pop(context),
          ),
        ]),
        const SizedBox(height: 10),
        Center(
          child: Text('PLANNED ON-DEVICE · NOTHING LEAVES YOUR PHONE',
              style: AppTypography.label
                  .copyWith(fontSize: 9, color: m.inkTertiary)),
        ),
      ],
    );
  }
}
