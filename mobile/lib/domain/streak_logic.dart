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
    this.brokenStreakDays = 0,
    this.brokenOn = '',
    this.brokenStartDate = '',
  });

  final int currentStreakDays;
  final int longestStreakDays;
  final int totalVisits;
  final String lastVisitDate;
  final String streakStartDate;
  final bool isStreakAlive;

  /// What the last break cost, recorded when the streak resets — so visiting
  /// again doesn't destroy the customer's chance to repair.
  final int brokenStreakDays;
  final String brokenOn;
  final String brokenStartDate;
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
  // Carried forward untouched unless this check-in is the one that breaks it.
  var brokenStreakDays = existing.brokenStreakDays;
  var brokenOn = existing.brokenOn;
  var brokenStartDate = existing.brokenStartDate;

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
      brokenStreakDays = existing.currentStreakDays;
      brokenOn = existing.lastVisitDate;
      brokenStartDate = existing.streakStartDate;
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
      brokenStreakDays: brokenStreakDays,
      brokenOn: brokenOn,
      brokenStartDate: brokenStartDate,
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

// ---- embers & streak repair ------------------------------------------------
//
// Port of the same section in functions/src/streakLogic.ts — keep in agreement.
//
// Breaking a long streak should cost something; that loss is what makes a
// streak worth keeping. It is paid in embers, earned by visiting, rather than
// in money: charging a customer for *not* visiting reads as a fine and is the
// fastest way to make them uninstall. The price rises with the streak, so the
// customer with the most to lose pays the most to save it, and can afford to
// because embers come from the visits that built the streak.

const embersPerCheckIn = 1;

/// Once the window lapses, a break stays repairable for this many extra days.
const repairGraceDays = 2;

/// Below this, a streak is cheaper to rebuild than to repair.
const minRepairableStreak = 3;

/// What it costs to repair a streak of [streakDays].
int repairCost(int streakDays) {
  if (streakDays < minRepairableStreak) return 0;
  if (streakDays < 7) return 2;
  if (streakDays < 30) return 5;
  return 15;
}

enum RepairEligibility { repairable, notBroken, tooShort, tooLate }

class RepairInfo {
  const RepairInfo({
    required this.eligibility,
    required this.lostStreakDays,
    required this.cost,
  });

  final RepairEligibility eligibility;

  /// The streak length that broke, and that a repair would restore.
  final int lostStreakDays;

  /// Embers required. 0 when not repairable.
  final int cost;

  bool get isRepairable => eligibility == RepairEligibility.repairable;
}

/// Whether a streak may be repaired today, what was lost, and what it costs.
///
/// Two ways to arrive here: the customer has not been back since the break, so
/// the old length is still on the streak; or they have already checked in
/// again, which resets it but records the loss. Both must be repairable, or
/// visiting the shop would be what destroys the chance to save the streak.
RepairInfo repairInfo(
  int currentStreakDays,
  String lastVisitDate,
  int brokenStreakDays,
  String brokenOn,
  String todayStr,
  int streakWindowDays,
) {
  RepairInfo none(RepairEligibility e) =>
      RepairInfo(eligibility: e, lostStreakDays: 0, cost: 0);

  // Already checked in since the break: the loss is on record.
  if (brokenStreakDays > 0 && brokenOn.isNotEmpty) {
    if (brokenStreakDays < minRepairableStreak) {
      return none(RepairEligibility.tooShort);
    }
    if (daysBetween(brokenOn, todayStr) > streakWindowDays + repairGraceDays) {
      return none(RepairEligibility.tooLate);
    }
    return RepairInfo(
      eligibility: RepairEligibility.repairable,
      lostStreakDays: brokenStreakDays,
      cost: repairCost(brokenStreakDays),
    );
  }

  // Not back yet: the streak still carries its pre-break length.
  if (lastVisitDate.isEmpty) return none(RepairEligibility.notBroken);
  final daysSince = daysBetween(lastVisitDate, todayStr);
  if (daysSince <= streakWindowDays) return none(RepairEligibility.notBroken);
  if (currentStreakDays < minRepairableStreak) {
    return none(RepairEligibility.tooShort);
  }
  if (daysSince > streakWindowDays + repairGraceDays) {
    return none(RepairEligibility.tooLate);
  }

  return RepairInfo(
    eligibility: RepairEligibility.repairable,
    lostStreakDays: currentStreakDays,
    cost: repairCost(currentStreakDays),
  );
}

