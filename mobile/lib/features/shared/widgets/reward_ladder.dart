import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/reward_tier.dart';
import 'gradient_progress_bar.dart';

/// The reward ladder for one axis (visits or streak days), showing which rungs
/// are cleared, which one is in reach, and how far off it is.
class RewardLadder extends StatelessWidget {
  const RewardLadder({
    super.key,
    required this.tiers,
    required this.currentValue,
    required this.type,
    required this.title,
  });

  final List<RewardTier> tiers;
  final int currentValue;
  final RewardType type;
  final String title;

  @override
  Widget build(BuildContext context) {
    final sorted = tiers.where((t) => t.type == type).toList()
      ..sort((a, b) => a.threshold.compareTo(b.threshold));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.heading(size: 16)),
        const SizedBox(height: Spacing.md),
        for (var i = 0; i < sorted.length; i++)
          _TierRow(
            tier: sorted[i],
            currentValue: currentValue,
            isLast: i == sorted.length - 1,
            // The first unmet rung is the one to aim at; everything past it is
            // still theoretical.
            isCurrent: currentValue < sorted[i].threshold &&
                (i == 0 || currentValue >= sorted[i - 1].threshold),
          ),
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.currentValue,
    required this.isLast,
    required this.isCurrent,
  });

  final RewardTier tier;
  final int currentValue;
  final bool isLast;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final achieved = currentValue >= tier.threshold;
    final progress = achieved ? 1.0 : currentValue / tier.threshold;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.sm,
      ),
      decoration: isCurrent
          ? BoxDecoration(
              color: AppColors.ember2.withValues(alpha: 0.04),
              borderRadius: Radii.mdAll,
            )
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  _marker(achieved),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
                        color: achieved
                            ? AppColors.success.withValues(alpha: 0.38)
                            : AppColors.line2,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tier.label,
                            style: AppText.heading(
                              size: 14,
                              weight: FontWeight.w500,
                              color:
                                  achieved ? AppColors.success : AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${tier.discountPercent}% off',
                          style: AppText.heading(
                            size: 14,
                            color: achieved
                                ? AppColors.success
                                : AppColors.ember2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(tier.description, style: AppText.body(size: 12)),
                    if (!achieved) ...[
                      const SizedBox(height: Spacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: GradientProgressBar(
                              value: progress,
                              height: 4,
                              colors: isCurrent
                                  ? const [AppColors.ember1, AppColors.ember2]
                                  : const [AppColors.muted2, AppColors.muted2],
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '$currentValue/${tier.threshold}',
                              textAlign: TextAlign.right,
                              style: AppText.body(
                                size: 11,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marker(bool achieved) {
    if (achieved) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 15, color: AppColors.primaryInk),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrent ? AppColors.ember2 : AppColors.line2,
          width: 2,
        ),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.primary : AppColors.muted2,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
