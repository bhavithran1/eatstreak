/// The reward presets an owner picks from when registering a shop. Ported from
/// the Expo app's src/constants/plans.ts — the thresholds and projected stats
/// are identical, so a shop set up in either app behaves the same.
library;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/models/enums.dart';
import '../data/models/reward_tier.dart';

/// One rung of a preset, before it's attached to a real shop.
class PlanTier {
  const PlanTier({
    required this.type,
    required this.threshold,
    required this.discountPercent,
    required this.label,
    required this.description,
    required this.emoji,
  });

  final RewardType type;
  final int threshold;
  final int discountPercent;
  final String label;
  final String description;
  final String emoji;

  /// Bind this rung to a shop. The id encodes the axis and threshold so it
  /// stays stable if the ladder is re-saved — vouchers key off tier ids.
  RewardTier toRewardTier(String shopId) => RewardTier(
        id: '${shopId}_${type == RewardType.visitCount ? 'v' : 's'}$threshold',
        shopId: shopId,
        type: type,
        threshold: threshold,
        discountPercent: discountPercent,
        label: label,
        description: description,
        emoji: emoji,
      );
}

/// Modelled outcomes shown on the plan picker. Estimates, labelled as such.
class PlanStats {
  const PlanStats({
    required this.projectedRepeatRate,
    required this.avgDiscountGiven,
    required this.customerRetention30d,
    required this.revenueImpact,
  });

  final int projectedRepeatRate;
  final int avgDiscountGiven;
  final int customerRetention30d;
  final String revenueImpact;
}

class DiscountPlan {
  const DiscountPlan({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.color,
    required this.description,
    required this.visitTiers,
    required this.streakTiers,
    required this.streakWindowDays,
    required this.stats,
  });

  final String id;
  final String name;
  final String tagline;
  final String emoji;
  final Color color;
  final String description;
  final List<PlanTier> visitTiers;
  final List<PlanTier> streakTiers;

  /// How many days may pass between visits before a streak dies.
  final int streakWindowDays;
  final PlanStats stats;

  /// The full reward ladder for a shop adopting this plan.
  List<RewardTier> rewardTiersFor(String shopId) => [
        for (final t in visitTiers) t.toRewardTier(shopId),
        for (final t in streakTiers) t.toRewardTier(shopId),
      ];
}

DiscountPlan? planById(String? id) {
  if (id == null) return null;
  for (final p in discountPlans) {
    if (p.id == id) return p;
  }
  return null;
}

const discountPlans = <DiscountPlan>[
  DiscountPlan(
    id: 'aggressive_growth',
    name: 'Fast Growth',
    tagline: 'Lower thresholds, faster rewards',
    emoji: '🎯',
    color: AppColors.ember3,
    description:
        'Lower thresholds and more generous discounts for new shops focused on '
        'building repeat visits quickly.',
    visitTiers: [
      PlanTier(type: RewardType.visitCount, threshold: 3, discountPercent: 10, label: 'Newcomer', description: '10% off your meal', emoji: '🌑'),
      PlanTier(type: RewardType.visitCount, threshold: 7, discountPercent: 20, label: 'Regular', description: '20% off your meal', emoji: '🌗'),
      PlanTier(type: RewardType.visitCount, threshold: 15, discountPercent: 35, label: 'Superfan', description: '35% off your meal', emoji: '🌕'),
      PlanTier(type: RewardType.visitCount, threshold: 30, discountPercent: 50, label: 'Legend', description: '50% off your meal', emoji: '☀️'),
    ],
    streakTiers: [
      PlanTier(type: RewardType.streakDays, threshold: 2, discountPercent: 5, label: '2-Day Streak', description: '5% off next visit', emoji: '🌱'),
      PlanTier(type: RewardType.streakDays, threshold: 5, discountPercent: 15, label: '5-Day Streak', description: '15% off next visit', emoji: '🌿'),
      PlanTier(type: RewardType.streakDays, threshold: 10, discountPercent: 30, label: '10-Day Streak', description: '30% off next visit', emoji: '🌲'),
      PlanTier(type: RewardType.streakDays, threshold: 21, discountPercent: 45, label: '21-Day Streak', description: '45% off — unstoppable!', emoji: '🏔️'),
    ],
    streakWindowDays: 3,
    stats: PlanStats(
      projectedRepeatRate: 68,
      avgDiscountGiven: 14,
      customerRetention30d: 52,
      revenueImpact: '+42%',
    ),
  ),
  DiscountPlan(
    id: 'steady_loyalty',
    name: 'Balanced Loyalty',
    tagline: 'Balanced rewards, sustainable growth',
    emoji: '🧭',
    color: AppColors.ember2,
    description:
        'Moderate thresholds with meaningful rewards. A practical balance '
        'between customer value and operating margin.',
    visitTiers: [
      PlanTier(type: RewardType.visitCount, threshold: 5, discountPercent: 10, label: 'Regular', description: '10% off your meal', emoji: '🌑'),
      PlanTier(type: RewardType.visitCount, threshold: 10, discountPercent: 20, label: 'Loyal Fan', description: '20% off your meal', emoji: '🌗'),
      PlanTier(type: RewardType.visitCount, threshold: 20, discountPercent: 30, label: 'VIP', description: '30% off your meal', emoji: '🌕'),
      PlanTier(type: RewardType.visitCount, threshold: 50, discountPercent: 50, label: 'Legend', description: '50% off your meal', emoji: '☀️'),
    ],
    streakTiers: [
      PlanTier(type: RewardType.streakDays, threshold: 3, discountPercent: 5, label: '3-Day Streak', description: '5% off next visit', emoji: '🌱'),
      PlanTier(type: RewardType.streakDays, threshold: 7, discountPercent: 15, label: '7-Day Streak', description: '15% off next visit', emoji: '🌿'),
      PlanTier(type: RewardType.streakDays, threshold: 14, discountPercent: 25, label: '14-Day Streak', description: '25% off next visit', emoji: '🌲'),
      PlanTier(type: RewardType.streakDays, threshold: 30, discountPercent: 40, label: '30-Day Streak', description: '40% off — legendary!', emoji: '🏔️'),
    ],
    streakWindowDays: 3,
    stats: PlanStats(
      projectedRepeatRate: 54,
      avgDiscountGiven: 9,
      customerRetention30d: 41,
      revenueImpact: '+28%',
    ),
  ),
  DiscountPlan(
    id: 'premium_vip',
    name: 'Premium',
    tagline: 'Higher thresholds, premium rewards',
    emoji: '🪩',
    color: Color(0xFFA78BFA),
    description:
        'Higher thresholds with larger rewards for businesses that want a more '
        'selective loyalty program.',
    visitTiers: [
      PlanTier(type: RewardType.visitCount, threshold: 10, discountPercent: 10, label: 'Member', description: '10% off your meal', emoji: '🌑'),
      PlanTier(type: RewardType.visitCount, threshold: 25, discountPercent: 20, label: 'Silver', description: '20% off your meal', emoji: '🌗'),
      PlanTier(type: RewardType.visitCount, threshold: 50, discountPercent: 35, label: 'Gold', description: '35% off your meal', emoji: '🌕'),
      PlanTier(type: RewardType.visitCount, threshold: 100, discountPercent: 50, label: 'Platinum', description: '50% off — hall of fame!', emoji: '☀️'),
    ],
    streakTiers: [
      PlanTier(type: RewardType.streakDays, threshold: 5, discountPercent: 5, label: '5-Day Streak', description: '5% off next visit', emoji: '🌱'),
      PlanTier(type: RewardType.streakDays, threshold: 14, discountPercent: 15, label: '14-Day Streak', description: '15% off next visit', emoji: '🌿'),
      PlanTier(type: RewardType.streakDays, threshold: 30, discountPercent: 30, label: '30-Day Streak', description: '30% off next visit', emoji: '🌲'),
      PlanTier(type: RewardType.streakDays, threshold: 60, discountPercent: 50, label: '60-Day Streak', description: '50% off — truly elite!', emoji: '🏔️'),
    ],
    streakWindowDays: 2,
    stats: PlanStats(
      projectedRepeatRate: 38,
      avgDiscountGiven: 6,
      customerRetention30d: 33,
      revenueImpact: '+19%',
    ),
  ),
  DiscountPlan(
    id: 'coffee_shop',
    name: 'Daily Visit',
    tagline: 'For cafés and frequent-visit shops',
    emoji: '⏳',
    color: AppColors.ember1,
    description:
        'Designed for coffee shops, juice bars, and bakeries with frequent '
        'visits and shorter return windows.',
    visitTiers: [
      PlanTier(type: RewardType.visitCount, threshold: 5, discountPercent: 10, label: '5th Cup Free', description: '10% off your order', emoji: '🌑'),
      PlanTier(type: RewardType.visitCount, threshold: 15, discountPercent: 15, label: 'Caffeine Crew', description: '15% off your order', emoji: '🌗'),
      PlanTier(type: RewardType.visitCount, threshold: 30, discountPercent: 25, label: 'Bean Boss', description: '25% off your order', emoji: '🌕'),
      PlanTier(type: RewardType.visitCount, threshold: 60, discountPercent: 40, label: 'Espresso Elite', description: '40% off — you live here!', emoji: '☀️'),
    ],
    streakTiers: [
      PlanTier(type: RewardType.streakDays, threshold: 3, discountPercent: 5, label: '3-Day Streak', description: 'Free size upgrade', emoji: '🌱'),
      PlanTier(type: RewardType.streakDays, threshold: 7, discountPercent: 10, label: 'Week Warrior', description: '10% off next order', emoji: '🌿'),
      PlanTier(type: RewardType.streakDays, threshold: 14, discountPercent: 20, label: '2-Week Ritual', description: '20% off next order', emoji: '🌲'),
      PlanTier(type: RewardType.streakDays, threshold: 30, discountPercent: 35, label: 'Monthly Regular', description: '35% off — your table is reserved!', emoji: '🏔️'),
    ],
    streakWindowDays: 2,
    stats: PlanStats(
      projectedRepeatRate: 72,
      avgDiscountGiven: 11,
      customerRetention30d: 58,
      revenueImpact: '+35%',
    ),
  ),
  DiscountPlan(
    id: 'weekend_special',
    name: 'Weekly Visit',
    tagline: 'More time for weekly customers',
    emoji: '🎪',
    color: AppColors.success,
    description:
        'A seven-day return window for restaurants where repeat customers are '
        'more likely to visit weekly.',
    visitTiers: [
      PlanTier(type: RewardType.visitCount, threshold: 4, discountPercent: 10, label: 'Starter', description: '10% off your meal', emoji: '🌑'),
      PlanTier(type: RewardType.visitCount, threshold: 8, discountPercent: 15, label: 'Regular', description: '15% off your meal', emoji: '🌗'),
      PlanTier(type: RewardType.visitCount, threshold: 16, discountPercent: 25, label: 'Devoted', description: '25% off your meal', emoji: '🌕'),
      PlanTier(type: RewardType.visitCount, threshold: 40, discountPercent: 40, label: 'Legend', description: '40% off your meal', emoji: '☀️'),
    ],
    streakTiers: [
      PlanTier(type: RewardType.streakDays, threshold: 2, discountPercent: 5, label: '2-Week Streak', description: '5% off next visit', emoji: '🌱'),
      PlanTier(type: RewardType.streakDays, threshold: 4, discountPercent: 10, label: 'Monthly Streak', description: '10% off next visit', emoji: '🌿'),
      PlanTier(type: RewardType.streakDays, threshold: 8, discountPercent: 20, label: '2-Month Streak', description: '20% off next visit', emoji: '🌲'),
      PlanTier(type: RewardType.streakDays, threshold: 12, discountPercent: 30, label: '3-Month Streak', description: "30% off — you're family!", emoji: '🏔️'),
    ],
    streakWindowDays: 7,
    stats: PlanStats(
      projectedRepeatRate: 46,
      avgDiscountGiven: 8,
      customerRetention30d: 37,
      revenueImpact: '+22%',
    ),
  ),
];
