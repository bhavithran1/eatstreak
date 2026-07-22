import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { randomBytes } from 'crypto';

import { Shop, Streak, Visit, Voucher, VisitResult, CheckInTokenDoc } from './types';
import { toDateStringInTZ, DEFAULT_TIME_ZONE, addDays } from './dates';
import { computeCheckIn, qualifyingTiers, generateVoucherCode, StreakCore } from './streakLogic';
import { CHECK_IN_TOKEN_TTL_SECONDS, newCheckInTokenDoc, isCheckInTokenValid } from './checkInToken';

admin.initializeApp();
const db = admin.firestore();

// Singapore region — lowest latency for Malaysian users.
setGlobalOptions({ region: 'asia-southeast1', maxInstances: 10 });

const streakId = (uid: string, shopId: string) => `${uid}_${shopId}`;
const voucherId = (uid: string, tierId: string) => `${uid}_${tierId}`;

/**
 * Mint a single-use check-in code for a shop the caller owns. The owner's
 * device shows this at checkout; `checkIn` consumes it, so a screenshot can't
 * be replayed and a saved code can't be scanned from home.
 */
export const createCheckInToken = onCall(
  async (request: CallableRequest<{ shopId?: string }>) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'You must be signed in.');

    const shopId = request.data?.shopId;
    if (!shopId || typeof shopId !== 'string') {
      throw new HttpsError('invalid-argument', 'shopId is required.');
    }

    const shopSnap = await db.collection('shops').doc(shopId).get();
    if (!shopSnap.exists) throw new HttpsError('not-found', 'Shop not found.');
    if ((shopSnap.data() as Shop).ownerId !== uid) {
      throw new HttpsError('permission-denied', 'Only the shop owner can create a check-in code.');
    }

    const token = randomBytes(18).toString('base64url');
    const doc = newCheckInTokenDoc(shopId, uid, new Date());
    await db.collection('checkInTokens').doc(token).set({
      ...doc,
      // Timestamp mirror of expiresAt, read only by the Firestore TTL policy so
      // spent/expired codes auto-delete. The validity logic uses the string
      // `expiresAt`; single-use still holds even if a doc is cleaned up early,
      // because an absent token reads as invalid.
      ttlAt: admin.firestore.Timestamp.fromDate(new Date(doc.expiresAt)),
    });

    return {
      token,
      shopId,
      expiresAt: doc.expiresAt,
      ttlSeconds: CHECK_IN_TOKEN_TTL_SECONDS,
    };
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

  // Every check-in must carry a single-use code the owner minted at checkout.
  // A bare shop link, a stale QR, or a screenshot has no valid code, so it
  // resolves to `code_invalid` rather than logging a visit.
  const token = request.data?.token;
  if (!token || typeof token !== 'string') {
    return { status: 'code_invalid' };
  }
  const tokenRef = db.collection('checkInTokens').doc(token);

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

  const sRef = db.collection('streaks').doc(streakId(uid, shopId));

  const result = await db.runTransaction(async (tx) => {
    // Reads first (Firestore requires all reads before any write). Validate the
    // single-use code and consume it in the same transaction, so two concurrent
    // scans of one code can't both succeed.
    const tokenSnap = await tx.get(tokenRef);
    const sSnap = await tx.get(sRef);

    const tokenData = tokenSnap.exists ? (tokenSnap.data() as CheckInTokenDoc) : null;
    if (!isCheckInTokenValid(tokenData, shopId, Date.now())) {
      return {
        status: 'code_invalid' as const,
        streak: undefined as Streak | undefined,
        newVouchers: [] as Voucher[],
        visit: undefined as Visit | undefined,
      };
    }
    const consumeToken = () =>
      tx.update(tokenRef, { used: true, usedBy: uid, usedAt: nowIso });

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
      // Still consume the code — it was a real, present scan, just a repeat
      // today. Leaving it unused would let someone else reuse the same code.
      consumeToken();
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
    consumeToken();
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
 * Redeem a voucher. Server-side so redemption can't be faked and double-redeem
 * is impossible (transactional check of isRedeemed).
 */
export const redeemVoucher = onCall(async (request: CallableRequest<{ voucherId?: string }>): Promise<Voucher> => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'You must be signed in.');

  const id = request.data?.voucherId;
  if (!id || typeof id !== 'string') {
    throw new HttpsError('invalid-argument', 'voucherId is required.');
  }

  const ref = db.collection('vouchers').doc(id);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Voucher does not exist.');
    const voucher = snap.data() as Voucher;

    if (voucher.userId !== uid) {
      throw new HttpsError('permission-denied', 'This voucher is not yours.');
    }
    if (voucher.isRedeemed) {
      throw new HttpsError('failed-precondition', 'This voucher was already redeemed.');
    }

    const redeemedAt = new Date().toISOString();
    tx.update(ref, { isRedeemed: true, redeemedAt });
    return { ...voucher, isRedeemed: true, redeemedAt };
  });
});
