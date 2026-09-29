import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The TaskTrackr mark: a momentum loop. An open aurora arc (amber → violet
/// → cyan) that is almost a full circle, with a bright dot at its leading
/// end — today's win closing the loop.
///
/// One painter feeds both the in-app logo and the generated app icons
/// (`tool/icon_gen`), so they can never drift apart.
class MomentumMarkPainter extends CustomPainter {
  const MomentumMarkPainter({
    this.withBackground = false,
    this.scale = 1,
    this.glow = true,
  });

  /// Paint the AMOLED tile + aurora wash behind the mark (app icon).
  final bool withBackground;

  /// Shrinks the mark inside the canvas, e.g. for Android's adaptive-icon
  /// safe zone.
  final double scale;

  /// Soft light under the arc and dot. Off for tiny sizes.
  final bool glow;

  static const amber = Color(0xFFFCBE54);
  static const violet = Color(0xFFA798FF);
  static const cyan = Color(0xFF1ACFDF);
  static const dotCore = Color(0xFFFFF1CF);

  // Arc starts just right of 12 o'clock and runs clockwise, leaving a gap at
  // the top; the dot sits at the head.
  static const _start = -math.pi / 2 + 0.62;
  static const _sweep = 2 * math.pi - 1.05;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);

    if (withBackground) {
      final rect = Offset.zero & size;
      canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
      void wash(Offset at, double r, Color color) {
        final rr = Rect.fromCircle(center: at, radius: r);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ).createShader(rr),
        );
      }

      wash(Offset(s * .18, s * .12), s * .85, const Color(0x8C4B4185));
      wash(Offset(s * .95, s * .98), s * .70, const Color(0x6600636D));
    }

    final r = s * .30 * scale;
    final w = s * .105 * scale;
    final arcRect = Rect.fromCircle(center: c, radius: r);

    // Sweep angles must sit in 0..2π, so build the gradient from 0 and
    // rotate it onto the arc instead of passing a negative start.
    // Pad past both round caps (≈0.18 rad each) so neither picks up the
    // colour from the far end of the sweep.
    const pad = 0.22;
    final gradient = const SweepGradient(
      endAngle: _sweep + 2 * pad,
      colors: [amber, violet, cyan],
      stops: [0, .55, 1],
      transform: GradientRotation(_start - pad),
    ).createShader(arcRect);

    if (glow) {
      canvas.drawArc(
        arcRect,
        _start,
        _sweep,
        false,
        Paint()
          // Paint alpha scales the shader: a soft halo, not a wash.
          ..color = const Color(0x73000000)
          ..shader = gradient
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 1.25
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .032 * scale),
      );
    }

    canvas.drawArc(
      arcRect,
      _start,
      _sweep,
      false,
      Paint()
        ..shader = gradient
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );

    // The head: a bright dot just past the end of the arc.
    const head = _start + _sweep + 0.42;
    final dot = c + Offset(math.cos(head), math.sin(head)) * r;
    final dotR = w * .62;
    if (glow) {
      canvas.drawCircle(
        dot,
        dotR * 1.7,
        Paint()
          ..color = amber.withValues(alpha: .4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .03 * scale),
      );
    }
    canvas.drawCircle(
      dot,
      dotR,
      Paint()
        ..shader = const RadialGradient(
          colors: [dotCore, amber],
          stops: [.25, 1],
        ).createShader(Rect.fromCircle(center: dot, radius: dotR)),
    );
  }

  @override
  bool shouldRepaint(MomentumMarkPainter old) =>
      old.withBackground != withBackground ||
      old.scale != scale ||
      old.glow != glow;
}

/// The logo as a widget. [tile] draws it on the black app-icon tile with
/// rounded corners, as it appears on the home screen.
class MomentumLogo extends StatelessWidget {
  const MomentumLogo({super.key, this.size = 72, this.tile = false});
  final double size;
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: MomentumMarkPainter(withBackground: tile, glow: size >= 28),
    );
    if (!tile) return mark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .225),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: MomentumMarkPainter.violet.withValues(alpha: .35),
            blurRadius: size * .5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .225),
        child: mark,
      ),
    );
  }
}
