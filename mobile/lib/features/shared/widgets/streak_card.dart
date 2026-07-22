import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/shop.dart';
import '../../../data/models/streak.dart';
import '../../../domain/streak_service.dart';
import 'gradient_progress_bar.dart';
import 'pressable_scale.dart';
import 'shop_icon.dart';
import 'urgency_style.dart';

enum StreakCardSize { small, large }

/// A running streak at one shop. The large variant headlines the home screen
/// and shop detail; the small one lists the rest.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streak,
    required this.shop,
    this.size = StreakCardSize.small,
    this.onTap,
  });

  final Streak streak;
  final Shop shop;
  final StreakCardSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final urgency = streakUrgency(streak, shop);
    final next = nextMilestone(streak, shop, RewardType.streakDays);
    final progress =
        next == null ? 1.0 : streak.currentStreakDays / next.threshold;

    return PressableScale(
      onTap: onTap,
      child: size == StreakCardSize.large
          ? _large(urgency, next?.threshold, next?.discountPercent, progress)
          : _small(urgency, progress),
    );
  }

  Widget _large(
    StreakUrgency urgency,
    int? nextThreshold,
    int? nextDiscount,
    double progress,
  ) {
    final remaining =
        nextThreshold == null ? 0 : nextThreshold - streak.currentStreakDays;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: Radii.xlAll,
        boxShadow: Shadows.floating,
      ),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          borderRadius: Radii.xlAll,
          border: Border.all(color: urgency.color.withValues(alpha: 0.25)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.primary.withValues(alpha: 0.04),
              AppColors.card,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShopIcon(
                  category: shop.category,
                  size: 48,
                  variant: ShopIconVariant.accent,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shop.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.heading(size: 18),
                            ),
                          ),
                          if (onTap != null)
                            const Icon(Icons.chevron_right,
                                size: 20, color: AppColors.muted2),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: UrgencyBadge(urgency: urgency),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${streak.currentStreakDays}',
                  style: AppText.heading(
                    size: 48,
                    weight: FontWeight.w700,
                    color: AppColors.ember2,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  urgency == StreakUrgency.dead ? 'day best' : 'days active',
                  style: AppText.body(size: 16),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            GradientProgressBar(value: progress),
            if (nextThreshold != null) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                '$remaining more ${remaining == 1 ? 'day' : 'days'} '
                'for $nextDiscount% off',
                style: AppText.body(size: 13, weight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stat('${streak.totalVisits}', 'total visits'),
                _stat('${streak.longestStreakDays}', 'best streak'),
                _stat(
                  nextDiscount == null ? 'Max' : '$nextDiscount%',
                  'next reward',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: AppText.heading(size: 20)),
          const SizedBox(height: Spacing.xs),
          Text(label, style: AppText.body(size: 12)),
        ],
      );

  Widget _small(StreakUrgency urgency, double progress) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: Radii.lgAll,
        border: Border.all(color: urgency.color.withValues(alpha: 0.19)),
        boxShadow: Shadows.card,
      ),
      child: Row(
        children: [
          ShopIcon(
            category: shop.category,
            size: 42,
            variant: ShopIconVariant.subtle,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.heading(size: 15, weight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    UrgencyBadge(urgency: urgency),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${streak.currentStreakDays} day streak',
                      style: AppText.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.ember2,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Text(
                      '${streak.totalVisits} visits',
                      style: AppText.body(size: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GradientProgressBar(
                  value: progress,
                  height: 3,
                  colors: const [AppColors.ember1, AppColors.ember2],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
