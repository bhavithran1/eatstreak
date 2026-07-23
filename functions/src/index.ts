import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { randomBytes } from 'crypto';

import { Shop, Streak, Visit, Voucher, VisitResult, CheckInTokenDoc } from './types';
import { toDateStringInTZ, DEFAULT_TIME_ZONE, addDays } from './dates';
import {
  computeCheckIn,
  qualifyingTiers,
  generateVoucherCode,
  StreakCore,
  EMBERS_PER_CHECK_IN,
  repairCost,
  repairEligibility,
  applyRepair,
} from './streakLogic';
import {
  CHECK_IN_TOKEN_TTL_SECONDS,
  checkInTokenDocId,
  newCheckInTokenDoc,
  isCheckInTokenValid,
} from './checkInToken';

admin.initializeApp();
const db = admin.firestore();

// Singapore region — lowest latency for Malaysian users.
setGlobalOptions({ region: 'asia-southeast1', maxInstances: 10 });

const streakId = (uid: string, shopId: string) => `${uid}_${shopId}`;
const voucherId = (uid: string, tierId: string) => `${uid}_${tierId}`;

/**
 * Today's check-in code for a shop the caller owns. Idempotent: every call on
 * the same day returns the same code, so the owner's screen can just ask for it
 * on open. Pass `rotate: true` to burn the current code and issue a new one —
 * the escape hatch if a code leaks.
 */
export const createCheckInToken = onCall(
  async (request: CallableRequest<{ shopId?: string; rotate?: boolean }>) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'You must be signed in.');

    const shopId = request.data?.shopId;
    if (!shopId || typeof shopId !== 'string') {
      throw new HttpsError('invalid-argument', 'shopId is required.');
    }

    const shopSnap = await db.collection('shops').doc(shopId).get();
    if (!shopSnap.exists) throw new HttpsError('not-found', 'Shop not found.');
    const shop = shopSnap.data() as Shop;
    if (shop.ownerId !== uid) {
      throw new HttpsError('permission-denied', 'Only the shop owner can create a check-in code.');
    }

    // The shop's own calendar day, so the code turns over at the same boundary
    // the streak logic uses.
    const today = toDateStringInTZ(new Date(), shop.timeZone || DEFAULT_TIME_ZONE);
    const ref = db.collection('checkInTokens').doc(checkInTokenDocId(shopId, today));

    const existing = await ref.get();
    if (existing.exists && request.data?.rotate !== true) {
      const doc = existing.data() as CheckInTokenDoc;
      return { token: doc.secret, shopId, expiresAt: doc.expiresAt, ttlSeconds: CHECK_IN_TOKEN_TTL_SECONDS };
    }

    const doc = newCheckInTokenDoc(shopId, uid, today, randomBytes(18).toString('base64url'), new Date());
    await ref.set({
      ...doc,
      // Timestamp mirror of expiresAt, read only by the Firestore TTL policy so
      // yesterday's codes auto-delete.
      ttlAt: admin.firestore.Timestamp.fromDate(new Date(doc.expiresAt)),
    });

    return { token: doc.secret, shopId, expiresAt: doc.expiresAt, ttlSeconds: CHECK_IN_TOKEN_TTL_SECONDS };
  },
);

/**
 * Server-authoritative check-in. Replaces the old on-device registerVisit().
 * Runs the entire streak + voucher update inside a Firestore transaction so
 * concurrent scans can't double-count, and clients can never write these docs
 * directly (security rules deny all client writes to streaks/visits/vouchers).
 */
export const checkIn = onCall(async (request: CallableRequest<{ shopId?: string; token?: string }>): Promise<VisitResult> => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'You must be signed in to check in.');

  const shopId = request.data?.shopId;
  if (!shopId || typeof shopId !== 'string') {
    throw new HttpsError('invalid-argument', 'shopId is required.');
  }

  // Every check-in must carry the shop's code for today. A bare shop link or
  // yesterday's screenshot has no valid code, so it resolves to `code_invalid`
  // rather than logging a visit.
  const token = request.data?.token;
  if (!token || typeof token !== 'string') {
    return { status: 'code_invalid' };
  }

  const shopSnap = await db.collection('shops').doc(shopId).get();
  if (!shopSnap.exists) {
    return { status: 'shop_not_found' };
  }
  const shop = shopSnap.data() as Shop;

  const userSnap = await db.collection('users').doc(uid).get();
  const userName = (userSnap.data()?.name as string) || 'Guest';

  const timeZone = shop.timeZone || DEFAULT_TIME_ZONE;
  const now = new Date();
  const nowIso = now.toISOString();
  const todayStr = toDateStringInTZ(now, timeZone);

  // Validate against today's code. Read-only — the code isn't consumed, so no
  // transaction is needed here; one check-in per shop per day is what bounds
  // what a leaked code is worth.
  const codeSnap = await db
    .collection('checkInTokens')
    .doc(checkInTokenDocId(shopId, todayStr))
    .get();
  const codeDoc = codeSnap.exists ? (codeSnap.data() as CheckInTokenDoc) : null;
  if (!isCheckInTokenValid(codeDoc, shopId, todayStr, token)) {
    return { status: 'code_invalid' };
  }

  const sRef = db.collection('streaks').doc(streakId(uid, shopId));

  const result = await db.runTransaction(async (tx) => {
    const sSnap = await tx.get(sRef);
    const existing = sSnap.exists ? (sSnap.data() as Streak) : null;
    const existingCore: StreakCore | null = existing
      ? {
          currentStreakDays: existing.currentStreakDays,
          longestStreakDays: existing.longestStreakDays,
          totalVisits: existing.totalVisits,
          lastVisitDate: existing.lastVisitDate,
          streakStartDate: existing.streakStartDate,
          isStreakAlive: existing.isStreakAlive,
        }
      : null;

    const { status, streak: nextCore } = computeCheckIn(existingCore, todayStr, shop.streakWindowDays);

    const fullStreak: Streak = {
      id: streakId(uid, shopId),
      userId: uid,
      shopId,
      shopOwnerId: shop.ownerId,
      userName,
      ...nextCore,
    };

    if (status === 'already_visited_today') {
      return { status, streak: fullStreak, newVouchers: [] as Voucher[], visit: undefined as Visit | undefined };
    }

    // Which tiers qualify at this new streak, and which of those we haven't
    // minted yet. Idempotency is enforced by the deterministic voucher doc id
    // {uid}_{tierId}: read the candidate docs first (all reads precede writes).
    const candidateTiers = qualifyingTiers(nextCore, shop.rewardTiers, new Set());
    const voucherRefs = candidateTiers.map((t) => db.collection('vouchers').doc(voucherId(uid, t.id)));
    const voucherSnaps = voucherRefs.length ? await tx.getAll(...voucherRefs) : [];
    const tiersToMint = candidateTiers.filter((_, i) => !voucherSnaps[i].exists);

    // ---- writes ----
    // Embers are earned only by actually turning up, which is what makes them
    // a fair price for repairing a streak later.
    tx.set(
      db.collection('users').doc(uid),
      { embers: admin.firestore.FieldValue.increment(EMBERS_PER_CHECK_IN) },
      { merge: true },
    );

    const visitRef = db.collection('visits').doc();
    const visit: Visit = {
      id: visitRef.id,
      userId: uid,
      shopId,
      shopOwnerId: shop.ownerId,
      userName,
      timestamp: nowIso,
    };
    tx.set(visitRef, visit);
    tx.set(sRef, fullStreak);

    const newVouchers: Voucher[] = tiersToMint.map((tier) => {
      const voucher: Voucher = {
        id: voucherId(uid, tier.id),
        userId: uid,
        shopId: shop.id,
        shopOwnerId: shop.ownerId,
        shopName: shop.name,
        shopEmoji: shop.emoji,
        tierId: tier.id,
        type: tier.type,
        discountPercent: tier.discountPercent,
        tierLabel: tier.label,
        earnedAt: nowIso,
        expiresAt: addDays(todayStr, 30) + 'T23:59:59Z',
        isRedeemed: false,
        redeemedAt: null,
        code: generateVoucherCode(),
      };
      tx.set(db.collection('vouchers').doc(voucher.id), voucher);
      return voucher;
    });

    return { status, streak: fullStreak, newVouchers, visit };
  });

  return {
    status: result.status,
    streak: result.streak,
    visit: result.visit,
    newVouchers: result.newVouchers,
    shop,
  };
});

/**
 * Repair a broken streak by spending embers.
 *
 * Losing a long streak should cost something — that is what makes it worth
 * keeping — but the price is paid in embers earned by visiting, never in money.
 * Charging a customer for *not* visiting reads as a fine and is the fastest way
 * to lose them. The cost rises with the streak, and so does the customer's
 * ability to pay it, because embers come from the visits that built it.
 */
export const repairStreak = onCall(
  async (request: CallableRequest<{ shopId?: string }>) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'You must be signed in.');

    const shopId = request.data?.shopId;
    if (!shopId || typeof shopId !== 'string') {
      throw new HttpsError('invalid-argument', 'shopId is required.');
    }

    const shopSnap = await db.collection('shops').doc(shopId).get();
    if (!shopSnap.exists) throw new HttpsError('not-found', 'Shop not found.');
    const shop = shopSnap.data() as Shop;
    const todayStr = toDateStringInTZ(new Date(), shop.timeZone || DEFAULT_TIME_ZONE);

    const sRef = db.collection('streaks').doc(streakId(uid, shopId));
    const uRef = db.collection('users').doc(uid);

    return db.runTransaction(async (tx) => {
      const [sSnap, uSnap] = await tx.getAll(sRef, uRef);
      if (!sSnap.exists) {
        throw new HttpsError('not-found', 'You have no streak at this shop.');
      }
      const streak = sSnap.data() as Streak;

      // Eligibility is decided here, never by the client: the same rule the app
      // uses to offer the repair has to gate the write.
      const eligibility = repairEligibility(streak, todayStr, shop.streakWindowDays);
      if (eligibility !== 'repairable') {
        throw new HttpsError(
          'failed-precondition',
          eligibility === 'not_broken'
            ? 'That streak is still alive — nothing to repair.'
            : eligibility === 'too_short'
              ? 'That streak is too short to repair. Just visit again to start a new one.'
              : 'That streak has been broken too long to repair.',
        );
      }

      const cost = repairCost(streak.currentStreakDays);
      const embers = (uSnap.data()?.embers as number) ?? 0;
      if (embers < cost) {
        throw new HttpsError(
          'failed-precondition',
          `This repair costs ${cost} embers and you have ${embers}. Check in to earn more.`,
        );
      }

      const repaired: Streak = { ...streak, ...applyRepair(streak, todayStr) };
      tx.set(sRef, repaired);
      tx.set(uRef, { embers: embers - cost }, { merge: true });

      return { streak: repaired, cost, embersRemaining: embers - cost };
    });
  },
);

/**
 * Redeem a voucher by its printed code — called by the shop owner, not the
 * customer.
 *
 * Redemption used to be customer self-serve: they tapped "mark as used" on
 * their own phone and the owner had no way to check the voucher was real,
 * unspent, or even theirs. Moving the act to the owner makes it verifiable, and
 * removes the customer's ability to burn a voucher by accident before staff are
 * ready.
 */
export const redeemVoucherByCode = onCall(
  async (request: CallableRequest<{ code?: string }>): Promise<Voucher> => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'You must be signed in.');

    const raw = request.data?.code;
    if (!raw || typeof raw !== 'string') {
      throw new HttpsError('invalid-argument', 'A voucher code is required.');
    }
    const code = raw.trim().toUpperCase();

    // Scoped to the caller's own shops, so an owner can never redeem against
    // someone else's voucher even with a valid-looking code.
    const matches = await db
      .collection('vouchers')
      .where('shopOwnerId', '==', uid)
      .where('code', '==', code)
      .get();

    if (matches.empty) {
      throw new HttpsError('not-found', 'No voucher with that code at your shop.');
    }

    const open = matches.docs.filter((d) => (d.data() as Voucher).isRedeemed !== true);
    if (open.length === 0) {
      throw new HttpsError('failed-precondition', 'That voucher has already been used.');
    }
    if (open.length > 1) {
      throw new HttpsError(
        'failed-precondition',
        'More than one voucher matches that code. Ask the customer to open it in their app.',
      );
    }
    const ref = open[0].ref;

    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const voucher = snap.data() as Voucher;

      if (voucher.isRedeemed) {
        throw new HttpsError('failed-precondition', 'That voucher has already been used.');
      }
      if (new Date(voucher.expiresAt).getTime() < Date.now()) {
        throw new HttpsError('failed-precondition', 'That voucher has expired.');
      }

      const redeemedAt = new Date().toISOString();
      tx.update(ref, { isRedeemed: true, redeemedAt });
      return { ...voucher, isRedeemed: true, redeemedAt };
    });
  },
);
