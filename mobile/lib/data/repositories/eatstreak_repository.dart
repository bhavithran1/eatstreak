import '../models/shop.dart';
import '../models/streak.dart';
import '../models/user.dart';
import '../models/visit.dart';
import '../models/visit_result.dart';
import '../models/voucher.dart';

/// The app's entire data surface. Two implementations:
///
///  - [DemoRepository]      on-device seeded data, no backend
///  - [FirestoreRepository] Cloud Firestore + callable Cloud Functions
///
/// Screens depend only on this, so switching backends is one provider override.
///
/// Note the asymmetry: streaks, visits and vouchers are readable but never
/// writable here. Those mutations happen inside [checkIn] / [redeemVoucher],
/// which the real backend runs server-side — Firestore rules deny direct client
/// writes, and that's the whole reason the interface is shaped this way.
abstract interface class EatStreakRepository {
  // ---- users ---------------------------------------------------------------
  Future<AppUser?> getUser(String id);
  Future<void> updateUser(AppUser user);

  // ---- shops ---------------------------------------------------------------
  Future<List<Shop>> getShops();
  Future<Shop?> getShop(String id);
  Future<void> updateShop(Shop shop);
  Future<void> addShop(Shop shop);
  Future<List<Shop>> getShopsByOwner(String ownerId);
  Future<Shop?> shopBySourceQr(String sourceQr);

  // ---- streaks (read-only) -------------------------------------------------
  Future<List<Streak>> getStreaksForUser(String userId);
  Future<List<Streak>> getStreaksForOwner(String ownerId);
  Future<Streak?> getStreak(String userId, String shopId);

  // ---- vouchers (read-only) ------------------------------------------------
  Future<List<Voucher>> getVouchersForUser(String userId);
  Future<List<Voucher>> getVouchersForOwner(String ownerId);

  // ---- visits (read-only) --------------------------------------------------
  Future<List<Visit>> getVisitsForUser(String userId);
  Future<List<Visit>> getVisitsForOwner(String ownerId);
  Future<List<Visit>> getVisitsForShop(String shopId);

  // ---- shop suggestions ----------------------------------------------------
  Future<void> addShopSuggestion({
    required String name,
    required String qrData,
    required String suggestedBy,
  });

  // ---- authoritative mutations ---------------------------------------------
  /// Record a check-in for the signed-in user; runs streak + voucher logic.
  Future<VisitResult> checkIn(String shopId);

  /// Redeem a voucher. Double-redeem is rejected.
  Future<Voucher> redeemVoucher(String voucherId);
}
