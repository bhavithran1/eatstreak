import 'package:flutter/material.dart';

/// Ported verbatim from the Expo app's src/constants/theme.ts so the two apps
/// render the same palette during the migration.
abstract final class AppColors {
  static const bg = Color(0xFF090E17);
  static const bg2 = Color(0xFF0C121D);

  static const ink = Color(0xFFF3F6FB);
  static const muted = Color(0xFF9BA8BA);
  static const muted2 = Color(0xFF657287);

  static const line = Color(0x14F4F2EA); // rgba(244,242,234,0.08)
  static const line2 = Color(0x24F4F2EA); // rgba(244,242,234,0.14)

  static const card = Color(0xFF121A27);
  static const card2 = Color(0xFF182334);
  static const elevated = Color(0xFF1E2B40);

  static const primary = Color(0xFF79A7FF);
  static const primaryPressed = Color(0xFF5F8FE9);
  static const primaryInk = Color(0xFF07111F);
  static const primarySoft = Color(0x1F79A7FF); // rgba(121,167,255,0.12)
  static const primaryBorder = Color(0x3D79A7FF); // rgba(121,167,255,0.24)

  /// Legacy aliases kept so ported screens stay visually identical.
  static const ember1 = Color(0xFFC8DAFF);
  static const ember2 = Color(0xFF79A7FF);
  static const ember3 = Color(0xFF477DE7);

  static const success = Color(0xFF61D1B3);
  static const error = Color(0xFFFF796D);
  static const warning = Color(0xFFF2C96D);

  /// The brand gradient, top-left to bottom-right.
  static const gradient = LinearGradient(
    colors: [ember1, ember2, ember3],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
