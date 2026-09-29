import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import '../providers/momentum_provider.dart';
import '../providers/task_provider.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    ref.read(focusProvider.notifier).onComplete = () {
      if (mounted)
        showMomentumToast(
            context,
            ref.read(gamificationProvider) == GamificationMode.off
                ? 'Session complete · take five'
                : 'Session complete · +$focusXp XP banked');
    };
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _pickTask(List<TaskModel> open) {
    final m = context.m;
    showMomentumSheet(
      context,
      (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text('Focus on…',
              style: AppTypography.heading2.copyWith(color: m.ink)),
          const SizedBox(height: 12),
          if (open.isEmpty)
            Text('No open tasks — focus freely.',
                style: AppTypography.body.copyWith(color: m.inkSecondary)),
          for (final t in open)
            Pressable(
              onTap: () {
                ref.read(focusProvider.notifier).selectTask(t.id);
                Navigator.pop(ctx);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: m.priorityColor(t.priority),
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(t.title,
                        style: AppTypography.bodyStrong.copyWith(color: m.ink)),
                  ),
                  Text(t.estimateLabel,
                      style:
                          AppTypography.label.copyWith(color: m.inkTertiary)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final f = ref.watch(focusProvider);
    final tasks = ref.watch(taskListProvider).value ?? const <TaskModel>[];
    final open = tasks.where((t) => !t.isCompleted).toList();
    final task = tasks.where((t) => t.id == f.taskId).firstOrNull ??
        (open.isEmpty ? null : open.first);

    if (f.running && !AppMotion.reduced(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }

    final mm = (f.left ~/ 60).toString().padLeft(2, '0');
    final ss = (f.left % 60).toString().padLeft(2, '0');
    final stateLabel = f.running
        ? 'IN FLOW · DO NOT DISTURB'
        : f.left == 0
            ? 'BREAK TIME · 5 MIN'
            : 'READY WHEN YOU ARE';
    final cta = f.running
        ? 'Pause'
        : f.left == focusLength || f.left == 0
            ? 'Start 25 minutes'
            : 'Resume';
    final h = f.minutesToday ~/ 60;
    final mins = f.minutesToday % 60;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        MomentumTokens.gutter,
        MediaQuery.paddingOf(context).top + 14,
        MomentumTokens.gutter,
        130,
      ),
      children: [
        Center(
          child: Text('DEEP WORK · SESSION ${f.sessionsToday + 1}',
              style: AppTypography.label.copyWith(color: m.inkTertiary)),
        ),
        const SizedBox(height: 26),
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                painter: _RingPainter(
                  progress: 1 - f.left / focusLength,
                  pulse: f.running ? _pulse.value : -1,
                  m: m,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$mm:$ss',
                          style: AppTypography.display.copyWith(
                            fontSize: 58,
                            color: m.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                      const SizedBox(height: 8),
                      Text(stateLabel,
                          style: AppTypography.label.copyWith(
                              fontSize: 9.5,
                              color: f.running ? m.amber : m.inkTertiary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        GlassCard(
          onTap: f.running ? null : () => _pickTask(open),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Current task'),
                    const SizedBox(height: 8),
                    Text(task?.title ?? 'Free focus — no task picked',
                        style: AppTypography.bodyStrong.copyWith(color: m.ink)),
                    if (task != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        TagChip(task.category,
                            color: m.projectColor(task.category)),
                        const SizedBox(width: 8),
                        if (task.estimateLabel.isNotEmpty)
                          Text('${task.estimateLabel} planned',
                              style: AppTypography.label.copyWith(
                                  fontSize: 10, color: m.inkTertiary)),
                      ]),
                    ],
                  ],
                ),
              ),
              if (!f.running)
                Icon(Icons.unfold_more_rounded, color: m.inkTertiary, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: MButton(
              label: cta,
              kind: f.running ? MButtonKind.secondary : MButtonKind.primary,
              onPressed: () {
                final n = ref.read(focusProvider.notifier);
                if (f.running) {
                  n.pause();
                  showMomentumToast(
                      context, 'Paused — the ring keeps your place');
                } else {
                  n.start(taskId: f.taskId ?? task?.id);
                  if (f.left == focusLength || f.left == 0) {
                    showMomentumToast(context, 'Focus started · stay with it');
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          MButton(
            label: 'Reset',
            kind: MButtonKind.ghost,
            onPressed: f.fresh ? null : ref.read(focusProvider.notifier).reset,
          ),
        ]),
        const SizedBox(height: MomentumTokens.sectionGap),
        Row(children: [
          _Stat(h > 0 ? '${h}h ${mins}m' : '${mins}m', 'DEEP WORK TODAY',
              m.amber),
          const SizedBox(width: 8),
          _Stat('${f.sessionsToday}/4', 'SESSIONS', m.cyan),
          const SizedBox(width: 8),
          if (ref.watch(gamificationProvider) == GamificationMode.off)
            _Stat('${f.sessionsToday * 25}m', 'FOCUSED TODAY', m.violet)
          else
            _Stat('+${f.sessionsToday * focusXp}', 'XP BANKED', m.violet),
        ]),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Expanded(
      child: GlassCard(
        radius: MomentumTokens.radiusRow,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(children: [
          Text(value,
              style:
                  AppTypography.heading2.copyWith(color: color, fontSize: 20)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: AppTypography.label
                  .copyWith(fontSize: 8.5, color: m.inkTertiary)),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.pulse, required this.m});
  final double progress;
  final double pulse; // -1 = off
  final MomentumTokens m;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 14;

    if (pulse >= 0) {
      final t = (pulse / .7).clamp(0.0, 1.0);
      canvas.drawCircle(
        c,
        r * (1 + .12 * t),
        Paint()
          ..color = m.violet.withValues(alpha: .35 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10,
      );
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = m.ink.withValues(alpha: .08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    final remaining = 1 - progress;
    if (remaining <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final arc = Paint()
      ..shader = SweepGradient(
        colors: [m.amber, m.violet, m.cyan, m.amber],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    if (m.isDark) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * remaining,
        false,
        Paint()
          ..color = m.violet.withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * remaining, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.pulse != pulse || old.m != m;
}
