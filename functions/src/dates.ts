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

/** Whole-day distance between two YYYY-MM-DD strings (order-independent). */
export function daysBetween(dateStr1: string, dateStr2: string): number {
  const d1 = new Date(dateStr1 + 'T00:00:00Z');
  const d2 = new Date(dateStr2 + 'T00:00:00Z');
  const diff = Math.abs(d2.getTime() - d1.getTime());
  return Math.round(diff / (1000 * 60 * 60 * 24));
}

/** Add `n` days to a YYYY-MM-DD string, returning YYYY-MM-DD. */
export function addDays(dateStr: string, n: number): string {
  const d = new Date(dateStr + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return toDateStringInTZ(d, 'UTC');
}
