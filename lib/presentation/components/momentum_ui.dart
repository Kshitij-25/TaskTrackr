import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';

// ───────────────────────────── Aurora ──────────────────────────────────────

/// The drifting aurora behind every screen. One layer, one RepaintBoundary —
/// never animated per card. Freezes under reduce-motion.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.intensity = 1});

  final double intensity;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return RepaintBoundary(
      child: ColoredBox(
        color: m.canvas,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _AuroraPainter(_c.value, m, widget.intensity),
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.m, this.intensity);
  final double t;
  final MomentumTokens m;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    void blob(Color c, Offset centre, double rx, double ry) {
      final rect =
          Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [
            c.withValues(alpha: c.a * intensity),
            c.withValues(alpha: 0),
          ]).createShader(rect),
      );
    }

    final w = size.width;
    final h = size.height;
    final s1 = 1 + 0.12 * (0.5 - 0.5 * math.cos(a));
    blob(
      m.auroraA,
      Offset(w * (0.08 + 0.06 * math.sin(a)), h * (-0.04 - 0.03 * math.sin(a))),
      w * 0.95 * s1,
      h * 0.42 * s1,
    );
    blob(
      m.auroraB,
      Offset(w * (1.0 - 0.07 * math.sin(a)), h * (0.04 + 0.04 * math.sin(a))),
      w * 0.75,
      h * 0.34,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.m != m;
}

// ───────────────────────────── Surfaces ────────────────────────────────────

/// e1 — flat glass card. White-alpha fill + hairline, no blur.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = MomentumTokens.radiusCard,
    this.onTap,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: context.m.card(radius: radius, tint: tint),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

/// e2/e3 — real backdrop blur. Only for tab bar, sheets and toasts.
class GlassBlur extends StatelessWidget {
  const GlassBlur({
    super.key,
    required this.child,
    this.radius = MomentumTokens.radiusCard,
    this.blur = 30,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: m.isDark ? 0.6 : 0.1),
            blurRadius: 44,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: br,
              color: m.isDark
                  ? const Color(0xB8121219)
                  : Colors.white.withValues(alpha: 0.78),
              border: Border.all(color: m.stroke),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Press = scale .97 over 120ms.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down && !AppMotion.reduced(context) ? 0.97 : 1,
        duration: AppMotion.micro,
        curve: AppMotion.easeMicro,
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────────── Type helpers ────────────────────────────────

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final row = Text(
      text.toUpperCase(),
      style:
          AppTypography.label.copyWith(color: color ?? context.m.inkTertiary),
    );
    if (trailing == null) return row;
    return Row(children: [Expanded(child: row), trailing!]);
  }
}

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(colors: m.aurora).createShader(r),
      child: Text(text, style: style),
    );
  }
}

// ───────────────────────────── Controls ────────────────────────────────────

/// The completion circle. Amber→violet fill + glow + tick when done.
class CheckDot extends StatelessWidget {
  const CheckDot({
    super.key,
    required this.done,
    required this.onTap,
    this.size = 22,
    this.square = false,
  });

  final bool done;
  final void Function(Offset globalCentre) onTap;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final radius = square ? 6.0 : size / 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        final c = box == null
            ? Offset.zero
            : box.localToGlobal(box.size.center(Offset.zero));
        onTap(c);
      },
      child: Padding(
        // 44pt target around a 22pt mark.
        padding: EdgeInsets.all((44 - size) / 2),
        child: AnimatedContainer(
          duration: AppMotion.of(context, const Duration(milliseconds: 300)),
          curve: AppMotion.ease,
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              width: 2,
              color: done ? Colors.transparent : m.ink.withValues(alpha: 0.3),
            ),
            gradient: done
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [m.amber, m.violet],
                  )
                : null,
            boxShadow: done && m.isDark
                ? [
                    BoxShadow(
                        color: m.violet.withValues(alpha: .55), blurRadius: 16)
                  ]
                : null,
          ),
          child: AnimatedScale(
            // Reduced motion: no scale, the tick just appears.
            scale: done || AppMotion.reduced(context) ? 1 : 0,
            duration: AppMotion.of(context, AppMotion.standard),
            curve: AppMotion.ease,
            child: Opacity(
              opacity: done ? 1 : 0,
              child: Icon(Icons.check_rounded,
                  size: size * 0.62, color: const Color(0xFF0B0B12)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The habit ring: conic amber→violet→cyan when logged.
class HabitRing extends StatelessWidget {
  const HabitRing({super.key, required this.done, this.size = 40});
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 350)),
      curve: AppMotion.ease,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: 2,
          color: done ? Colors.transparent : m.ink.withValues(alpha: .22),
        ),
        gradient: done
            ? SweepGradient(
                startAngle: math.pi,
                endAngle: math.pi * 3,
                colors: [m.amber, m.violet, m.cyan, m.amber],
                transform: const GradientRotation(math.pi / 2),
              )
            : null,
        boxShadow: done && m.isDark
            ? [BoxShadow(color: m.violet.withValues(alpha: .5), blurRadius: 20)]
            : null,
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 300)),
        width: done ? size * .35 : size * .25,
        height: done ? size * .35 : size * .25,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? m.canvas : m.ink.withValues(alpha: .2),
        ),
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, required this.color, this.dot = false});
  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(MomentumTokens.radiusChip),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter / segmented chip: solid ink when selected.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Pressable(
      haptic: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.standard),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? m.ink.withValues(alpha: m.isDark ? .92 : 1)
              : m.ink.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
          border: Border.all(
              color:
                  selected ? Colors.transparent : m.ink.withValues(alpha: .1)),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 1,
            color: selected ? m.canvas : m.inkSecondary,
          ),
        ),
      ),
    );
  }
}

enum MButtonKind { primary, secondary, ghost, destructive, ai }

class MButton extends StatelessWidget {
  const MButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = MButtonKind.primary,
    this.icon,
    this.small = false,
    this.expand = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final MButtonKind kind;
  final Widget? icon;
  final bool small;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final disabled = onPressed == null || loading;

    Color fg;
    BoxDecoration deco;
    final r = BorderRadius.circular(MomentumTokens.radiusButton);
    switch (kind) {
      case MButtonKind.primary:
        fg = m.isDark ? const Color(0xFF0B0B12) : Colors.white;
        deco = BoxDecoration(
          borderRadius: r,
          color: m.isDark ? Colors.white.withValues(alpha: .94) : m.ink,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: (m.isDark ? Colors.white : m.violet)
                        .withValues(alpha: m.isDark ? .12 : .25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
        );
      case MButtonKind.ai:
        fg = const Color(0xFF0B0B12);
        deco = BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(colors: [m.amber, m.violet]),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                      color: m.violet.withValues(alpha: .4), blurRadius: 22)
                ],
        );
      case MButtonKind.secondary:
        fg = m.ink;
        deco = BoxDecoration(
          borderRadius: r,
          color: m.ink.withValues(alpha: .08),
          border: Border.all(color: m.ink.withValues(alpha: .12)),
        );
      case MButtonKind.ghost:
        fg = m.inkSecondary;
        deco = BoxDecoration(borderRadius: r);
      case MButtonKind.destructive:
        fg = m.danger;
        deco = BoxDecoration(
          borderRadius: r,
          color: m.danger.withValues(alpha: .12),
          border: Border.all(color: m.danger.withValues(alpha: .3)),
        );
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          IconTheme(data: IconThemeData(color: fg, size: 18), child: icon!),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong.copyWith(
              color: fg,
              fontSize: small ? 12.5 : 14,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: onPressed == null ? .38 : 1,
      child: Pressable(
        onTap: disabled ? null : onPressed,
        child: Container(
          height: small ? 36 : 48,
          padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
          decoration: deco,
          child: content,
        ),
      ),
    );
  }
}

/// XP bar: amber → violet → cyan with glow.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress, this.height = 8});
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: m.ink.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(height),
      ),
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, c) => AnimatedContainer(
          duration: AppMotion.of(context, const Duration(milliseconds: 600)),
          curve: AppMotion.ease,
          width: c.maxWidth * progress.clamp(0.02, 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: LinearGradient(
              colors: m.aurora,
              stops: const [0, .6, 1],
            ),
            boxShadow: m.isDark
                ? [
                    BoxShadow(
                        color: m.violet.withValues(alpha: .6), blurRadius: 18)
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

/// Avatar with an aurora ring and optional level badge.
class LevelAvatar extends StatelessWidget {
  const LevelAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.level,
    this.size = 44,
  });

  final String name;
  final String? photoUrl;
  final int? level;
  final double size;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'U';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return SizedBox(
      width: size + 6,
      height: size + 10,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: size + 4,
            height: size + 4,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  SweepGradient(colors: [m.amber, m.violet, m.cyan, m.amber]),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: m.isDark ? const Color(0xFF14141C) : m.raised,
                image: photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(photoUrl!), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: photoUrl == null
                  ? Text(
                      initials,
                      style: AppTypography.heading2.copyWith(
                        fontSize: size * .34,
                        color: m.ink,
                      ),
                    )
                  : null,
            ),
          ),
          if (level != null)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: m.amber,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: m.canvas, width: 2),
                ),
                child: Text(
                  'L$level',
                  style: AppTypography.label.copyWith(
                    fontSize: 9,
                    letterSpacing: .3,
                    color: const Color(0xFF0B0B12),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The brand crest: conic aurora rounded square with a momentum mark.
class MomentumCrest extends StatelessWidget {
  const MomentumCrest({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        gradient: SweepGradient(
          colors: [m.amber, m.violet, m.cyan, m.amber],
          transform: const GradientRotation(math.pi * 1.15),
        ),
        boxShadow: [
          BoxShadow(
            color: m.violet.withValues(alpha: m.isDark ? .55 : .35),
            blurRadius: size * .6,
          ),
        ],
      ),
      child: CustomPaint(painter: _CrestMarkPainter()),
    );
  }
}

class _CrestMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0xFF0B0B12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * .085
      ..strokeCap = StrokeCap.round;
    // Arc = momentum; dot = today.
    final c = s.center(Offset.zero);
    final r = s.width * .24;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi * .75,
        math.pi * 1.5, false, p);
    canvas.drawCircle(
      c + Offset(r * math.cos(math.pi * .25), r * math.sin(math.pi * .25)),
      s.width * .07,
      Paint()..color = const Color(0xFF0B0B12),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ───────────────────────────── Feedback ────────────────────────────────────

/// App-wide messenger so toasts survive the sheet that raised them closing.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showMomentumToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = rootMessengerKey.currentState ??
      (context.mounted ? ScaffoldMessenger.maybeOf(context) : null);
  if (messenger == null) return;
  final m = messenger.context.m;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: m.isDark ? m.amber : const Color(0xFFFCBE54),
              onPressed: onAction ?? () {},
            ),
      duration: Duration(milliseconds: actionLabel == null ? 2600 : 4000),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
    ));
}

/// 16-particle burst at [globalCentre]. Pooled via a single overlay entry.
void showXpBurst(BuildContext context, Offset globalCentre) {
  if (AppMotion.reduced(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final m = context.m;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _Burst(
        centre: globalCentre,
        colors: [m.amber, m.violet, m.cyan, m.success],
        onDone: () => entry.remove(),
      ),
    ),
  );
  overlay.insert(entry);
}

class _Burst extends StatefulWidget {
  const _Burst(
      {required this.centre, required this.colors, required this.onDone});
  final Offset centre;
  final List<Color> colors;
  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.celebrate)
        ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _BurstPainter(
          AppMotion.easeCelebrate.transform(_c.value),
          widget.centre,
          widget.colors,
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.c, this.colors);
  final double t;
  final Offset c;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * math.pi * 2;
      final d = (46 + (i % 4) * 16) * t;
      final pos = c + Offset(math.cos(a) * d, math.sin(a) * d);
      final r = (i % 3 == 0 ? 3.5 : 2.5) * (1 - .6 * t);
      final paint = Paint()..color = colors[i % 4].withValues(alpha: 1 - t);
      if (i.isOdd) {
        canvas.drawCircle(pos, r, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: pos, width: r * 2, height: r * 2),
              const Radius.circular(1.5)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

// ───────────────────────────── Sheets ──────────────────────────────────────

/// e3 sheet: blurred glass, 32 radius, scrim.
Future<T?> showMomentumSheet<T>(BuildContext context, WidgetBuilder builder) {
  final m = context.m;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: m.scrim,
    elevation: 0,
    sheetAnimationStyle: AppMotion.reduced(context)
        ? const AnimationStyle(
            duration: AppMotion.micro,
            reverseDuration: AppMotion.micro,
          )
        : null,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MomentumTokens.radiusSheet)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: m.sheetBlur / 2, sigmaY: m.sheetBlur / 2),
          child: Container(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .9),
            decoration: BoxDecoration(
              color: m.isDark
                  ? const Color(0xE00E0E15)
                  : Colors.white.withValues(alpha: .9),
              border: Border(top: BorderSide(color: m.stroke)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: m.ink.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Flexible(child: builder(ctx)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pick one of a short list of options in a Momentum sheet.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<(String label, T value, Color? color)> options,
  T? selected,
}) {
  return showMomentumSheet<T>(context, (ctx) {
    final m = ctx.m;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Text(title, style: AppTypography.heading2.copyWith(color: m.ink)),
        const SizedBox(height: 10),
        for (final (label, value, color) in options)
          Pressable(
            onTap: () => Navigator.pop(ctx, value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color ?? m.ink.withValues(alpha: .3),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: AppTypography.bodyStrong.copyWith(color: m.ink)),
                ),
                if (value == selected)
                  Icon(Icons.check_rounded, size: 18, color: m.violet),
              ]),
            ),
          ),
      ],
    );
  });
}

/// Name the win, then offer exactly one action.
class MomentumEmptyState extends StatelessWidget {
  const MomentumEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: m.ink.withValues(alpha: .16)),
            ),
            child: Icon(Icons.circle_outlined, size: 18, color: m.inkTertiary),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(color: m.ink)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: m.inkSecondary)),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            MButton(
              label: actionLabel!,
              onPressed: onAction,
              kind: MButtonKind.secondary,
              small: true,
            ),
          ],
        ],
      ),
    );
  }
}
