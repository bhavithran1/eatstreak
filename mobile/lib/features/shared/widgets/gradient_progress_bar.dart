import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A track with a gradient fill, used for streak and reward-tier progress.
/// Animates to its new value so a check-in visibly advances the bar.
class GradientProgressBar extends StatelessWidget {
  const GradientProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.colors = const [AppColors.ember1, AppColors.ember2, AppColors.ember3],
    this.track = AppColors.line2,
  });

  /// 0..1; values outside are clamped.
  final double value;
  final double height;
  final List<Color> colors;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            LayoutBuilder(
              builder: (context, constraints) => AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * clamped,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
