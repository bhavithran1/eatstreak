// Plain-Node unit tests for the single-use check-in code rules. No emulator /
// Java needed. Run: npm test

import {
  isCheckInTokenValid,
  newCheckInTokenDoc,
  CHECK_IN_TOKEN_TTL_SECONDS,
} from './checkInToken';
import { CheckInTokenDoc } from './types';

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

const NOW = new Date('2026-07-23T10:00:00.000Z');
const NOW_MS = NOW.getTime();
const SHOP = 'shop_1';

function fresh(overrides: Partial<CheckInTokenDoc> = {}): CheckInTokenDoc {
  return { ...newCheckInTokenDoc(SHOP, 'owner_1', NOW), ...overrides };
}

// --- newCheckInTokenDoc -----------------------------------------------------
{
  const d = newCheckInTokenDoc(SHOP, 'owner_1', NOW);
  assert('new doc: shopId set', d.shopId === SHOP);
  assert('new doc: ownerId set', d.ownerId === 'owner_1');
  assert('new doc: starts unused', d.used === false && d.usedBy === null && d.usedAt === null);
  assert(
    'new doc: expires TTL seconds after creation',
    new Date(d.expiresAt).getTime() - new Date(d.createdAt).getTime() ===
      CHECK_IN_TOKEN_TTL_SECONDS * 1000,
  );
}

// --- isCheckInTokenValid ----------------------------------------------------
{
  assert('valid: fresh code for this shop', isCheckInTokenValid(fresh(), SHOP, NOW_MS) === true);

  assert('invalid: missing token', isCheckInTokenValid(null, SHOP, NOW_MS) === false);

  assert(
    'invalid: code for another shop',
    isCheckInTokenValid(fresh(), 'shop_other', NOW_MS) === false,
  );

  assert(
    'invalid: already used (single-use)',
    isCheckInTokenValid(fresh({ used: true, usedBy: 'cust', usedAt: NOW.toISOString() }), SHOP, NOW_MS) ===
      false,
  );

  // Just before expiry → still valid; just after → expired.
  const expiryMs = new Date(fresh().expiresAt).getTime();
  assert('valid: one second before expiry', isCheckInTokenValid(fresh(), SHOP, expiryMs - 1000) === true);
  assert('invalid: one second after expiry', isCheckInTokenValid(fresh(), SHOP, expiryMs + 1000) === false);
  assert('valid: exactly at expiry instant', isCheckInTokenValid(fresh(), SHOP, expiryMs) === true);
}

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
