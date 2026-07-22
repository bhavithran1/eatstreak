// Plain-Node unit tests for the pure check-in logic. No emulator / Java needed.
// Run: npm test  (compiles with tsconfig.test.json, then executes this file)
//
// Covers the exact scenarios from the plan's verification section.

import { computeCheckIn, qualifyingTiers, StreakCore } from './streakLogic';
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

// --- summary ----------------------------------------------------------------
console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
