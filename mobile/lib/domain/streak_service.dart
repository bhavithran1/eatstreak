/// Read-only helpers screens use to render streak state. Check-in writes are
/// server-authoritative (see streak_logic.dart); nothing here mutates anything.
library;

import '../core/utils/dates.dart';
import '../data/models/enums.dart';
import '../data/models/reward_tier.dart';
import '../data/models/shop.dart';
import '../data/models/streak.dart';

/// How close this streak is to dying, given the shop's return window.
StreakUrgency streakUrgency(Streak streak, Shop shop) {
  if (!streak.isStreakAlive) return StreakUrgency.dead;

  final daysSince = daysBetween(streak.lastVisitDate, todayString());
  if (daysSince == 0) return StreakUrgency.safe;
  if (daysSince < shop.streakWindowDays) return StreakUrgency.warning;
  if (daysSince == shop.streakWindowDays) return StreakUrgency.critical;
  return StreakUrgency.dead;
}

/// Recompute `isStreakAlive` against today — a stored streak goes stale the
/// moment the window passes, and nothing writes to it until the next check-in.
Streak refreshStreakAlive(Streak streak, Shop shop) {
  final daysSince = daysBetween(streak.lastVisitDate, todayString());
  return streak.copyWith(isStreakAlive: daysSince <= shop.streakWindowDays);
}

/// Largest discount already unlocked for one reward axis.
int bestDiscount(Streak streak, Shop shop, RewardType type) {
  final value =
      type == RewardType.visitCount ? streak.totalVisits : streak.currentStreakDays;

  var best = 0;
  for (final tier in shop.rewardTiers) {
    if (tier.type == type && value >= tier.threshold && tier.discountPercent > best) {
      best = tier.discountPercent;
    }
  }
  return best;
}

/// The next tier the user hasn't reached yet, or null once they've maxed out.
RewardTier? nextMilestone(Streak streak, Shop shop, RewardType type) {
  final value =
      type == RewardType.visitCount ? streak.totalVisits : streak.currentStreakDays;

  final ofType = shop.rewardTiers.where((t) => t.type == type).toList()
    ..sort((a, b) => a.threshold.compareTo(b.threshold));

  for (final tier in ofType) {
    if (tier.threshold > value) return tier;
  }
  return null;
}

/// Days remaining before this streak lapses. 0 means today is the last chance.
int daysLeftToVisit(Streak streak, Shop shop) =>
    daysUntilExpiry(streak.lastVisitDate, shop.streakWindowDays);
