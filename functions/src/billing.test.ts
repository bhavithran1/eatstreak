// Plain-Node unit tests for webhook authenticity and event mapping. These are
// the two things most likely to be silently wrong in a payment integration and
// both are decidable without a Curlec account. Run: npm test

import { createHmac } from 'crypto';
import { verifyWebhookSignature, statusForEvent, shopIdFromPayload } from './billing';

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

const SECRET = 'whsec_test_123';
const body = JSON.stringify({
  event: 'subscription.charged',
  payload: { subscription: { entity: { notes: { shopId: 'shop_abc' } } } },
});
const sign = (b: string, secret = SECRET) =>
  createHmac('sha256', secret).update(b).digest('hex');

// --- signature --------------------------------------------------------------
{
  assert('accepts a correctly signed body',
    verifyWebhookSignature(body, sign(body), SECRET) === true);

  assert('accepts the same bytes as a Buffer',
    verifyWebhookSignature(Buffer.from(body, 'utf8'), sign(body), SECRET) === true);

  assert('rejects a missing signature',
    verifyWebhookSignature(body, undefined, SECRET) === false);

  assert('rejects an empty signature',
    verifyWebhookSignature(body, '', SECRET) === false);

  assert('rejects a signature made with the wrong secret',
    verifyWebhookSignature(body, sign(body, 'whsec_attacker'), SECRET) === false);

  // The attack this defends against: same signature, altered payload.
  const tampered = body.replace('shop_abc', 'shop_victim');
  assert('rejects a tampered body under a valid old signature',
    verifyWebhookSignature(tampered, sign(body), SECRET) === false);

  assert('rejects a truncated signature (no length-mismatch crash)',
    verifyWebhookSignature(body, sign(body).slice(0, 32), SECRET) === false);

  assert('rejects when no secret is configured',
    verifyWebhookSignature(body, sign(body), '') === false);

  // Re-serialised JSON has different bytes; this is why rawBody matters.
  const reserialised = JSON.stringify(JSON.parse(body).payload);
  assert('a re-serialised body does not verify',
    verifyWebhookSignature(reserialised, sign(body), SECRET) === false);
}

// --- event mapping ----------------------------------------------------------
{
  assert('charged grants access', statusForEvent('subscription.charged') === 'active');
  assert('activated grants access', statusForEvent('subscription.activated') === 'active');
  assert('resumed grants access', statusForEvent('subscription.resumed') === 'active');
  assert('halted is past due', statusForEvent('subscription.halted') === 'past_due');
  assert('pending is past due', statusForEvent('subscription.pending') === 'past_due');
  assert('cancelled revokes', statusForEvent('subscription.cancelled') === 'cancelled');
  assert('completed revokes', statusForEvent('subscription.completed') === 'cancelled');

  // An event type added by Razorpay later must not revoke a paying customer.
  assert('an unrecognised event is unknown, not a downgrade',
    statusForEvent('subscription.something.new') === 'unknown');
  assert('an unrelated event is unknown', statusForEvent('payment.failed') === 'unknown');
}

// --- attribution ------------------------------------------------------------
{
  assert('reads shopId from subscription notes',
    shopIdFromPayload(JSON.parse(body).payload) === 'shop_abc');

  assert('no notes means no attribution',
    shopIdFromPayload({ subscription: { entity: {} } }) === null);

  assert('empty shopId is not attribution',
    shopIdFromPayload({ subscription: { entity: { notes: { shopId: '' } } } }) === null);

  assert('a non-string shopId is rejected',
    shopIdFromPayload({ subscription: { entity: { notes: { shopId: 42 } } } }) === null);

  assert('a malformed payload does not throw', shopIdFromPayload(null) === null);
}

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
