import { Streak, Shop, RewardTier, Voucher, VisitResult, Visit } from '../types';
import { toDateString, daysBetween, addDays } from '../utils/dates';
import { generateId, generateVoucherCode } from '../utils/formatters';
import * as storage from '../store/storage';
import type { StreakUrgency } from '../types';

export async function registerVisit(userId: string, shopId: string): Promise<VisitResult> {
  const shop = await storage.getShop(shopId);
  if (!shop) return { status: 'shop_not_found' };

  const now = new Date();
  const todayStr = toDateString(now);

  let streak = await storage.getStreak(userId, shopId);

  if (streak && streak.lastVisitDate === todayStr) {
    return { status: 'already_visited_today', streak, shop };
  }

  const visit: Visit = {
    id: generateId(),
    userId,
    shopId,
    timestamp: now.toISOString(),
  };
  await storage.addVisit(visit);

  if (!streak) {
    streak = {
      id: generateId(),
      userId,
      shopId,
      currentStreakDays: 1,
      longestStreakDays: 1,
      totalVisits: 1,
      lastVisitDate: todayStr,
      streakStartDate: todayStr,
      isStreakAlive: true,
    };
  } else {
    streak.totalVisits += 1;

    if (!streak.lastVisitDate) {
      streak.currentStreakDays = 1;
      streak.streakStartDate = todayStr;
    } else {
      const daysSince = daysBetween(streak.lastVisitDate, todayStr);
      if (daysSince <= shop.streakWindowDays) {
        streak.currentStreakDays += 1;
      } else {
        streak.currentStreakDays = 1;
        streak.streakStartDate = todayStr;
      }
    }

    streak.lastVisitDate = todayStr;
    streak.longestStreakDays = Math.max(streak.longestStreakDays, streak.currentStreakDays);
    streak.isStreakAlive = true;
  }

  const newVouchers = await checkAndAwardVouchers(userId, streak, shop);
  await storage.saveStreak(streak);

  return { status: 'success', streak, newVouchers, shop };
}

async function checkAndAwardVouchers(userId: string, streak: Streak, shop: Shop): Promise<Voucher[]> {
  const existing = await storage.getVouchersForUser(userId);
  const newVouchers: Voucher[] = [];

  for (const tier of shop.rewardTiers) {
    const value = tier.type === 'visit_count' ? streak.totalVisits : streak.currentStreakDays;
    if (value < tier.threshold) continue;

    const alreadyAwarded = existing.some(v => v.tierId === tier.id);
    if (alreadyAwarded) continue;

    const voucher: Voucher = {
      id: generateId(),
      userId,
      shopId: shop.id,
      shopName: shop.name,
      shopEmoji: shop.emoji,
      tierId: tier.id,
      type: tier.type,
      discountPercent: tier.discountPercent,
      tierLabel: tier.label,
      earnedAt: new Date().toISOString(),
      expiresAt: addDays(toDateString(new Date()), 30) + 'T23:59:59Z',
      isRedeemed: false,
      redeemedAt: null,
      code: generateVoucherCode(),
    };
    await storage.addVoucher(voucher);
    newVouchers.push(voucher);
  }

  return newVouchers;
}

export function getStreakUrgency(streak: Streak, shop: Shop): StreakUrgency {
  if (!streak.isStreakAlive) return 'dead';
  const todayStr = toDateString(new Date());
  const daysSince = daysBetween(streak.lastVisitDate, todayStr);
  if (daysSince === 0) return 'safe';
  if (daysSince < shop.streakWindowDays) return 'warning';
  if (daysSince === shop.streakWindowDays) return 'critical';
  return 'dead';
}

export function refreshStreakAlive(streak: Streak, shop: Shop): Streak {
  const todayStr = toDateString(new Date());
  const daysSince = daysBetween(streak.lastVisitDate, todayStr);
  return {
    ...streak,
    isStreakAlive: daysSince <= shop.streakWindowDays,
  };
}

export function getBestDiscount(streak: Streak, shop: Shop, type: 'visit_count' | 'streak_days'): number {
  const value = type === 'visit_count' ? streak.totalVisits : streak.currentStreakDays;
  let best = 0;
  for (const tier of shop.rewardTiers) {
    if (tier.type === type && value >= tier.threshold && tier.discountPercent > best) {
      best = tier.discountPercent;
    }
  }
  return best;
}

export function getNextMilestone(streak: Streak, shop: Shop, type: 'visit_count' | 'streak_days'): RewardTier | null {
  const value = type === 'visit_count' ? streak.totalVisits : streak.currentStreakDays;
  const tiersOfType = shop.rewardTiers
    .filter(t => t.type === type)
    .sort((a, b) => a.threshold - b.threshold);
  return tiersOfType.find(t => t.threshold > value) || null;
}
