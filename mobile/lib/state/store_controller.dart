import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/check_in_token.dart';
import '../data/models/enums.dart';
import '../data/models/shop.dart';
import '../data/models/streak.dart';
import '../data/models/user.dart';
import '../data/models/visit.dart';
import '../data/models/visit_result.dart';
import '../data/models/voucher.dart';
import '../data/repositories/eatstreak_repository.dart';
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
      role == UserRole.owner ? _repo.getVisitsForOwner(uid) : _repo.getVisitsForUser(uid),
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

  /// Mint a single-use check-in code for the owner's shop to show at checkout.
  Future<CheckInToken> createCheckInToken(String shopId) =>
      _repo.createCheckInToken(shopId);

  /// Emits `true` once the owner's current code has been scanned.
  Stream<bool> watchCheckInTokenUsed(String token) =>
      _repo.watchCheckInTokenUsed(token);

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

      state = AsyncValue.data(
        current.copyWith(streaks: streaks, visits: visits, vouchers: vouchers),
      );
    }

    return result;
  }

  Future<void> redeemVoucher(String voucherId) async {
    final updated = await _repo.redeemVoucher(voucherId);
    final current = state.value ?? const StoreState();

    state = AsyncValue.data(
      current.copyWith(
        vouchers: [
          for (final v in current.vouchers) v.id == updated.id ? updated : v,
        ],
      ),
    );
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
