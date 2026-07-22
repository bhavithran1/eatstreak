// Pure logic for single-use check-in codes, factored out of the callable so it
// can be unit-tested without an emulator (same approach as streakLogic.ts).

import { CheckInTokenDoc } from './types';

// A check-in code is valid for this long, then the owner's screen rotates it.
// Short enough that a screenshot is useless, long enough to show at a counter.
export const CHECK_IN_TOKEN_TTL_SECONDS = 90;

/** A freshly minted, unused check-in code document. */
export function newCheckInTokenDoc(
  shopId: string,
  ownerId: string,
  now: Date,
): CheckInTokenDoc {
  return {
    shopId,
    ownerId,
    createdAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + CHECK_IN_TOKEN_TTL_SECONDS * 1000).toISOString(),
    used: false,
    usedBy: null,
    usedAt: null,
  };
}

/**
 * Whether a scanned single-use code may be consumed for [shopId] at [nowMs].
 * Valid only if it exists, is for this shop, hasn't been used, and hasn't
 * expired. Everything else — a stale QR, a screenshot, a code for another
 * shop — is rejected.
 */
export function isCheckInTokenValid(
  token: CheckInTokenDoc | null,
  shopId: string,
  nowMs: number,
): boolean {
  if (token === null) return false;
  if (token.shopId !== shopId) return false;
  if (token.used === true) return false;
  if (new Date(token.expiresAt).getTime() < nowMs) return false;
  return true;
}
