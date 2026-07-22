import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The EatStreak mark: an open ring with an accent arc and a dot core. Ported
/// from the Expo BrandMark SVG, drawn with a painter so it scales cleanly.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 48,
    this.color = AppColors.ink,
    this.accent = AppColors.primary,
  });

  final double size;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'EatStreak',
      child: CustomPaint(
        size: Size.square(size),
        painter: _BrandMarkPainter(color: color, accent: accent),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // The original is authored on a 64x64 viewBox; scale to whatever we're given.
    final scale = size.width / 64;
    final center = Offset(32 * scale, 32 * scale);
    final radius = 24 * scale;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * scale
      ..strokeCap = StrokeCap.round;

    // Main ring: an almost-complete arc, open at the top right.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _deg(-35),
      _deg(285),
      false,
      stroke..color = color,
    );

    // Accent arc closing most of the gap.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _deg(-75),
      _deg(70),
      false,
      stroke..color = accent,
    );

    canvas.drawCircle(center, 8 * scale, Paint()..color = color);
    canvas.drawCircle(center, 3 * scale, Paint()..color = accent);
  }

  static double _deg(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
}
