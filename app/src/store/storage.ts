import AsyncStorage from '@react-native-async-storage/async-storage';
import { User, Shop, Visit, Streak, Voucher, UserRole } from '../types';
import { MOCK_SHOPS, MOCK_USERS, MOCK_VISITS, MOCK_STREAKS, MOCK_VOUCHERS } from '../constants/mockData';

const KEYS = {
  users: '@eatstreak/users',
  shops: '@eatstreak/shops',
  visits: '@eatstreak/visits',
  streaks: '@eatstreak/streaks',
  vouchers: '@eatstreak/vouchers',
  currentUserId: '@eatstreak/currentUserId',
  currentRole: '@eatstreak/currentRole',
  initialized: '@eatstreak/initialized',
  onboarded: '@eatstreak/onboarded',
};

async function get<T>(key: string): Promise<T | null> {
  const val = await AsyncStorage.getItem(key);
  return val ? JSON.parse(val) : null;
}

async function set<T>(key: string, value: T): Promise<void> {
  await AsyncStorage.setItem(key, JSON.stringify(value));
}

export async function isOnboarded(): Promise<boolean> {
  const val = await AsyncStorage.getItem(KEYS.onboarded);
  return val === 'true';
}

export async function setOnboarded(): Promise<void> {
  await AsyncStorage.setItem(KEYS.onboarded, 'true');
}

export async function initializeIfNeeded(): Promise<void> {
  const initialized = await AsyncStorage.getItem(KEYS.initialized);
  if (initialized) return;
  await set(KEYS.users, MOCK_USERS);
  await set(KEYS.shops, MOCK_SHOPS);
  await set(KEYS.visits, MOCK_VISITS);
  await set(KEYS.streaks, MOCK_STREAKS);
  await set(KEYS.vouchers, MOCK_VOUCHERS);
  await set(KEYS.currentUserId, 'user_maya');
  await set(KEYS.currentRole, 'customer');
  await AsyncStorage.setItem(KEYS.initialized, 'true');
}

export async function resetAllData(): Promise<void> {
  await AsyncStorage.clear();
}

export async function getCurrentUserId(): Promise<string> {
  return (await get<string>(KEYS.currentUserId)) || 'user_maya';
}

export async function getCurrentRole(): Promise<UserRole> {
  return (await get<UserRole>(KEYS.currentRole)) || 'customer';
}

export async function setCurrentRole(role: UserRole): Promise<void> {
  await set(KEYS.currentRole, role);
  const userId = role === 'customer' ? 'user_maya' : 'user_nadia';
  await set(KEYS.currentUserId, userId);
}

export async function getUsers(): Promise<User[]> {
  return (await get<User[]>(KEYS.users)) || [];
}

export async function getUser(id: string): Promise<User | null> {
  const users = await getUsers();
  return users.find(u => u.id === id) || null;
}

export async function updateUser(user: User): Promise<void> {
  const users = await getUsers();
  const idx = users.findIndex(u => u.id === user.id);
  if (idx >= 0) users[idx] = user;
  else users.push(user);
  await set(KEYS.users, users);
}

export async function getShops(): Promise<Shop[]> {
  return (await get<Shop[]>(KEYS.shops)) || [];
}

export async function getShop(id: string): Promise<Shop | null> {
  const shops = await getShops();
  return shops.find(s => s.id === id) || null;
}

export async function updateShop(shop: Shop): Promise<void> {
  const shops = await getShops();
  const idx = shops.findIndex(s => s.id === shop.id);
  if (idx >= 0) shops[idx] = shop;
  else shops.push(shop);
  await set(KEYS.shops, shops);
}

export async function getVisits(): Promise<Visit[]> {
  return (await get<Visit[]>(KEYS.visits)) || [];
}

export async function getVisitsForUser(userId: string): Promise<Visit[]> {
  const visits = await getVisits();
  return visits.filter(v => v.userId === userId);
}

export async function getVisitsForShop(shopId: string): Promise<Visit[]> {
  const visits = await getVisits();
  return visits.filter(v => v.shopId === shopId);
}

export async function addVisit(visit: Visit): Promise<void> {
  const visits = await getVisits();
  visits.push(visit);
  await set(KEYS.visits, visits);
}

export async function getStreaks(): Promise<Streak[]> {
  return (await get<Streak[]>(KEYS.streaks)) || [];
}

export async function getStreaksForUser(userId: string): Promise<Streak[]> {
  const streaks = await getStreaks();
  return streaks.filter(s => s.userId === userId);
}

export async function getStreak(userId: string, shopId: string): Promise<Streak | null> {
  const streaks = await getStreaks();
  return streaks.find(s => s.userId === userId && s.shopId === shopId) || null;
}

export async function saveStreak(streak: Streak): Promise<void> {
  const streaks = await getStreaks();
  const idx = streaks.findIndex(s => s.id === streak.id);
  if (idx >= 0) streaks[idx] = streak;
  else streaks.push(streak);
  await set(KEYS.streaks, streaks);
}

export async function getVouchers(): Promise<Voucher[]> {
  return (await get<Voucher[]>(KEYS.vouchers)) || [];
}

export async function getVouchersForUser(userId: string): Promise<Voucher[]> {
  const vouchers = await getVouchers();
  return vouchers.filter(v => v.userId === userId);
}

export async function addVoucher(voucher: Voucher): Promise<void> {
  const vouchers = await getVouchers();
  vouchers.push(voucher);
  await set(KEYS.vouchers, vouchers);
}

export async function redeemVoucher(voucherId: string): Promise<void> {
  const vouchers = await getVouchers();
  const idx = vouchers.findIndex(v => v.id === voucherId);
  if (idx >= 0) {
    vouchers[idx].isRedeemed = true;
    vouchers[idx].redeemedAt = new Date().toISOString();
    await set(KEYS.vouchers, vouchers);
  }
}
