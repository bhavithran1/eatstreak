/// Pure, I/O-free streak + voucher math. Ported from
/// functions/src/streakLogic.ts, which is the authority — the Cloud Function
/// runs that copy for real check-ins, and this one backs demo mode. Everything
/// time-dependent is passed in so both are unit-testable.
library;

import '../core/utils/dates.dart';
import '../data/models/enums.dart';
import '../data/models/reward_tier.dart';

/// The mutable core of a streak, without identity/denormalized fields.
class StreakCore {
  const StreakCore({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.totalVisits,
    required this.lastVisitDate,
    required this.streakStartDate,
    required this.isStreakAlive,
  });

  final int currentStreakDays;
  final int longestStreakDays;
  final int totalVisits;
  final String lastVisitDate;
  final String streakStartDate;
  final bool isStreakAlive;
}

class ComputeCheckInResult {
  const ComputeCheckInResult({required this.status, required this.streak});

  final CheckInStatus status;

  /// The streak after this check-in; unchanged when already visited today.
  final StreakCore streak;
}

/// Apply one check-in to a streak:
///  - same calendar day (in the shop's tz) → no mutation
///  - first ever visit → streak of 1
///  - within [streakWindowDays] of the last visit → increment
///  - beyond the window → reset to 1
ComputeCheckInResult computeCheckIn(
  StreakCore? existing,
  String todayStr,
  int streakWindowDays,
) {
  if (existing != null && existing.lastVisitDate == todayStr) {
    return ComputeCheckInResult(
      status: CheckInStatus.alreadyVisitedToday,
      streak: existing,
    );
  }

  if (existing == null) {
    return ComputeCheckInResult(
      status: CheckInStatus.success,
      streak: StreakCore(
        currentStreakDays: 1,
        longestStreakDays: 1,
        totalVisits: 1,
        lastVisitDate: todayStr,
        streakStartDate: todayStr,
        isStreakAlive: true,
      ),
    );
  }

  final int currentStreakDays;
  final String streakStartDate;

  if (existing.lastVisitDate.isEmpty) {
    currentStreakDays = 1;
    streakStartDate = todayStr;
  } else {
    final daysSince = daysBetween(existing.lastVisitDate, todayStr);
    if (daysSince <= streakWindowDays) {
      currentStreakDays = existing.currentStreakDays + 1;
      streakStartDate = existing.streakStartDate;
    } else {
      currentStreakDays = 1;
      streakStartDate = todayStr;
    }
  }

  return ComputeCheckInResult(
    status: CheckInStatus.success,
    streak: StreakCore(
      currentStreakDays: currentStreakDays,
      longestStreakDays:
          existing.longestStreakDays > currentStreakDays ? existing.longestStreakDays : currentStreakDays,
      totalVisits: existing.totalVisits + 1,
      lastVisitDate: todayStr,
      streakStartDate: streakStartDate,
      isStreakAlive: true,
    ),
  );
}

/// Which tiers should mint a voucher at this streak, excluding ones already
/// earned. One voucher per tier, ever.
List<RewardTier> qualifyingTiers(
  StreakCore streak,
  List<RewardTier> tiers,
  Set<String> alreadyAwardedTierIds,
) {
  return tiers.where((tier) {
    final value = tier.type == RewardType.visitCount
        ? streak.totalVisits
        : streak.currentStreakDays;
    return value >= tier.threshold && !alreadyAwardedTierIds.contains(tier.id);
  }).toList();
}
