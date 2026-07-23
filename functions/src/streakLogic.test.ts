// Plain-Node unit tests for the pure check-in logic. No emulator / Java needed.
// Run: npm test  (compiles with tsconfig.test.json, then executes this file)
//
// Covers the exact scenarios from the plan's verification section.

import { computeCheckIn, qualifyingTiers, StreakCore, repairCost, repairEligibility, applyRepair } from './streakLogic';
import { toDateStringInTZ, addDays } from './dates';
import { RewardTier } from './types';

let passed = 0;
let failed = 0;

function assert(name: string, cond: boolean, detail?: string) {
  if (cond) {
    passed++;
    console.log(`  ok  ${name}`);
  } else {
    failed++;
    console.error(`FAIL  ${name}${detail ? ' — ' + detail : ''}`);
  }
}

function eq<T>(name: string, actual: T, expected: T) {
  assert(name, actual === expected, `got ${JSON.stringify(actual)}, want ${JSON.stringify(expected)}`);
}

const TODAY = '2026-07-16';
const YESTERDAY = addDays(TODAY, -1);
const TWO_AGO = addDays(TODAY, -2);
const FOUR_AGO = addDays(TODAY, -4);

// --- computeCheckIn ---------------------------------------------------------

// New streak = 1
{
  const r = computeCheckIn(null, TODAY, 3);
  eq('new streak: status success', r.status, 'success');
  eq('new streak: currentStreakDays', r.streak.currentStreakDays, 1);
  eq('new streak: totalVisits', r.streak.totalVisits, 1);
  eq('new streak: alive', r.streak.isStreakAlive, true);
}

// Same-day repeat => no mutation
{
  const existing: StreakCore = {
    currentStreakDays: 5, longestStreakDays: 9, totalVisits: 12,
    lastVisitDate: TODAY, streakStartDate: '2026-07-12', isStreakAlive: true,
  };
  const r = computeCheckIn(existing, TODAY, 3);
  eq('same-day: status', r.status, 'already_visited_today');
  eq('same-day: unchanged streakDays', r.streak.currentStreakDays, 5);
  eq('same-day: unchanged totalVisits', r.streak.totalVisits, 12);
  assert('same-day: returns same object', r.streak === existing);
}

// Within window => increment
{
  const existing: StreakCore = {
    currentStreakDays: 5, longestStreakDays: 5, totalVisits: 5,
    lastVisitDate: YESTERDAY, streakStartDate: '2026-07-10', isStreakAlive: true,
  };
  const r = computeCheckIn(existing, TODAY, 3);
  eq('within-window(1d,win3): increments', r.streak.currentStreakDays, 6);
  eq('within-window: totalVisits++', r.streak.totalVisits, 6);
  eq('within-window: keeps streakStartDate', r.streak.streakStartDate, '2026-07-10');
  eq('within-window: longest bumped', r.streak.longestStreakDays, 6);
}

// At the window boundary (daysSince == window) => still increment
{
  const existing: StreakCore = {
    currentStreakDays: 2, longestStreakDays: 2, totalVisits: 2,
    lastVisitDate: TWO_AGO, streakStartDate: TWO_AGO, isStreakAlive: true,
  };
  const r = computeCheckIn(existing, TODAY, 2);
  eq('boundary(2d,win2): increments', r.streak.currentStreakDays, 3);
}

// Beyond window => reset to 1
{
  const existing: StreakCore = {
    currentStreakDays: 8, longestStreakDays: 8, totalVisits: 8,
    lastVisitDate: FOUR_AGO, streakStartDate: '2026-07-05', isStreakAlive: true,
  };
  const r = computeCheckIn(existing, TODAY, 2);
  eq('beyond-window: resets currentStreakDays', r.streak.currentStreakDays, 1);
  eq('beyond-window: totalVisits still increments', r.streak.totalVisits, 9);
  eq('beyond-window: new streakStartDate', r.streak.streakStartDate, TODAY);
  eq('beyond-window: preserves longest', r.streak.longestStreakDays, 8);
}

// --- qualifyingTiers (voucher awarding + idempotency) -----------------------

const tiers: RewardTier[] = [
  { id: 's_v5', shopId: 's', type: 'visit_count', threshold: 5, discountPercent: 10, label: 'Regular', description: '', emoji: '⭐' },
  { id: 's_v10', shopId: 's', type: 'visit_count', threshold: 10, discountPercent: 20, label: 'Loyal', description: '', emoji: '💎' },
  { id: 's_s3', shopId: 's', type: 'streak_days', threshold: 3, discountPercent: 5, label: '3-Day', description: '', emoji: '🔥' },
];

// Threshold just reached => awards exactly the tiers met, none above
{
  const streak: StreakCore = {
    currentStreakDays: 3, longestStreakDays: 3, totalVisits: 5,
    lastVisitDate: TODAY, streakStartDate: TODAY, isStreakAlive: true,
  };
  const q = qualifyingTiers(streak, tiers, new Set());
  const ids = q.map((t) => t.id).sort();
  eq('awards v5 + s3', JSON.stringify(ids), JSON.stringify(['s_s3', 's_v5']));
  assert('does not award v10 (threshold 10 > 5)', !ids.includes('s_v10'));
}

// Idempotency: already-awarded tiers are skipped
{
  const streak: StreakCore = {
    currentStreakDays: 3, longestStreakDays: 3, totalVisits: 5,
    lastVisitDate: TODAY, streakStartDate: TODAY, isStreakAlive: true,
  };
  const q = qualifyingTiers(streak, tiers, new Set(['s_v5', 's_s3']));
  eq('idempotent: nothing re-awarded', q.length, 0);
}

// Nothing qualifies below all thresholds
{
  const streak: StreakCore = {
    currentStreakDays: 1, longestStreakDays: 1, totalVisits: 1,
    lastVisitDate: TODAY, streakStartDate: TODAY, isStreakAlive: true,
  };
  eq('below thresholds: none', qualifyingTiers(streak, tiers, new Set()).length, 0);
}

// --- timezone day boundary --------------------------------------------------
{
  // 2026-07-16 16:30 UTC is 2026-07-17 00:30 in Kuala Lumpur (UTC+8).
  const d = new Date('2026-07-16T16:30:00Z');
  eq('KL tz rolls to next day', toDateStringInTZ(d, 'Asia/Kuala_Lumpur'), '2026-07-17');
  eq('UTC stays same day', toDateStringInTZ(d, 'UTC'), '2026-07-16');
}


// --- embers & repair --------------------------------------------------------

{
  eq('repair: sub-3-day streak is free/ineligible', repairCost(2), 0);
  eq('repair: 3-day costs 2', repairCost(3), 2);
  eq('repair: 6-day costs 2', repairCost(6), 2);
  eq('repair: 7-day costs 5', repairCost(7), 5);
  eq('repair: 29-day costs 5', repairCost(29), 5);
  eq('repair: 30-day costs 15', repairCost(30), 15);
  eq('repair: 100-day costs 15', repairCost(100), 15);
  assert('repair: price rises with streak', repairCost(3) < repairCost(7) && repairCost(7) < repairCost(30));

  // window 3: visited TODAY-2 is still alive, TODAY-4 is broken.
  const alive = { currentStreakDays: 10, lastVisitDate: addDays(TODAY, -2) };
  eq('eligibility: inside window is not broken',
    repairEligibility(alive, TODAY, 3), 'not_broken');

  const broken = { currentStreakDays: 10, lastVisitDate: addDays(TODAY, -4) };
  eq('eligibility: just past the window is repairable',
    repairEligibility(broken, TODAY, 3), 'repairable');

  const shortStreak = { currentStreakDays: 2, lastVisitDate: addDays(TODAY, -4) };
  eq('eligibility: a 2-day streak is too short to repair',
    repairEligibility(shortStreak, TODAY, 3), 'too_short');

  const abandoned = { currentStreakDays: 30, lastVisitDate: addDays(TODAY, -6) };
  eq('eligibility: past the grace period it is gone for good',
    repairEligibility(abandoned, TODAY, 3), 'too_late');

  const never = { currentStreakDays: 0, lastVisitDate: '' };
  eq('eligibility: no visits yet is not a break',
    repairEligibility(never, TODAY, 3), 'not_broken');

  // A repair restores the streak without counting as a visit.
  const core = {
    currentStreakDays: 12, longestStreakDays: 12, totalVisits: 30,
    lastVisitDate: addDays(TODAY, -4), streakStartDate: '2026-01-01', isStreakAlive: false,
  };
  const repaired = applyRepair(core, TODAY);
  eq('repair: streak length is preserved, not incremented', repaired.currentStreakDays, 12);
  eq('repair: totalVisits unchanged (a repair is not a visit)', repaired.totalVisits, 30);
  eq('repair: alive again', repaired.isStreakAlive, true);
  eq('repair: reads as visited yesterday', repaired.lastVisitDate, addDays(TODAY, -1));
  // ...which means checking in today still increments rather than being a no-op.
  eq('repair: a check-in today still counts',
    computeCheckIn(repaired, TODAY, 3).streak.currentStreakDays, 13);
}

// --- summary ----------------------------------------------------------------
console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
