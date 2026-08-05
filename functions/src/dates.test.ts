// Plain-Node unit tests for the date helpers. Run: npm test
//
// These are half of a ported pair — `mobile/lib/core/utils/dates.dart` is the
// other half — so the cases here are mirrored by `test/core/dates_test.dart`.
// The two implementations silently disagreed on unreadable input for as long as
// neither was tested on it: this returned a NaN that compared false against
// every threshold (quietly *preserving* a streak), while Dart threw a
// FormatException that took out the owner dashboard.

import {
  daysBetween,
  addDays,
  toDateStringInTZ,
  UNKNOWN_DATE_DISTANCE_DAYS,
  DEFAULT_TIME_ZONE,
} from './dates';

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

// --- daysBetween: the ordinary cases ----------------------------------------
{
  assert('same day is 0', daysBetween('2026-03-01', '2026-03-01') === 0);
  assert('consecutive days is 1', daysBetween('2026-03-01', '2026-03-02') === 1);
  assert('order does not matter', daysBetween('2026-03-05', '2026-03-01') === 4);
  assert('across a month boundary', daysBetween('2026-02-27', '2026-03-02') === 3);
  assert('across a leap day', daysBetween('2028-02-28', '2028-03-01') === 2);
  assert('across a year boundary', daysBetween('2025-12-31', '2026-01-01') === 1);
  assert('a full year', daysBetween('2026-01-01', '2027-01-01') === 365);
}

// --- daysBetween: unreadable input ------------------------------------------
// The value must read as "long ago". Returning 0 would keep a streak alive off
// a corrupt document, which is the failure this constant exists to prevent.
{
  assert('the parity constant is 99999 (must match dates.dart)',
    UNKNOWN_DATE_DISTANCE_DAYS === 99999);

  assert('an empty date is unknown, not NaN',
    daysBetween('', '2026-03-01') === UNKNOWN_DATE_DISTANCE_DAYS);

  assert('an empty second date is unknown',
    daysBetween('2026-03-01', '') === UNKNOWN_DATE_DISTANCE_DAYS);

  assert('both empty is unknown',
    daysBetween('', '') === UNKNOWN_DATE_DISTANCE_DAYS);

  assert('junk is unknown',
    daysBetween('not-a-date', '2026-03-01') === UNKNOWN_DATE_DISTANCE_DAYS);

  assert('the result is never NaN',
    !Number.isNaN(daysBetween('', '')));

  // The whole point of the sentinel: it has to lapse a streak, not preserve
  // one. NaN failed this — `NaN > 3` is false.
  assert('unknown exceeds any real streak window',
    UNKNOWN_DATE_DISTANCE_DAYS > 90);
}

// --- daysBetween: ISO instants ----------------------------------------------
// Documents in the wild carry both shapes. The contract for an instant is only
// that it is *read* rather than thrown away — comparing an instant to a bare
// day mixes zones (this side parses a bare day in UTC, the Dart side in
// device-local time), so the exact figure is not something either side
// promises. Two bare days, the documented input, agree exactly.
{
  assert('an ISO instant is accepted, not rejected',
    daysBetween('2026-03-01T10:30:00Z', '2026-03-01') !== UNKNOWN_DATE_DISTANCE_DAYS);

  assert('an ISO instant on the same day is within a day of it',
    daysBetween('2026-03-01T10:30:00Z', '2026-03-01') <= 1);

  assert('an instant a week out is a week away, zone skew aside',
    daysBetween('2026-03-08T10:30:00Z', '2026-03-01') >= 6 &&
    daysBetween('2026-03-08T10:30:00Z', '2026-03-01') <= 8);
}

// --- addDays ----------------------------------------------------------------
{
  assert('adds within a month', addDays('2026-03-01', 5) === '2026-03-06');
  assert('crosses a month boundary', addDays('2026-02-27', 3) === '2026-03-02');
  assert('crosses a leap day', addDays('2028-02-28', 2) === '2028-03-01');
  assert('adds 30 days (the voucher window)', addDays('2026-03-01', 30) === '2026-03-31');
  assert('subtracts with a negative n', addDays('2026-03-01', -1) === '2026-02-28');
  assert('adding zero is identity', addDays('2026-03-01', 0) === '2026-03-01');

  // Feeds a voucher's expiresAt. "Invalid Date" there is a voucher that can
  // never be redeemed, so unparseable input comes back untouched instead.
  assert('junk is returned unchanged, not "Invalid Date"',
    addDays('not-a-date', 30) === 'not-a-date');

  assert('an empty string is returned unchanged', addDays('', 30) === '');
}

// --- toDateStringInTZ -------------------------------------------------------
// The shop's own midnight is what turns a check-in code over, so the timezone
// has to actually shift the calendar day.
{
  assert('formats as YYYY-MM-DD',
    /^\d{4}-\d{2}-\d{2}$/.test(toDateStringInTZ(new Date('2026-03-01T12:00:00Z'))));

  // 16:30 UTC is 00:30 the next day in Kuala Lumpur (UTC+8).
  assert('the shop timezone moves the day forward past its midnight',
    toDateStringInTZ(new Date('2026-02-28T16:30:00Z'), DEFAULT_TIME_ZONE) === '2026-03-01');

  assert('the same instant is still the previous day in UTC',
    toDateStringInTZ(new Date('2026-02-28T16:30:00Z'), 'UTC') === '2026-02-28');

  assert('just before the shop midnight is still the old day',
    toDateStringInTZ(new Date('2026-02-28T15:30:00Z'), DEFAULT_TIME_ZONE) === '2026-02-28');
}

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
