// Pure logic for single-use check-in codes, factored out of the callable so it
// can be unit-tested without an emulator (same approach as streakLogic.ts).

import { CheckInTokenDoc } from './types';

// How long a code stays valid while it sits on the owner's screen. The code is
// replaced the moment it's scanned (single-use + regenerate-on-use), so this is
// only a backstop: long enough that a code never expires under a waiting
// customer, short enough to bound a photographed-but-unscanned code and to let
// Firestore TTL clean up abandoned codes daily.
export const CHECK_IN_TOKEN_TTL_SECONDS = 24 * 60 * 60;

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
