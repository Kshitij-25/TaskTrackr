import 'package:flutter/material.dart';

/// Momentum motion tokens. Nothing animates position/opacity past 360ms.
class AppMotion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration sheet = Duration(milliseconds: 360);
  static const Duration celebrate = Duration(milliseconds: 820);

  static const Curve ease = Cubic(0.2, 0.85, 0.2, 1);
  static const Curve easeCelebrate = Cubic(0.2, 0.7, 0.3, 1);
  static const Curve easeMicro = Curves.easeOutQuint;

  // Legacy names
  static const Duration fast = micro;
  static const Duration normal = standard;
  static const Duration slow = sheet;
  static const Curve easeSpring = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve easeSmooth = ease;
  static const double entrySlideOffset = 10;

  /// True when the OS asks for reduced motion (iOS Reduce Motion,
  /// Android "Remove animations").
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or a 120ms crossfade-length duration under reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? micro : d;
}
