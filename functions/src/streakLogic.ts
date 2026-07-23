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
  // What the last break cost, recorded when the streak resets. Without this a
  // customer who breaks a streak and then simply visits again has overwritten
  // the only evidence of what they lost — so turning up at the shop would
  // destroy their chance to repair, which is exactly backwards.
  brokenStreakDays?: number;
  brokenOn?: string;
  brokenStartDate?: string;
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
  // Carried forward untouched unless this check-in is the one that breaks it.
  let broken = {
    brokenStreakDays: existing.brokenStreakDays ?? 0,
    brokenOn: existing.brokenOn ?? '',
    brokenStartDate: existing.brokenStartDate ?? '',
  };

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
      broken = {
        brokenStreakDays: existing.currentStreakDays,
        brokenOn: existing.lastVisitDate,
        brokenStartDate: existing.streakStartDate,
      };
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
      ...broken,
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

/**
 * Number of random characters after the prefix. Must match
 * `voucherCodeLength` in mobile/lib/core/utils/formatters.dart, which generates
 * the demo-mode equivalent.
 */
export const VOUCHER_CODE_LENGTH = 6;

export const VOUCHER_CODE_PREFIX = 'EAT-';

/**
 * EAT-XXXXXX code. The alphabet drops I, O, 0 and 1 — the pairs staff actually
 * confuse when reading a code off a stranger's phone. L stays: it is only
 * mistakable for 1, and 1 is already gone.
 */
export function generateVoucherCode(rand: () => number = Math.random): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < VOUCHER_CODE_LENGTH; i++) {
    code += chars[Math.floor(rand() * chars.length)];
  }
  return `${VOUCHER_CODE_PREFIX}${code}`;
}

/**
 * Tidy up a hand-typed voucher code before looking it up.
 *
 * Staff read the code off the customer's phone, so it arrives lowercase, with
 * spaces, with an extra hyphen, or with the `EAT-` prefix left off. Comparing
 * those to the stored code verbatim answers "no voucher with that code", which
 * accuses the customer of something that is really a typo. Normalising both
 * sides makes the lookup forgiving without widening what actually matches: the
 * random body still has to be exactly right.
 */
export function normalizeVoucherCode(raw: string): string {
  // Strip separators first, so leading whitespace can't hide the prefix and
  // leave it to be treated as part of the code.
  const compact = raw.toUpperCase().replace(/[^A-Z0-9]/g, '');

  // Drop the prefix only when what's left is exactly a code body. A body may
  // itself begin with E-A-T, so removing a leading "EAT" unconditionally would
  // eat three real characters from someone who typed the body alone.
  const stripped = 'EAT';
  if (compact === stripped) return ''; // the prefix and nothing else

  const body =
    compact.startsWith(stripped) && compact.length === stripped.length + VOUCHER_CODE_LENGTH
      ? compact.slice(stripped.length)
      : compact;

  return body.length === 0 ? '' : `${VOUCHER_CODE_PREFIX}${body}`;
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

export interface RepairInfo {
  eligibility: RepairEligibility;
  /** The streak length that broke, and that a repair would restore. */
  lostStreakDays: number;
  /** Embers required. 0 when not repairable. */
  cost: number;
}

/**
 * Whether a streak may be repaired today, what was lost, and what it costs.
 *
 * There are two ways to arrive here. Either the customer has not been back
 * since the break, so the old length is still sitting on the streak, or they
 * have already checked in again — which resets the streak but records what it
 * cost. Both must be repairable, or visiting the shop would be what destroys
 * the customer's chance to save their streak.
 */
export function repairInfo(
  streak: Pick<
    StreakCore,
    'currentStreakDays' | 'lastVisitDate' | 'brokenStreakDays' | 'brokenOn'
  >,
  todayStr: string,
  streakWindowDays: number,
): RepairInfo {
  const none = (eligibility: RepairEligibility): RepairInfo => ({
    eligibility,
    lostStreakDays: 0,
    cost: 0,
  });

  const brokenDays = streak.brokenStreakDays ?? 0;
  const brokenOn = streak.brokenOn ?? '';

  // Already checked in since the break: the loss is on record.
  if (brokenDays > 0 && brokenOn) {
    if (brokenDays < MIN_REPAIRABLE_STREAK) return none('too_short');
    if (daysBetween(brokenOn, todayStr) > streakWindowDays + REPAIR_GRACE_DAYS) {
      return none('too_late');
    }
    return { eligibility: 'repairable', lostStreakDays: brokenDays, cost: repairCost(brokenDays) };
  }

  // Not back yet: the streak still carries its pre-break length.
  if (!streak.lastVisitDate) return none('not_broken');
  const daysSince = daysBetween(streak.lastVisitDate, todayStr);
  if (daysSince <= streakWindowDays) return none('not_broken');
  if (streak.currentStreakDays < MIN_REPAIRABLE_STREAK) return none('too_short');
  if (daysSince > streakWindowDays + REPAIR_GRACE_DAYS) return none('too_late');

  return {
    eligibility: 'repairable',
    lostStreakDays: streak.currentStreakDays,
    cost: repairCost(streak.currentStreakDays),
  };
}

export function applyRepair(streak: StreakCore, todayStr: string): StreakCore {
  const brokenDays = streak.brokenStreakDays ?? 0;
  const cleared = { brokenStreakDays: 0, brokenOn: '', brokenStartDate: '' };

  // Already checked in since the break: fold the lost run back onto the days
  // rebuilt since, and keep the real last-visit date.
  if (brokenDays > 0 && streak.brokenOn) {
    const restored = brokenDays + streak.currentStreakDays;
    return {
      ...streak,
      ...cleared,
      currentStreakDays: restored,
      longestStreakDays: Math.max(streak.longestStreakDays, restored),
      streakStartDate: streak.brokenStartDate || streak.streakStartDate,
      isStreakAlive: true,
    };
  }

  // Not back yet: keep the length and read as though yesterday's visit
  // happened, so the streak is alive and today's check-in still counts.
  return {
    ...streak,
    ...cleared,
    lastVisitDate: addDays(todayStr, -1),
    isStreakAlive: true,
  };
}
