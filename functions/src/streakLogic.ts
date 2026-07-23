// Pure, I/O-free streak + voucher logic. Ported verbatim from the rules in
// app/src/services/streakService.ts (registerVisit + checkAndAwardVouchers) so
// behaviour is identical to the old on-device version — but with no Firestore,
// no Date.now(), no randomness. Everything time-dependent is passed in.
//
// Both the Cloud Function (index.ts, inside a transaction) and the Node unit
// test import these functions. That's what lets us verify the highest-risk math
// without needing the Java-based emulator.

import { daysBetween, addDays } from './dates';
import { RewardTier } from './types';

export interface StreakCore {
  currentStreakDays: number;
  longestStreakDays: number;
  totalVisits: number;
  lastVisitDate: string;
  streakStartDate: string;
  isStreakAlive: boolean;
}

export type CheckInStatus = 'success' | 'already_visited_today';

export interface ComputeCheckInResult {
  status: CheckInStatus;
  /** The streak after this check-in. Unchanged when already_visited_today. */
  streak: StreakCore;
}

/**
 * Apply one check-in to a streak. Mirrors registerVisit():
 *  - same calendar day (in shop tz) => no mutation, already_visited_today
 *  - first ever visit => streak of 1
 *  - within streakWindowDays of last visit => increment
 *  - beyond the window => reset to 1
 */
export function computeCheckIn(
  existing: StreakCore | null,
  todayStr: string,
  streakWindowDays: number
): ComputeCheckInResult {
  if (existing && existing.lastVisitDate === todayStr) {
    return { status: 'already_visited_today', streak: existing };
  }

  if (!existing) {
    return {
      status: 'success',
      streak: {
        currentStreakDays: 1,
        longestStreakDays: 1,
        totalVisits: 1,
        lastVisitDate: todayStr,
        streakStartDate: todayStr,
        isStreakAlive: true,
      },
    };
  }

  const totalVisits = existing.totalVisits + 1;
  let currentStreakDays: number;
  let streakStartDate: string;

  if (!existing.lastVisitDate) {
    currentStreakDays = 1;
    streakStartDate = todayStr;
  } else {
    const daysSince = daysBetween(existing.lastVisitDate, todayStr);
    if (daysSince <= streakWindowDays) {
      currentStreakDays = existing.currentStreakDays + 1;
      streakStartDate = existing.streakStartDate;
    } else {
      currentStreakDays = 1;
      streakStartDate = todayStr;
    }
  }

  return {
    status: 'success',
    streak: {
      totalVisits,
      currentStreakDays,
      streakStartDate,
      lastVisitDate: todayStr,
      longestStreakDays: Math.max(existing.longestStreakDays, currentStreakDays),
      isStreakAlive: true,
    },
  };
}

/**
 * Which reward tiers should mint a voucher for this streak, given the tiers the
 * user has already earned. Mirrors checkAndAwardVouchers()'s qualification +
 * idempotency (one voucher per tier ever).
 */
export function qualifyingTiers(
  streak: StreakCore,
  tiers: RewardTier[],
  alreadyAwardedTierIds: Set<string>
): RewardTier[] {
  const result: RewardTier[] = [];
  for (const tier of tiers) {
    const value = tier.type === 'visit_count' ? streak.totalVisits : streak.currentStreakDays;
    if (value < tier.threshold) continue;
    if (alreadyAwardedTierIds.has(tier.id)) continue;
    result.push(tier);
  }
  return result;
}

/** EAT-XXXX code, ambiguity-free alphabet. Ported from formatters.ts. */
export function generateVoucherCode(rand: () => number = Math.random): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(rand() * chars.length)];
  }
  return `EAT-${code}`;
}

// ---- embers & streak repair ------------------------------------------------
//
// Breaking a long streak should cost something — that loss is what makes a
// streak worth keeping. It is paid in embers, earned by visiting, rather than
// in money: charging a customer for *not* visiting reads as a fine and is the
// fastest way to make them uninstall. The price rises with the streak, so the
// customer with the most to lose pays the most to save it, and can afford to
// because embers come from the visits that built the streak.

export const EMBERS_PER_CHECK_IN = 1;

/// Once the window lapses, a break stays repairable for this many extra days.
export const REPAIR_GRACE_DAYS = 2;

/// Below this, a streak is cheaper to rebuild than to repair.
export const MIN_REPAIRABLE_STREAK = 3;

/** What it costs to repair a streak of [streakDays]. */
export function repairCost(streakDays: number): number {
  if (streakDays < MIN_REPAIRABLE_STREAK) return 0;
  if (streakDays < 7) return 2;
  if (streakDays < 30) return 5;
  return 15;
}

export type RepairEligibility = 'repairable' | 'not_broken' | 'too_short' | 'too_late';

/**
 * Whether a streak may be repaired today. A streak is only "broken" relative to
 * the shop's window, and the offer expires so a repair can't resurrect a streak
 * abandoned weeks ago.
 */
export function repairEligibility(
  streak: Pick<StreakCore, 'currentStreakDays' | 'lastVisitDate'>,
  todayStr: string,
  streakWindowDays: number,
): RepairEligibility {
  if (!streak.lastVisitDate) return 'not_broken';

  const daysSince = daysBetween(streak.lastVisitDate, todayStr);
  if (daysSince <= streakWindowDays) return 'not_broken';
  if (streak.currentStreakDays < MIN_REPAIRABLE_STREAK) return 'too_short';
  if (daysSince > streakWindowDays + REPAIR_GRACE_DAYS) return 'too_late';
  return 'repairable';
}

/**
 * The streak after a repair: alive again, as though the last visit had been
 * yesterday. The length is preserved but never incremented — a repair is not a
 * visit, and it must still leave room to check in today.
 */
export function applyRepair(streak: StreakCore, todayStr: string): StreakCore {
  return {
    ...streak,
    lastVisitDate: addDays(todayStr, -1),
    isStreakAlive: true,
  };
}
