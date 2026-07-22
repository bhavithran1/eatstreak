import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing scale from the Expo theme. Use these instead of literals.
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class Radii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 100;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

abstract final class Shadows {
  static const card = [
    BoxShadow(color: Color(0x2E000000), offset: Offset(0, 8), blurRadius: 20),
  ];

  static const floating = [
    BoxShadow(color: Color(0x47000000), offset: Offset(0, 12), blurRadius: 24),
  ];

  /// The glow under primary CTAs — the gradient button's colored drop shadow.
  static const primaryGlow = [
    BoxShadow(color: Color(0x4779A7FF), offset: Offset(0, 12), blurRadius: 24),
  ];
}

/// Hairline border used on cards and inputs throughout the app.
Border get hairline => Border.all(color: AppColors.line, width: 1);
Border get hairlineStrong => Border.all(color: AppColors.line2, width: 1);
