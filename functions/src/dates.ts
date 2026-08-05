// Date helpers ported from app/src/utils/dates.ts, with one deliberate change:
// the "current day" is computed in a fixed shop timezone rather than the server's
// local time (functions run in UTC). This keeps a near-midnight check-in
// consistent regardless of where the function executes. See plan risk note.

export const DEFAULT_TIME_ZONE = 'Asia/Kuala_Lumpur';

/** YYYY-MM-DD for `date` as observed in `timeZone`. */
export function toDateStringInTZ(date: Date, timeZone: string = DEFAULT_TIME_ZONE): string {
  // en-CA formats as YYYY-MM-DD; timeZone shifts the wall-clock day correctly.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

/**
 * Distance reported for a date we cannot read.
 *
 * Must read as "long ago", never "today": an unreadable last-visit date should
 * lapse a streak rather than keep one alive off a corrupt document.
 *
 * Mirrored by `unknownDateDistanceDays` in `mobile/lib/core/utils/dates.dart`,
 * and asserted literally on both sides. The two used to disagree on exactly
 * this input — `new Date('T00:00:00Z')` is an Invalid Date, so this returned a
 * silent NaN (and `NaN > windowDays` is false, quietly *preserving* the streak,
 * the opposite of the safe answer) where Dart threw a FormatException.
 */
export const UNKNOWN_DATE_DISTANCE_DAYS = 99999;

/** Accepts both a YYYY-MM-DD day and a full ISO instant. Null when neither. */
function parseDay(dateStr: string): Date | null {
  if (!dateStr) return null;
  const d = new Date(dateStr.includes('T') ? dateStr : dateStr + 'T00:00:00Z');
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * Whole-day distance between two YYYY-MM-DD strings (order-independent).
 * [UNKNOWN_DATE_DISTANCE_DAYS] if either side is missing or unparseable.
 */
export function daysBetween(dateStr1: string, dateStr2: string): number {
  const d1 = parseDay(dateStr1);
  const d2 = parseDay(dateStr2);
  if (d1 === null || d2 === null) return UNKNOWN_DATE_DISTANCE_DAYS;
  const diff = Math.abs(d2.getTime() - d1.getTime());
  return Math.round(diff / (1000 * 60 * 60 * 24));
}

/**
 * Add `n` days to a YYYY-MM-DD string, returning YYYY-MM-DD. Unparseable input
 * is returned unchanged rather than becoming the string "Invalid Date" — this
 * feeds a voucher's `expiresAt`, and a garbage timestamp there is a voucher
 * that can never be redeemed.
 */
export function addDays(dateStr: string, n: number): string {
  const d = parseDay(dateStr);
  if (d === null) return dateStr;
  d.setUTCDate(d.getUTCDate() + n);
  return toDateStringInTZ(d, 'UTC');
}
