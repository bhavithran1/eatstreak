// Pure logic for daily check-in codes, factored out of the callables so it can
// be unit-tested without an emulator (same approach as streakLogic.ts).
//
// One code per shop per day. The code is a random secret — never derived from
// the shop id — so it can't be guessed, and yesterday's code is dead today.
// There is no per-scan consumption: the server already caps check-ins at one
// per shop per day, so a code is only ever worth one visit to any one customer.

import { CheckInTokenDoc } from './types';

// Cleanup backstop only; validity is decided by the code's `date`, not by this.
// Two days of slack keeps a code around long enough to be diagnosable.
export const CHECK_IN_TOKEN_TTL_SECONDS = 48 * 60 * 60;

/** One document per shop per day. */
export function checkInTokenDocId(shopId: string, date: string): string {
  return `${shopId}_${date}`;
}

/** A day's code document. [date] is the shop-timezone calendar day. */
export function newCheckInTokenDoc(
  shopId: string,
  ownerId: string,
  date: string,
  secret: string,
  now: Date,
): CheckInTokenDoc {
  return {
    shopId,
    ownerId,
    date,
    secret,
    createdAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + CHECK_IN_TOKEN_TTL_SECONDS * 1000).toISOString(),
  };
}

/**
 * Whether [presented] is the valid check-in code for [shopId] on [today].
 * Rejects a missing code, another shop's code, a different day's code, and any
 * secret that doesn't match exactly.
 */
export function isCheckInTokenValid(
  doc: CheckInTokenDoc | null,
  shopId: string,
  today: string,
  presented: string,
): boolean {
  if (doc === null) return false;
  if (doc.shopId !== shopId) return false;
  if (doc.date !== today) return false;
  if (!doc.secret || !presented) return false;
  return doc.secret === presented;
}
