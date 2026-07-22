// Pure, I/O-free streak + voucher logic. Ported verbatim from the rules in
// app/src/services/streakService.ts (registerVisit + checkAndAwardVouchers) so
// behaviour is identical to the old on-device version — but with no Firestore,
// no Date.now(), no randomness. Everything time-dependent is passed in.
//
// Both the Cloud Function (index.ts, inside a transaction) and the Node unit
// test import these functions. That's what lets us verify the highest-risk math
// without needing the Java-based emulator.

import { daysBetween } from './dates';
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
  for (let i = 0; i < 4; i++) {
    code += chars[Math.floor(rand() * chars.length)];
  }
  return `EAT-${code}`;
}
