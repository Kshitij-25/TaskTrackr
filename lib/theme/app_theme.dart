import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'momentum_tokens.dart';

class AppTheme {
  static ThemeData get light => _build(MomentumTokens.light);
  static ThemeData get dark => _build(MomentumTokens.dark);

  static ThemeData _build(MomentumTokens m) {
    final brightness = m.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: m.violet,
      brightness: brightness,
    ).copyWith(
      primary: m.violet,
      onPrimary: m.onAccent,
      secondary: m.cyan,
      onSecondary: m.onAccent,
      tertiary: m.amber,
      error: m.danger,
      surface: m.isDark ? const Color(0xFF0B0B12) : m.surface,
      onSurface: m.ink,
      outline: m.stroke,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: m.violet,
      scaffoldBackgroundColor: m.canvas,
      canvasColor: m.canvas,
      dividerColor: m.stroke,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: [m],
      textTheme: TextTheme(
        displayLarge: AppTypography.display.copyWith(color: m.ink),
        headlineLarge: AppTypography.heading1.copyWith(color: m.ink),
        headlineMedium: AppTypography.heading2.copyWith(color: m.ink),
        titleMedium: AppTypography.bodyStrong.copyWith(color: m.ink),
        bodyLarge: AppTypography.body.copyWith(color: m.ink),
        bodyMedium: AppTypography.body.copyWith(color: m.ink),
        bodySmall: AppTypography.caption.copyWith(color: m.inkSecondary),
        labelLarge: AppTypography.label.copyWith(color: m.inkSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: m.ink,
        titleTextStyle: AppTypography.heading2.copyWith(color: m.ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: m.isDark ? const Color(0xFF1A1A24) : m.ink,
        contentTextStyle: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.violet : m.raised,
        ),
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: m.inkSecondary,
        textColor: m.ink,
      ),
    );
  }
}
