export type UserRole = 'customer' | 'owner';

export type ShopCategory = 'coffee' | 'ramen' | 'pizza' | 'bistro' | 'bakery' | 'smoothie' | 'brunch' | 'mexican';

export interface User {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  joinedAt: string;
}

export interface Shop {
  id: string;
  name: string;
  ownerId: string;
  category: ShopCategory;
  emoji: string;
  description: string;
  address: string;
  rewardTiers: RewardTier[];
  streakWindowDays: number;
  createdAt: string;
}

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

export interface Visit {
  id: string;
  userId: string;
  shopId: string;
  timestamp: string;
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
}

export interface QRPayload {
  s: string;
  v: number;
}

export type StreakUrgency = 'safe' | 'warning' | 'critical' | 'dead';

export interface VisitResult {
  status: 'success' | 'already_visited_today' | 'shop_not_found';
  streak?: Streak;
  newVouchers?: Voucher[];
  shop?: Shop;
}
