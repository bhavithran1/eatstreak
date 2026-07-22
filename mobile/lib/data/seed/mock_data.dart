/// Sample world for demo mode, ported from the Expo app's mockData.ts.
/// Nothing here is used when demo mode is off.
library;

import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/reward_tier.dart';
import '../models/shop.dart';
import '../models/streak.dart';
import '../models/user.dart';
import '../models/visit.dart';
import '../models/voucher.dart';

/// The single identity a demo session signs in as.
const demoUid = 'demo_user';

/// The shop handed to the demo user when they switch to the owner role. Chosen
/// so it doesn't overlap with the shops they have customer streaks at.
const demoOwnedShopId = 'shop_sweetrise';

List<RewardTier> _tiers(String shopId) => [
      RewardTier(id: '${shopId}_v5', shopId: shopId, type: RewardType.visitCount, threshold: 5, discountPercent: 10, label: 'Regular', description: '10% off your meal', emoji: '🥉'),
      RewardTier(id: '${shopId}_v10', shopId: shopId, type: RewardType.visitCount, threshold: 10, discountPercent: 20, label: 'Loyal Fan', description: '20% off your meal', emoji: '🥈'),
      RewardTier(id: '${shopId}_v20', shopId: shopId, type: RewardType.visitCount, threshold: 20, discountPercent: 30, label: 'VIP', description: '30% off your meal', emoji: '🥇'),
      RewardTier(id: '${shopId}_v50', shopId: shopId, type: RewardType.visitCount, threshold: 50, discountPercent: 50, label: 'Legend', description: '50% off your meal', emoji: '👑'),
      RewardTier(id: '${shopId}_s3', shopId: shopId, type: RewardType.streakDays, threshold: 3, discountPercent: 5, label: '3-Day Streak', description: '5% off next visit', emoji: '🔥'),
      RewardTier(id: '${shopId}_s7', shopId: shopId, type: RewardType.streakDays, threshold: 7, discountPercent: 15, label: '7-Day Streak', description: '15% off next visit', emoji: '🔥'),
      RewardTier(id: '${shopId}_s14', shopId: shopId, type: RewardType.streakDays, threshold: 14, discountPercent: 25, label: '14-Day Streak', description: '25% off next visit', emoji: '🔥'),
      RewardTier(id: '${shopId}_s30', shopId: shopId, type: RewardType.streakDays, threshold: 30, discountPercent: 40, label: '30-Day Streak', description: '40% off — legendary!', emoji: '💎'),
    ];

List<Shop> _baseShops() => [
      Shop(
        id: 'shop_nonna',
        name: "Nonna's Kitchen",
        ownerId: 'user_nadia',
        category: ShopCategory.bistro,
        emoji: '🍝',
        description: 'Authentic Italian comfort food made with love. Fresh pasta daily.',
        address: '42 Olive Lane, Downtown',
        rewardTiers: _tiers('shop_nonna'),
        streakWindowDays: 3,
        createdAt: '2025-01-15',
      ),
      Shop(
        id: 'shop_ramen',
        name: 'Ramen Bar 88',
        ownerId: 'user_owner2',
        category: ShopCategory.ramen,
        emoji: '🍜',
        description: 'Rich tonkotsu broth, handmade noodles. Open late.',
        address: '88 Noodle St, Eastside',
        rewardTiers: _tiers('shop_ramen'),
        streakWindowDays: 2,
        createdAt: '2025-02-01',
      ),
      Shop(
        id: 'shop_blueroast',
        name: 'Blue Roast Coffee',
        ownerId: 'user_owner3',
        category: ShopCategory.coffee,
        emoji: '☕',
        description: 'Single-origin pour-overs and seasonal espresso blends.',
        address: '7 Bean Ave, Midtown',
        rewardTiers: _tiers('shop_blueroast'),
        streakWindowDays: 3,
        createdAt: '2025-01-20',
      ),
      Shop(
        id: 'shop_masa',
        name: 'Masa Taqueria',
        ownerId: 'user_owner4',
        category: ShopCategory.mexican,
        emoji: '🌮',
        description: 'Street-style tacos, fresh salsas, and house-made horchata.',
        address: '15 Fiesta Blvd, Westside',
        rewardTiers: _tiers('shop_masa'),
        streakWindowDays: 4,
        createdAt: '2025-03-01',
      ),
      Shop(
        id: demoOwnedShopId,
        name: 'Sweet Rise Bakery',
        ownerId: 'user_owner5',
        category: ShopCategory.bakery,
        emoji: '🥐',
        description: 'Artisan pastries, sourdough bread, and weekend brunch specials.',
        address: '3 Flour Ct, Uptown',
        rewardTiers: _tiers(demoOwnedShopId),
        streakWindowDays: 3,
        createdAt: '2025-02-10',
      ),
    ];

/// Other customers at the demo user's own shop, so the owner screens have
/// something real to render.
const _regulars = [
  (id: 'demo_c1', name: 'Priya Raman', streak: 34, visits: 41, lastVisitDaysAgo: 0),
  (id: 'demo_c2', name: 'Tom Okafor', streak: 12, visits: 19, lastVisitDaysAgo: 1),
  (id: 'demo_c3', name: 'Lena Fischer', streak: 8, visits: 8, lastVisitDaysAgo: 1),
  (id: 'demo_c4', name: 'Jae-won Park', streak: 5, visits: 23, lastVisitDaysAgo: 2),
  (id: 'demo_c5', name: 'Sofia Marín', streak: 3, visits: 3, lastVisitDaysAgo: 0),
  (id: 'demo_c6', name: 'Ade Bakare', streak: 2, visits: 11, lastVisitDaysAgo: 9),
];

/// A complete demo world, ready to persist.
class DemoSeed {
  const DemoSeed({
    required this.users,
    required this.shops,
    required this.visits,
    required this.streaks,
    required this.vouchers,
  });

  final List<AppUser> users;
  final List<Shop> shops;
  final List<Visit> visits;
  final List<Streak> streaks;
  final List<Voucher> vouchers;
}

/// Build a fresh demo world.
///
/// [includeDemoUser] is false until onboarding runs: with no users/{demoUid}
/// document the app treats the session as not-yet-onboarded, so a fresh install
/// still walks through onboarding instead of jumping straight to home.
DemoSeed buildDemoSeed({required String userName, required bool includeDemoUser}) {
  final shops = _baseShops()
      .map((s) => s.id == demoOwnedShopId ? s.copyWith(ownerId: demoUid) : s)
      .toList();

  String? ownerOf(String shopId) {
    for (final s in shops) {
      if (s.id == shopId) return s.ownerId;
    }
    return null;
  }

  final demoUser = AppUser(
    id: demoUid,
    name: userName,
    email: 'you@eatstreak.demo',
    role: UserRole.customer,
    joinedAt: dateNDaysAgo(30),
  );

  final users = <AppUser>[
    if (includeDemoUser) demoUser,
    for (final r in _regulars)
      AppUser(
        id: r.id,
        name: r.name,
        email: '${r.id}@eatstreak.demo',
        role: UserRole.customer,
        joinedAt: dateNDaysAgo(60),
      ),
  ];

  // The demo user's own history. Streaks that would read as "already visited
  // today" are pulled back a day, so the first thing you can do is scan a code
  // and watch a streak tick up.
  final streaks = <Streak>[
    _streak('streak_nonna', 'shop_nonna', 12, ownerOf, userName),
    _streak('streak_ramen', 'shop_ramen', 7, ownerOf, userName),
    _streak('streak_blueroast', 'shop_blueroast', 21, ownerOf, userName),
    Streak(
      id: 'streak_masa',
      userId: demoUid,
      userName: userName,
      shopId: 'shop_masa',
      shopOwnerId: ownerOf('shop_masa'),
      currentStreakDays: 2,
      longestStreakDays: 2,
      totalVisits: 2,
      lastVisitDate: dateNDaysAgo(4),
      streakStartDate: dateNDaysAgo(5),
      isStreakAlive: false,
    ),
    for (final r in _regulars)
      Streak(
        id: 'streak_${r.id}_$demoOwnedShopId',
        userId: r.id,
        userName: r.name,
        shopId: demoOwnedShopId,
        shopOwnerId: demoUid,
        currentStreakDays: r.streak,
        longestStreakDays: r.streak,
        totalVisits: r.visits,
        lastVisitDate: dateNDaysAgo(r.lastVisitDaysAgo),
        streakStartDate: dateNDaysAgo(r.lastVisitDaysAgo + r.streak - 1),
        isStreakAlive: r.lastVisitDaysAgo <= 3,
      ),
  ];

  final visits = <Visit>[
    ..._generatedVisits('shop_nonna', 12, ownerOf, userName),
    ..._generatedVisits('shop_ramen', 7, ownerOf, userName),
    ..._generatedVisits('shop_blueroast', 21, ownerOf, userName),
    for (var i = 0; i < 2; i++)
      Visit(
        id: 'visit_masa_$i',
        userId: demoUid,
        userName: userName,
        shopId: 'shop_masa',
        shopOwnerId: ownerOf('shop_masa'),
        timestamp: '${dateNDaysAgo(5 - i)}T12:00:00Z',
      ),
    // Visit history at the owned shop, so the dashboard sparkline has a shape.
    for (final r in _regulars)
      for (var i = 0; i < r.visits; i++)
        if (r.lastVisitDaysAgo + i <= 29)
          Visit(
            id: 'visit_${r.id}_$i',
            userId: r.id,
            userName: r.name,
            shopId: demoOwnedShopId,
            shopOwnerId: demoUid,
            timestamp: '${dateNDaysAgo(r.lastVisitDaysAgo + i)}T12:00:00Z',
          ),
  ];

  final vouchers = <Voucher>[
    _voucher('shop_nonna', "Nonna's Kitchen", '🍝', 'v5', RewardType.visitCount, 10, 'Regular', 7, 23, false, ownerOf),
    _voucher('shop_nonna', "Nonna's Kitchen", '🍝', 'v10', RewardType.visitCount, 20, 'Loyal Fan', 2, 28, false, ownerOf),
    _voucher('shop_ramen', 'Ramen Bar 88', '🍜', 's7', RewardType.streakDays, 15, '7-Day Streak', 0, 30, false, ownerOf),
    _voucher('shop_blueroast', 'Blue Roast Coffee', '☕', 'v10', RewardType.visitCount, 20, 'Loyal Fan', 11, 19, true, ownerOf),
    _voucher('shop_blueroast', 'Blue Roast Coffee', '☕', 'v20', RewardType.visitCount, 30, 'VIP', 1, 29, false, ownerOf),
    _voucher('shop_blueroast', 'Blue Roast Coffee', '☕', 's14', RewardType.streakDays, 25, '14-Day Streak', 7, 23, false, ownerOf),
  ];

  return DemoSeed(
    users: users,
    shops: shops,
    visits: visits,
    streaks: streaks,
    vouchers: vouchers,
  );
}

/// An alive streak for the demo user. lastVisitDate is deliberately yesterday,
/// never today, so a check-in is always available to try.
Streak _streak(
  String id,
  String shopId,
  int days,
  String? Function(String) ownerOf,
  String userName,
) =>
    Streak(
      id: id,
      userId: demoUid,
      userName: userName,
      shopId: shopId,
      shopOwnerId: ownerOf(shopId),
      currentStreakDays: days,
      longestStreakDays: days,
      totalVisits: days,
      lastVisitDate: dateNDaysAgo(1),
      streakStartDate: dateNDaysAgo(days - 1),
      isStreakAlive: true,
    );

List<Visit> _generatedVisits(
  String shopId,
  int count,
  String? Function(String) ownerOf,
  String userName,
) =>
    [
      for (var i = count - 1; i >= 0; i--)
        Visit(
          id: 'visit_${shopId}_$i',
          userId: demoUid,
          userName: userName,
          shopId: shopId,
          shopOwnerId: ownerOf(shopId),
          timestamp: '${dateNDaysAgo(i)}T12:00:00Z',
        ),
    ];

Voucher _voucher(
  String shopId,
  String shopName,
  String shopEmoji,
  String tierSuffix,
  RewardType type,
  int discount,
  String label,
  int earnedDaysAgo,
  int expiresInDays,
  bool redeemed,
  String? Function(String) ownerOf,
) =>
    Voucher(
      id: 'voucher_${shopId}_$tierSuffix',
      userId: demoUid,
      shopId: shopId,
      shopOwnerId: ownerOf(shopId),
      shopName: shopName,
      shopEmoji: shopEmoji,
      tierId: '${shopId}_$tierSuffix',
      type: type,
      discountPercent: discount,
      tierLabel: label,
      earnedAt: '${dateNDaysAgo(earnedDaysAgo)}T12:00:00Z',
      expiresAt: '${addDays(todayString(), expiresInDays)}T23:59:59Z',
      isRedeemed: redeemed,
      redeemedAt: redeemed ? '${dateNDaysAgo(5)}T14:00:00Z' : null,
      code: generateVoucherCode(),
    );
