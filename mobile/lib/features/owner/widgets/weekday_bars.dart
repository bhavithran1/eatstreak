import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/owner_analytics.dart';

/// Which days of the week the shop is actually busy, as seven bars.
///
/// The 30-day line above it answers "are we growing"; this answers "when do I
/// need staff", which is the question an owner can act on this week. The peak
/// day is filled and labelled — the rest are deliberately quiet, because the
/// comparison is what carries the meaning, not the individual heights.
///
/// Every dimension comes from the incoming constraints or the text metrics.
/// Nothing here is a fixed pixel size: this widget is in the layout stress test
/// at 2.0x text on a 320pt phone, and a hardcoded bar width or label column is
/// exactly what fails there.
class WeekdayBars extends StatelessWidget {
  const WeekdayBars({
    super.key,
    required this.counts,
    this.barHeight = 72,
  });

  /// Seven counts, index 0 = Monday, matching `DateTime.weekday - 1`.
  final List<int> counts;

  /// Height of the bar track before text scaling. Scaled with the text setting
  /// so the chart grows with the labels rather than being crowded out by them.
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // Clamped: at 2.0x an unclamped track pushes the card past a short screen,
    // and the bars stop being comparable long before that helps anyone.
    final track = barHeight * scale.clamp(1.0, 1.4);

    final max = counts.isEmpty
        ? 0
        : counts.reduce((a, b) => a > b ? a : b);
    final peak = max == 0 ? -1 : counts.indexOf(max);

    if (max == 0) {
      return SizedBox(
        height: track,
        child: Center(
          child: Text(
            'No visits recorded yet this month.',
            textAlign: TextAlign.center,
            style: AppText.body(size: 12, color: AppColors.muted2),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < counts.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _bar(
                count: counts[i],
                fraction: counts[i] / max,
                weekday: i + 1,
                isPeak: i == peak,
                track: track,
              ),
            ),
          ),
      ],
    );
  }

  Widget _bar({
    required int count,
    required double fraction,
    required int weekday,
    required bool isPeak,
    required double track,
  }) {
    final color = isPeak ? AppColors.primary : AppColors.line2;

    return Semantics(
      label: '${weekdayLabel(weekday)}: $count '
          '${count == 1 ? 'visit' : 'visits'}'
          '${isPeak ? ', the busiest day' : ''}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The count sits above its own bar rather than in a legend, so the
          // chart needs no axis to be readable. FittedBox because a four-digit
          // count at 2.0x is wider than a seventh of a 320pt screen.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$count',
              style: AppText.body(
                size: 11,
                weight: FontWeight.w600,
                color: isPeak ? AppColors.primary : AppColors.muted2,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          SizedBox(
            height: track,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fraction.clamp(0.04, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: Radii.smAll,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              weekdayLabel(weekday),
              style: AppText.body(
                size: 11,
                weight: isPeak ? FontWeight.w600 : FontWeight.w400,
                color: isPeak ? AppColors.ink : AppColors.muted2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
