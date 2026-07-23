import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics.dart';
import '../core/utils/dates.dart';
import '../data/models/check_in_token.dart';
import '../data/models/enums.dart';
import '../data/models/shop.dart';
import '../data/models/streak.dart';
import '../data/models/user.dart';
import '../data/models/visit.dart';
import '../data/models/visit_result.dart';
import '../data/models/voucher.dart';
import '../data/repositories/eatstreak_repository.dart';
import '../domain/streak_logic.dart';
import 'auth_controller.dart';
import 'providers.dart';

/// Everything the signed-in user is allowed to see, already scoped to their
/// role. The port of StoreProvider's AppState.
class StoreState {
  const StoreState({
    this.currentUser,
    this.shops = const [],
    this.streaks = const [],
    this.vouchers = const [],
    this.visits = const [],
  });

  final AppUser? currentUser;
  final List<Shop> shops;
  final List<Streak> streaks;
  final List<Voucher> vouchers;
  final List<Visit> visits;

  /// The shop this user owns, if they're an owner who has registered one.
  Shop? get ownedShop {
    final uid = currentUser?.id;
    if (uid == null) return null;
    for (final s in shops) {
      if (s.ownerId == uid) return s;
    }
    return null;
  }

  Shop? shopById(String id) {
    for (final s in shops) {
      if (s.id == id) return s;
    }
    return null;
  }

  Streak? streakForShop(String shopId) {
    for (final s in streaks) {
      if (s.shopId == shopId) return s;
    }
    return null;
  }

  StoreState copyWith({
    AppUser? currentUser,
    List<Shop>? shops,
    List<Streak>? streaks,
    List<Voucher>? vouchers,
    List<Visit>? visits,
  }) =>
      StoreState(
        currentUser: currentUser ?? this.currentUser,
        shops: shops ?? this.shops,
        streaks: streaks ?? this.streaks,
        vouchers: vouchers ?? this.vouchers,
        visits: visits ?? this.visits,
      );
}

/// Visits are only read to draw the dashboard's 30-day view, so that is all we
/// fetch. Reading every visit ever recorded would get slower and more expensive
/// for exactly the shops doing best.
String get _visitWindowStart => dateNDaysAgo(29);

class StoreController extends AsyncNotifier<StoreState> {
  EatStreakRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<StoreState> build() async {
    // Rebuilds whenever identity or role changes, which is exactly when the
    // scoped queries below would return something different.
    final auth = ref.watch(authControllerProvider);

    if (auth.initializing || !auth.isSignedIn || !auth.isOnboarded) {
      return const StoreState();
    }

    return _loadScoped(auth.uid!, auth.role!, auth.userDoc);
  }

  /// Read the collections this user may see. Owners query by shopOwnerId,
  /// customers by userId — the split mirrors the Firestore security rules.
  Future<StoreState> _loadScoped(String uid, UserRole role, AppUser? userDoc) async {
    final shops = await _repo.getShops();

    final results = await Future.wait([
      role == UserRole.owner
          ? _repo.getStreaksForOwner(uid)
          : _repo.getStreaksForUser(uid),
      role == UserRole.owner
          ? _repo.getVouchersForOwner(uid)
          : _repo.getVouchersForUser(uid),
      role == UserRole.owner
          ? _repo.getVisitsForOwner(uid, since: _visitWindowStart)
          : _repo.getVisitsForUser(uid, since: _visitWindowStart),
    ]);

    return StoreState(
      currentUser: userDoc,
      shops: shops,
      streaks: results[0] as List<Streak>,
      vouchers: results[1] as List<Voucher>,
      visits: results[2] as List<Visit>,
    );
  }

  Future<void> refresh() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isSignedIn || !auth.isOnboarded) return;

    state = await AsyncValue.guard(
      () => _loadScoped(auth.uid!, auth.role!, auth.userDoc),
    );
  }

  Analytics get _analytics => ref.read(analyticsProvider);

  /// Today's check-in code for the owner's shop. [rotate] issues a new one.
  Future<CheckInToken> createCheckInToken(String shopId, {bool rotate = false}) async {
    final token = await _repo.createCheckInToken(shopId, rotate: rotate);
    // Only the deliberate reset is worth counting — the idempotent daily fetch
    // fires every time the screen opens and would drown it.
    if (rotate) unawaited(_analytics.checkInCodeRotated());
    return token;
  }

  /// Record a check-in and fold the result into local state, so the success
  /// screen and home reflect it without a round trip.
  Future<VisitResult> checkIn(String shopId, {String? token}) async {
    final result = await _repo.checkIn(shopId, token: token);
    final streak = result.streak;

    if (result.isSuccess && streak != null) {
      final current = state.value ?? const StoreState();

      final streaks = [...current.streaks];
      final i = streaks.indexWhere((s) => s.id == streak.id);
      if (i >= 0) {
        streaks[i] = streak;
      } else {
        streaks.add(streak);
      }

      final visit = result.visit;
      final visits = visit != null && !current.visits.any((v) => v.id == visit.id)
          ? [...current.visits, visit]
          : current.visits;

      final known = current.vouchers.map((v) => v.id).toSet();
      final vouchers = [
        ...current.vouchers,
        ...result.newVouchers.where((v) => !known.contains(v.id)),
      ];

      // Mirror the ember the server just awarded. Without this the balance
      // stays a check-in behind, and a repair the customer can now afford is
      // still offered as "not enough embers".
      final user = current.currentUser;

      state = AsyncValue.data(
        current.copyWith(
          streaks: streaks,
          visits: visits,
          vouchers: vouchers,
          currentUser: user?.withEmbers(user.embers + embersPerCheckIn),
        ),
      );

      unawaited(_analytics.checkedIn(
        streakDays: streak.currentStreakDays,
        newVouchers: result.newVouchers.length,
      ));
    } else {
      // Logged here rather than in the scanner so the deep-link path is counted
      // too — a scan that opens the app from the camera never touches the
      // in-app scanner at all.
      unawaited(_analytics.checkInFailed(result.status.name));
    }

    return result;
  }

  /// Owner-confirmed redemption. The customer shows the code; the owner enters
  /// it. Returns the voucher so the owner can see what they just honoured.
  Future<Voucher> redeemVoucherByCode(String code) async {
    final updated = await _repo.redeemVoucherByCode(code);
    final current = state.value ?? const StoreState();

    final known = current.vouchers.any((v) => v.id == updated.id);
    state = AsyncValue.data(
      current.copyWith(
        vouchers: known
            ? [for (final v in current.vouchers) v.id == updated.id ? updated : v]
            : [...current.vouchers, updated],
      ),
    );
    unawaited(_analytics.voucherRedeemed(discountPercent: updated.discountPercent));
    return updated;
  }

  /// Spend embers to bring a broken streak back. The balance lives on the user
  /// document, so refresh it afterwards to reflect what was spent.
  Future<Streak> repairStreak(String shopId) async {
    // Read what the repair cost *before* it happens: the server spends the
    // embers and returns only the mended streak, and by the time it does the
    // break record has been cleared.
    final before = state.value?.streaks.where((s) => s.shopId == shopId).firstOrNull;
    final window = state.value?.shops
        .where((s) => s.id == shopId)
        .firstOrNull
        ?.streakWindowDays;

    final repaired = await _repo.repairStreak(shopId);
    final current = state.value ?? const StoreState();

    if (before != null && window != null) {
      final info = repairInfo(
        before.currentStreakDays,
        before.lastVisitDate,
        before.brokenStreakDays,
        before.brokenOn,
        todayString(),
        window,
      );
      unawaited(_analytics.streakRepaired(
        lostDays: info.lostStreakDays,
        cost: info.cost,
      ));
    }

    state = AsyncValue.data(
      current.copyWith(
        streaks: [
          for (final s in current.streaks) s.id == repaired.id ? repaired : s,
        ],
      ),
    );
    await ref.read(authControllerProvider.notifier).refreshUserDoc();
    return repaired;
  }

  Future<void> updateShop(Shop shop) async {
    await _repo.updateShop(shop);
    final current = state.value ?? const StoreState();

    state = AsyncValue.data(
      current.copyWith(
        shops: [for (final s in current.shops) s.id == shop.id ? shop : s],
      ),
    );
  }

  Future<void> registerShop(Shop shop) async {
    await _repo.addShop(shop);
    unawaited(_analytics.shopRegistered());
    final current = state.value ?? const StoreState();

    final exists = current.shops.any((s) => s.id == shop.id);
    state = AsyncValue.data(
      current.copyWith(
        shops: exists
            ? [for (final s in current.shops) s.id == shop.id ? shop : s]
            : [...current.shops, shop],
      ),
    );
  }

  Future<void> updateUser(AppUser user) async {
    await _repo.updateUser(user);
    await ref.read(authControllerProvider.notifier).refreshUserDoc();
  }

  /// Switch between the customer and owner views of the same account.
  Future<void> switchRole(UserRole role) async {
    final current = state.value?.currentUser;
    if (current == null) return;
    await updateUser(current.copyWith(role: role));
    // build() re-runs off the auth change and reloads scoped data.
  }

  Future<void> addShopSuggestion(String name, String qrData) async {
    final uid = ref.read(authControllerProvider).uid;
    if (uid == null) return;
    await _repo.addShopSuggestion(name: name, qrData: qrData, suggestedBy: uid);
  }

  /// With a shared backend there is no local data to wipe — sign out instead.
  Future<void> resetAll() => ref.read(authControllerProvider.notifier).signOut();
}

final storeControllerProvider =
    AsyncNotifierProvider<StoreController, StoreState>(StoreController.new);
