import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Momentum design tokens. AMOLED and Light are two instances of one set —
/// widgets read colours from here, never raw hex.
@immutable
class MomentumTokens extends ThemeExtension<MomentumTokens> {
  const MomentumTokens({
    required this.isDark,
    required this.canvas,
    required this.surface,
    required this.glass,
    required this.raised,
    required this.stroke,
    required this.violet,
    required this.cyan,
    required this.amber,
    required this.success,
    required this.danger,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.onAccent,
    required this.auroraA,
    required this.auroraB,
    required this.scrim,
    required this.sheetBlur,
  });

  final bool isDark;
  final Color canvas;
  final Color surface;
  final Color glass;
  final Color raised;
  final Color stroke;
  final Color violet;
  final Color cyan;
  final Color amber;
  final Color success;
  final Color danger;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color onAccent;
  final Color auroraA;
  final Color auroraB;
  final Color scrim;
  final double sheetBlur;

  static const dark = MomentumTokens(
    isDark: true,
    canvas: Color(0xFF000000),
    surface: Color(0x0BFFFFFF), // .042
    glass: Color(0x0EFFFFFF), // .055
    raised: Color(0x17FFFFFF), // .09
    stroke: Color(0x1AFFFFFF), // .10
    violet: Color(0xFFA798FF),
    cyan: Color(0xFF1ACFDF),
    amber: Color(0xFFFCBE54),
    success: Color(0xFF6AD895),
    danger: Color(0xFFFD717C),
    ink: Color(0xF0FFFFFF), // .94
    inkSecondary: Color(0x9EFFFFFF), // .62
    inkTertiary: Color(0x61FFFFFF), // .38
    onAccent: Color(0xFF0B0B12),
    auroraA: Color(0x804B4185),
    auroraB: Color(0x6100636D),
    scrim: Color(0x9E040408),
    sheetBlur: 34,
  );

  static const light = MomentumTokens(
    isDark: false,
    canvas: Color(0xFFFAFAFC),
    surface: Color(0xFFFFFFFF),
    glass: Color(0xB8FFFFFF), // .72
    raised: Color(0xFFEDEDFC),
    stroke: Color(0x1712121C), // .09
    violet: Color(0xFF7156D8),
    cyan: Color(0xFF0083A0),
    amber: Color(0xFFBE7200),
    success: Color(0xFF0E9254),
    danger: Color(0xFFD33949),
    ink: Color(0xFF14141A),
    inkSecondary: Color(0x9914141A), // .6
    inkTertiary: Color(0x6614141A), // .4
    onAccent: Color(0xFFFFFFFF),
    auroraA: Color(0x407156D8),
    auroraB: Color(0x3300A3C0),
    scrim: Color(0x5914141A),
    sheetBlur: 20,
  );

  static const radiusChip = 9.0;
  static const radiusButton = 14.0;
  static const radiusRow = 20.0;
  static const radiusCard = 26.0;
  static const radiusSheet = 32.0;
  static const gutter = 16.0;
  static const sectionGap = 26.0;

  /// Signature amber → violet → cyan sweep used for XP, completion and rings.
  List<Color> get aurora => [amber, violet, cyan];

  Color priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return danger;
      case 'medium':
      case 'med':
        return amber;
      default:
        return cyan;
    }
  }

  Color projectColor(String project) {
    switch (project.toLowerCase()) {
      case 'work':
        return violet;
      case 'personal':
        return success;
      case 'health':
        return danger;
      case 'finance':
      case 'learning':
        return amber;
      default:
        return cyan;
    }
  }

  /// Flat glass card (e1). No BackdropFilter — cheap inside scrollables.
  BoxDecoration card({double radius = radiusCard, Color? tint}) =>
      BoxDecoration(
        color: tint ?? (isDark ? glass : surface),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: stroke),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: violet.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
      );

  @override
  MomentumTokens copyWith() => this;

  @override
  MomentumTokens lerp(ThemeExtension<MomentumTokens>? other, double t) {
    if (other is! MomentumTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MomentumTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      glass: c(glass, other.glass),
      raised: c(raised, other.raised),
      stroke: c(stroke, other.stroke),
      violet: c(violet, other.violet),
      cyan: c(cyan, other.cyan),
      amber: c(amber, other.amber),
      success: c(success, other.success),
      danger: c(danger, other.danger),
      ink: c(ink, other.ink),
      inkSecondary: c(inkSecondary, other.inkSecondary),
      inkTertiary: c(inkTertiary, other.inkTertiary),
      onAccent: c(onAccent, other.onAccent),
      auroraA: c(auroraA, other.auroraA),
      auroraB: c(auroraB, other.auroraB),
      scrim: c(scrim, other.scrim),
      sheetBlur: lerpDouble(sheetBlur, other.sheetBlur, t)!,
    );
  }
}

extension MomentumContext on BuildContext {
  MomentumTokens get m =>
      Theme.of(this).extension<MomentumTokens>() ?? MomentumTokens.dark;
}
