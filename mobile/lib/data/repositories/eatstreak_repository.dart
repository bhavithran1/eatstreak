import '../models/check_in_token.dart';
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
  /// [since] is an inclusive `yyyy-MM-dd` lower bound. Visits are only ever
  /// read for the dashboard's rolling window, so an unbounded read would grow
  /// without limit for the shops that succeed most.
  Future<List<Visit>> getVisitsForUser(String userId, {String? since});
  Future<List<Visit>> getVisitsForOwner(String ownerId, {String? since});
  Future<List<Visit>> getVisitsForShop(String shopId);

  // ---- shop suggestions ----------------------------------------------------
  Future<void> addShopSuggestion({
    required String name,
    required String qrData,
    required String suggestedBy,
  });

  // ---- authoritative mutations ---------------------------------------------
  /// Today's check-in code for a shop the caller owns. Idempotent — the same
  /// code all day — so the owner's screen can just ask for it on open. Pass
  /// [rotate] to burn today's code and issue a new one if it leaks.
  Future<CheckInToken> createCheckInToken(String shopId, {bool rotate});

  /// Record a check-in for the signed-in user; runs streak + voucher logic.
  /// [token] is the day's code scanned from the owner's screen.
  Future<VisitResult> checkIn(String shopId, {String? token});

  /// Spend embers to bring a broken streak back. The server decides whether it
  /// is eligible and what it costs — the client only offers the button.
  Future<Streak> repairStreak(String shopId);

  /// Redeem a voucher by its printed code. Called by the *owner*: redemption is
  /// theirs to confirm, so the customer can neither fake nor accidentally burn
  /// a discount. Double-redeem is rejected.
  Future<Voucher> redeemVoucherByCode(String code);
}
