import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../../domain/streak_logic.dart';
import '../models/check_in_token.dart';
import '../models/enums.dart';
import '../models/shop.dart';
import '../models/streak.dart';
import '../models/user.dart';
import '../models/visit.dart';
import '../models/visit_result.dart';
import '../models/voucher.dart';
import '../seed/mock_data.dart';
import 'eatstreak_repository.dart';

/// On-device backend for demo mode: the whole repository surface backed by
/// SharedPreferences and seeded from mock_data.dart.
///
/// [checkIn] and [redeemVoucher] run client-side here — exactly what the real
/// backend refuses to allow. That's fine because nothing in demo mode is
/// trusted, but it's why this class must never be reachable with Env.demoMode
/// off.
class DemoRepository implements EatStreakRepository {
  DemoRepository();

  static const _storageKey = 'eatstreak.demo.v1';

  _DemoData? _cache;

  // ---- persistence ---------------------------------------------------------

  Future<_DemoData> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      return _cache = _DemoData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    final fresh = _DemoData.fromSeed(
      buildDemoSeed(userName: 'You', includeDemoUser: false),
    );
    await _save(fresh);
    return fresh;
  }

  Future<void> _save(_DemoData data) async {
    _cache = data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data.toJson()));
  }

  Future<void> _mutate(void Function(_DemoData data) change) async {
    final data = await _load();
    change(data);
    await _save(data);
  }

  /// Rebuild the world, naming the demo user. Called when onboarding finishes.
  Future<AppUser> seed(String userName) async {
    final data = _DemoData.fromSeed(
      buildDemoSeed(userName: userName, includeDemoUser: true),
    );
    await _save(data);
    return data.users.firstWhere((u) => u.id == demoUid);
  }

  Future<void> clear() async {
    _cache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ---- users ---------------------------------------------------------------

  @override
  Future<AppUser?> getUser(String id) async {
    final data = await _load();
    for (final u in data.users) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Future<void> updateUser(AppUser user) => _mutate((data) {
        final i = data.users.indexWhere((u) => u.id == user.id);
        if (i >= 0) {
          data.users[i] = user;
        } else {
          data.users.add(user);
        }
      });

  // ---- shops ---------------------------------------------------------------

  @override
  Future<List<Shop>> getShops() async => List.of((await _load()).shops);

  @override
  Future<Shop?> getShop(String id) async {
    final data = await _load();
    for (final s in data.shops) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<void> updateShop(Shop shop) => _mutate((data) {
        final i = data.shops.indexWhere((s) => s.id == shop.id);
        if (i >= 0) {
          data.shops[i] = shop;
        } else {
          data.shops.add(shop);
        }
      });

  @override
  Future<void> addShop(Shop shop) => updateShop(shop);

  @override
  Future<List<Shop>> getShopsByOwner(String ownerId) async =>
      (await _load()).shops.where((s) => s.ownerId == ownerId).toList();

  @override
  Future<Shop?> shopBySourceQr(String sourceQr) async {
    final data = await _load();
    for (final s in data.shops) {
      if (s.sourceQR == sourceQr) return s;
    }
    return null;
  }

  // ---- reads ---------------------------------------------------------------

  @override
  Future<List<Streak>> getStreaksForUser(String userId) async =>
      (await _load()).streaks.where((s) => s.userId == userId).toList();

  @override
  Future<List<Streak>> getStreaksForOwner(String ownerId) async =>
      (await _load()).streaks.where((s) => s.shopOwnerId == ownerId).toList();

  @override
  Future<Streak?> getStreak(String userId, String shopId) async {
    final data = await _load();
    for (final s in data.streaks) {
      if (s.userId == userId && s.shopId == shopId) return s;
    }
    return null;
  }

  @override
  Future<List<Voucher>> getVouchersForUser(String userId) async =>
      (await _load()).vouchers.where((v) => v.userId == userId).toList();

  @override
  Future<List<Voucher>> getVouchersForOwner(String ownerId) async =>
      (await _load()).vouchers.where((v) => v.shopOwnerId == ownerId).toList();

  @override
  Future<List<Visit>> getVisitsForUser(String userId, {String? since}) async =>
      (await _load())
          .visits
          .where((v) => v.userId == userId && _onOrAfter(v, since))
          .toList();

  @override
  Future<List<Visit>> getVisitsForOwner(String ownerId, {String? since}) async =>
      (await _load())
          .visits
          .where((v) => v.shopOwnerId == ownerId && _onOrAfter(v, since))
          .toList();

  static bool _onOrAfter(Visit v, String? since) =>
      since == null || v.timestamp.compareTo(since) >= 0;

  @override
  Future<List<Visit>> getVisitsForShop(String shopId) async =>
      (await _load()).visits.where((v) => v.shopId == shopId).toList();

  @override
  Future<void> addShopSuggestion({
    required String name,
    required String qrData,
    required String suggestedBy,
  }) =>
      _mutate((data) => data.suggestions.add({
            'name': name,
            'qrData': qrData,
            'suggestedBy': suggestedBy,
            'createdAt': DateTime.now().toIso8601String(),
          }));

  // ---- mutations that are server-side in the real backend -------------------

  @override
  Future<CheckInToken> createCheckInToken(String shopId, {bool rotate = false}) async {
    // No server in demo mode — a code derived from the day keeps the owner QR
    // screen stable across opens, and demo check-ins don't validate it.
    return CheckInToken(
      token: 'demo_${shopId}_${toDateString(DateTime.now())}',
      shopId: shopId,
      expiresAt: DateTime.now().add(const Duration(hours: 48)),
      ttlSeconds: 48 * 60 * 60,
    );
  }

  @override
  Future<VisitResult> checkIn(String shopId, {String? token}) async {
    final data = await _load();

    final shop = data.shops.where((s) => s.id == shopId).firstOrNull;
    if (shop == null) {
      return const VisitResult(status: CheckInStatus.shopNotFound);
    }

    final userName =
        data.users.where((u) => u.id == demoUid).firstOrNull?.name ?? 'Guest';
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final todayStr = toDateString(now);

    final existing =
        data.streaks.where((s) => s.userId == demoUid && s.shopId == shopId).firstOrNull;

    final computed = computeCheckIn(
      existing == null
          ? null
          : StreakCore(
              currentStreakDays: existing.currentStreakDays,
              longestStreakDays: existing.longestStreakDays,
              totalVisits: existing.totalVisits,
              lastVisitDate: existing.lastVisitDate,
              streakStartDate: existing.streakStartDate,
              isStreakAlive: existing.isStreakAlive,
            ),
      todayStr,
      shop.streakWindowDays,
    );

    final next = Streak(
      id: '${demoUid}_$shopId',
      userId: demoUid,
      userName: userName,
      shopId: shopId,
      shopOwnerId: shop.ownerId,
      currentStreakDays: computed.streak.currentStreakDays,
      longestStreakDays: computed.streak.longestStreakDays,
      totalVisits: computed.streak.totalVisits,
      lastVisitDate: computed.streak.lastVisitDate,
      streakStartDate: computed.streak.streakStartDate,
      isStreakAlive: computed.streak.isStreakAlive,
    );

    if (computed.status == CheckInStatus.alreadyVisitedToday) {
      return VisitResult(status: computed.status, streak: next, shop: shop);
    }

    final awarded = data.vouchers
        .where((v) => v.userId == demoUid)
        .map((v) => v.tierId)
        .toSet();

    final newVouchers = qualifyingTiers(computed.streak, shop.rewardTiers, awarded)
        .map((tier) => Voucher(
              id: '${demoUid}_${tier.id}',
              userId: demoUid,
              shopId: shop.id,
              shopOwnerId: shop.ownerId,
              shopName: shop.name,
              shopEmoji: shop.emoji,
              tierId: tier.id,
              type: tier.type,
              discountPercent: tier.discountPercent,
              tierLabel: tier.label,
              earnedAt: nowIso,
              expiresAt: '${addDays(todayStr, 30)}T23:59:59Z',
              isRedeemed: false,
              code: generateVoucherCode(),
            ))
        .toList();

    final visit = Visit(
      id: generateId(),
      userId: demoUid,
      userName: userName,
      shopId: shopId,
      shopOwnerId: shop.ownerId,
      timestamp: nowIso,
    );

    await _mutate((d) {
      final i = d.streaks.indexWhere((s) => s.userId == demoUid && s.shopId == shopId);
      if (i >= 0) {
        d.streaks[i] = next;
      } else {
        d.streaks.add(next);
      }
      d.visits.add(visit);
      d.vouchers.addAll(newVouchers);
    });

    return VisitResult(
      status: CheckInStatus.success,
      streak: next,
      visit: visit,
      newVouchers: newVouchers,
      shop: shop,
    );
  }

  @override
  Future<Voucher> redeemVoucher(String voucherId) async {
    final data = await _load();
    final voucher = data.vouchers.where((v) => v.id == voucherId).firstOrNull;

    if (voucher == null) {
      throw StateError('Voucher not found.');
    }
    if (voucher.isRedeemed) {
      throw StateError('This voucher has already been redeemed.');
    }

    final updated = voucher.copyWith(
      isRedeemed: true,
      redeemedAt: DateTime.now().toIso8601String(),
    );

    await _mutate((d) {
      final i = d.vouchers.indexWhere((v) => v.id == voucherId);
      if (i >= 0) d.vouchers[i] = updated;
    });

    return updated;
  }
}

/// The persisted demo world.
class _DemoData {
  _DemoData({
    required this.users,
    required this.shops,
    required this.visits,
    required this.streaks,
    required this.vouchers,
    required this.suggestions,
  });

  final List<AppUser> users;
  final List<Shop> shops;
  final List<Visit> visits;
  final List<Streak> streaks;
  final List<Voucher> vouchers;
  final List<Map<String, dynamic>> suggestions;

  factory _DemoData.fromSeed(DemoSeed seed) => _DemoData(
        users: List.of(seed.users),
        shops: List.of(seed.shops),
        visits: List.of(seed.visits),
        streaks: List.of(seed.streaks),
        vouchers: List.of(seed.vouchers),
        suggestions: [],
      );

  factory _DemoData.fromJson(Map<String, dynamic> json) => _DemoData(
        users: _list(json['users'], AppUser.fromJson),
        shops: _list(json['shops'], Shop.fromJson),
        visits: _list(json['visits'], Visit.fromJson),
        streaks: _list(json['streaks'], Streak.fromJson),
        vouchers: _list(json['vouchers'], Voucher.fromJson),
        suggestions: (json['suggestions'] as List<dynamic>? ?? const [])
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList(),
      );

  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
      (raw as List<dynamic>? ?? const [])
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();

  Map<String, dynamic> toJson() => {
        'users': users.map((u) => u.toJson()).toList(),
        'shops': shops.map((s) => s.toJson()).toList(),
        'visits': visits.map((v) => v.toJson()).toList(),
        'streaks': streaks.map((s) => s.toJson()).toList(),
        'vouchers': vouchers.map((v) => v.toJson()).toList(),
        'suggestions': suggestions,
      };
}
