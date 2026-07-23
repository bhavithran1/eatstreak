// Shared domain types — mirror app/src/types/index.ts so the server and client
// agree on document shapes. Server docs add denormalized fields (shopOwnerId,
// userName) for rule-friendly owner queries and display.

export type UserRole = 'customer' | 'owner';

export interface RewardTier {
  id: string;
  shopId: string;
  type: 'visit_count' | 'streak_days';
  threshold: number;
  discountPercent: number;
  label: string;
  description: string;
  emoji: string;
}

export interface Shop {
  id: string;
  name: string;
  ownerId: string;
  category: string;
  emoji: string;
  description: string;
  address: string;
  rewardTiers: RewardTier[];
  streakWindowDays: number;
  createdAt: string;
  sourceQR?: string;
  planId?: string;
  timeZone?: string; // day-boundary timezone for streak math (default Asia/Kuala_Lumpur)
}

export interface Visit {
  id: string;
  userId: string;
  shopId: string;
  timestamp: string;
  shopOwnerId: string; // denormalized
  userName: string; // denormalized
}

export interface Streak {
  id: string;
  userId: string;
  shopId: string;
  currentStreakDays: number;
  longestStreakDays: number;
  totalVisits: number;
  lastVisitDate: string;
  streakStartDate: string;
  isStreakAlive: boolean;
  shopOwnerId: string; // denormalized
  userName: string; // denormalized
}

export interface Voucher {
  id: string;
  userId: string;
  shopId: string;
  shopName: string;
  shopEmoji: string;
  tierId: string;
  type: 'visit_count' | 'streak_days';
  discountPercent: number;
  tierLabel: string;
  earnedAt: string;
  expiresAt: string;
  isRedeemed: boolean;
  redeemedAt: string | null;
  code: string;
  shopOwnerId: string; // denormalized
}

export interface VisitResult {
  status: 'success' | 'already_visited_today' | 'shop_not_found' | 'code_invalid';
  streak?: Streak;
  visit?: Visit;
  newVouchers?: Voucher[];
  shop?: Shop;
}

// The check-in code for one shop on one day. `secret` is random, so the code
// can't be derived from the shop id; `date` is the shop-timezone calendar day,
// which is what makes yesterday's code useless today.
export interface CheckInTokenDoc {
  shopId: string;
  ownerId: string;
  date: string;
  secret: string;
  createdAt: string;
  expiresAt: string;
}
