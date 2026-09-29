import 'package:flutter/material.dart';

/// Legacy colour names, remapped onto the Momentum palette. New code should
/// read `context.m` (MomentumTokens) instead.
class AppColors {
  // Brand Primary
  static const Color primaryLight = Color(0xFFEDEDFC);
  static const Color primary = Color(0xFF7156D8);
  static const Color primaryDark = Color(0xFF5B41C0);
  static const Color accent = Color(0xFF1ACFDF);

  // Semantic States
  static const Color success = Color(0xFF6AD895);
  static const Color warning = Color(0xFFFCBE54);
  static const Color danger = Color(0xFFFD717C);

  // Priority Colors
  static const Color high = Color(0xFFFD717C);
  static const Color medium = Color(0xFFFCBE54);
  static const Color low = Color(0xFF1ACFDF);

  // Neutral Scale
  static const Color neutral50 = Color(0xFFFAFAFC);
  static const Color neutral100 = Color(0xFFF2F2F7);
  static const Color neutral200 = Color(0xFFE4E4EC);
  static const Color neutral400 = Color(0xFF9A9AAA);
  static const Color neutral600 = Color(0xFF4A4A58);
  static const Color neutral800 = Color(0xFF14141A);

  // Dark Mode Surfaces (AMOLED)
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0E0E14);
  static const Color darkSurface2 = Color(0xFF17171F);
  static const Color darkBorder = Color(0xFF26262F);
}
