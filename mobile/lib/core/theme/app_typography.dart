import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Two families, matching the Expo app: Space Grotesk for headings and numerals,
/// Inter for body copy. google_fonts fetches and caches them at runtime, so
/// there are no font binaries in the repo.
abstract final class AppText {
  static TextStyle heading({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.muted,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // ---- named roles ---------------------------------------------------------

  /// Screen title, e.g. "Customers".
  static TextStyle get screenTitle =>
      heading(size: 30, weight: FontWeight.w700, letterSpacing: -0.5);

  /// Section heading inside a screen.
  static TextStyle get sectionTitle => heading(size: 18, weight: FontWeight.w600);

  /// Big numerals — streak counts, KPI values.
  static TextStyle stat({double size = 32, Color color = AppColors.ink}) =>
      heading(size: size, weight: FontWeight.w700, color: color, letterSpacing: -1);

  /// All-caps eyebrow above a title.
  static TextStyle get eyebrow => body(
        size: 12,
        weight: FontWeight.w600,
        color: AppColors.muted2,
        letterSpacing: 1.4,
      );

  static TextStyle get bodyText => body(size: 15, height: 1.55);

  static TextStyle get caption => body(size: 13, color: AppColors.muted2);

  static TextStyle get buttonLabel =>
      heading(size: 16, weight: FontWeight.w600, letterSpacing: 0.3);
}
