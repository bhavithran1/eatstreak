// Pure billing logic: webhook authenticity and what each event means.
//
// Kept I/O-free so it can be unit-tested without a Curlec account — the two
// things most likely to be wrong here are the signature check and the event
// mapping, and both are decidable from a string.

import { createHmac, timingSafeEqual } from 'crypto';

export type SubscriptionStatus = 'active' | 'past_due' | 'cancelled' | 'unknown';

/**
 * Verify a Curlec/Razorpay webhook signature.
 *
 * HMAC-SHA256 of the **raw** request body, keyed by the webhook secret, hex
 * encoded, delivered in `X-Razorpay-Signature`.
 *
 * [rawBody] must be the bytes exactly as received. Firebase's onRequest runs
 * Express, which has already JSON-parsed `req.body`; re-serialising that gives
 * different bytes (key order, whitespace) and every signature fails. Use
 * `req.rawBody`.
 *
 * Compared in constant time — a plain `===` leaks the correct prefix through
 * timing and turns forgery into a byte-at-a-time search.
 */
export function verifyWebhookSignature(
  rawBody: Buffer | string,
  signature: string | undefined,
  secret: string,
): boolean {
  if (!signature || !secret) return false;

  const expected = createHmac('sha256', secret).update(rawBody).digest('hex');
  const given = Buffer.from(signature, 'utf8');
  const mine = Buffer.from(expected, 'utf8');

  // timingSafeEqual throws on length mismatch, which is itself a leak-free
  // rejection — but guard so a malformed header can't crash the function.
  if (given.length !== mine.length) return false;
  return timingSafeEqual(given, mine);
}

/**
 * What a subscription event means for access.
 *
 * Deliberately conservative: only events that positively confirm a paid,
 * running subscription grant `active`. Anything unrecognised is `unknown` and
 * leaves existing state alone, so a new event type Razorpay adds later can
 * never silently revoke a paying customer's access.
 */
export function statusForEvent(event: string): SubscriptionStatus {
  switch (event) {
    case 'subscription.activated':
    case 'subscription.charged':
    case 'subscription.resumed':
    case 'subscription.updated':
      return 'active';

    // Authenticated means the mandate exists but the first charge has not
    // landed. Access is already covered by the free month at that point.
    case 'subscription.pending':
    case 'subscription.halted':
      return 'past_due';

    case 'subscription.cancelled':
    case 'subscription.completed':
    case 'subscription.expired':
      return 'cancelled';

    default:
      return 'unknown';
  }
}

/**
 * The shop a subscription belongs to.
 *
 * Set as `notes.shopId` when the subscription is created. Without it a webhook
 * cannot be attributed, and guessing — by email, say — would let one owner's
 * payment activate another's shop.
 */
export function shopIdFromPayload(payload: unknown): string | null {
  const sub = (payload as { subscription?: { entity?: { notes?: Record<string, unknown> } } })
    ?.subscription?.entity;
  const shopId = sub?.notes?.shopId;
  return typeof shopId === 'string' && shopId.length > 0 ? shopId : null;
}
