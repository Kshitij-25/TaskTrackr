import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Space Grotesk for numerals and heads, Manrope for reading, mono for labels.
class AppTypography {
  /// Display 34 — timer, level, streak.
  static TextStyle get display => GoogleFonts.spaceGrotesk(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        height: 1.05,
      );

  /// Title 27 — screen titles.
  static TextStyle get heading1 => GoogleFonts.spaceGrotesk(
        fontSize: 27,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.55,
        height: 1.15,
      );

  /// Headline 19 — sheet and card heads.
  static TextStyle get heading2 => GoogleFonts.spaceGrotesk(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  /// Body strong 14.5 — task titles.
  static TextStyle get bodyStrong => GoogleFonts.manrope(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      );

  /// Body 14 — notes, descriptions.
  static TextStyle get body => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
      );

  static TextStyle get caption => GoogleFonts.manrope(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  /// Label 11 — mono, +14% tracking. Section heads, metadata, numerals.
  static TextStyle get label => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      );
}
