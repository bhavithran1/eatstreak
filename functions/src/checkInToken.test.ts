// Plain-Node unit tests for the daily check-in code rules. No emulator / Java
// needed. Run: npm test

import {
  isCheckInTokenValid,
  newCheckInTokenDoc,
  checkInTokenDocId,
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
const TODAY = '2026-07-23';
const YESTERDAY = '2026-07-22';
const SHOP = 'shop_1';
const SECRET = 's3cr3t-abc';

function code(overrides: Partial<CheckInTokenDoc> = {}): CheckInTokenDoc {
  return { ...newCheckInTokenDoc(SHOP, 'owner_1', TODAY, SECRET, NOW), ...overrides };
}

// --- doc id -----------------------------------------------------------------
{
  assert('doc id is one per shop per day', checkInTokenDocId(SHOP, TODAY) === `${SHOP}_${TODAY}`);
  assert(
    'doc id differs across days',
    checkInTokenDocId(SHOP, TODAY) !== checkInTokenDocId(SHOP, YESTERDAY),
  );
}

// --- newCheckInTokenDoc -----------------------------------------------------
{
  const d = newCheckInTokenDoc(SHOP, 'owner_1', TODAY, SECRET, NOW);
  assert('new doc: shopId set', d.shopId === SHOP);
  assert('new doc: ownerId set', d.ownerId === 'owner_1');
  assert('new doc: date set', d.date === TODAY);
  assert('new doc: secret set', d.secret === SECRET);
  assert(
    'new doc: cleanup backstop is TTL seconds out',
    new Date(d.expiresAt).getTime() - new Date(d.createdAt).getTime() ===
      CHECK_IN_TOKEN_TTL_SECONDS * 1000,
  );
}

// --- isCheckInTokenValid ----------------------------------------------------
{
  assert("valid: today's code, right shop, right secret",
    isCheckInTokenValid(code(), SHOP, TODAY, SECRET) === true);

  assert('invalid: no code for today', isCheckInTokenValid(null, SHOP, TODAY, SECRET) === false);

  assert("invalid: yesterday's code today",
    isCheckInTokenValid(code({ date: YESTERDAY }), SHOP, TODAY, SECRET) === false);

  assert('invalid: code belongs to another shop',
    isCheckInTokenValid(code({ shopId: 'shop_other' }), SHOP, TODAY, SECRET) === false);

  assert('invalid: wrong secret (guessed code)',
    isCheckInTokenValid(code(), SHOP, TODAY, 'not-the-secret') === false);

  assert('invalid: empty presented secret',
    isCheckInTokenValid(code(), SHOP, TODAY, '') === false);

  assert('invalid: stored secret missing',
    isCheckInTokenValid(code({ secret: '' }), SHOP, TODAY, '') === false);

  // Rotating issues a new secret; the old one must stop working immediately.
  assert('invalid: superseded secret after rotate',
    isCheckInTokenValid(code({ secret: 'rotated-new' }), SHOP, TODAY, SECRET) === false);
}

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
