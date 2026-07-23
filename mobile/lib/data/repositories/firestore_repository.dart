import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/config/env.dart';
import '../models/check_in_token.dart';
import '../models/shop.dart';
import '../models/streak.dart';
import '../models/user.dart';
import '../models/visit.dart';
import '../models/visit_result.dart';
import '../models/voucher.dart';
import 'eatstreak_repository.dart';

/// Cloud Firestore + callable Cloud Functions.
///
/// Streaks, visits and vouchers are read here but never written: those come
/// from the `checkIn` / `redeemVoucher` callables, because Firestore rules deny
/// direct client writes to them. Anything else would let a customer mint their
/// own discounts.
class FirestoreRepository implements EatStreakRepository {
  FirestoreRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: Env.functionsRegion);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _shops => _db.collection('shops');
  CollectionReference<Map<String, dynamic>> get _streaks => _db.collection('streaks');
  CollectionReference<Map<String, dynamic>> get _vouchers => _db.collection('vouchers');
  CollectionReference<Map<String, dynamic>> get _visits => _db.collection('visits');
  CollectionReference<Map<String, dynamic>> get _suggestions =>
      _db.collection('shopSuggestions');

  static List<T> _map<T>(
    QuerySnapshot<Map<String, dynamic>> snap,
    T Function(Map<String, dynamic>) parse,
  ) =>
      snap.docs.map((d) => parse(d.data())).toList();

  // ---- users ---------------------------------------------------------------

  @override
  Future<AppUser?> getUser(String id) async {
    final snap = await _users.doc(id).get();
    final data = snap.data();
    return data == null ? null : AppUser.fromJson(data);
  }

  @override
  Future<void> updateUser(AppUser user) =>
      // `embers` is server-owned: Cloud Functions increment it on check-in and
      // spend it on streak repairs. Writing the client's copy back would race
      // with those increments, and the security rules reject it outright.
      _users.doc(user.id).set(
            user.toJson()..remove('embers'),
            SetOptions(merge: true),
          );

  // ---- shops ---------------------------------------------------------------

  @override
  Future<List<Shop>> getShops() async => _map(await _shops.get(), Shop.fromJson);

  @override
  Future<Shop?> getShop(String id) async {
    final snap = await _shops.doc(id).get();
    final data = snap.data();
    return data == null ? null : Shop.fromJson(data);
  }

  @override
  Future<void> updateShop(Shop shop) =>
      _shops.doc(shop.id).set(shop.toJson(), SetOptions(merge: true));

  @override
  Future<void> addShop(Shop shop) => _shops.doc(shop.id).set(shop.toJson());

  @override
  Future<List<Shop>> getShopsByOwner(String ownerId) async =>
      _map(await _shops.where('ownerId', isEqualTo: ownerId).get(), Shop.fromJson);

  @override
  Future<Shop?> shopBySourceQr(String sourceQr) async {
    final snap = await _shops.where('sourceQR', isEqualTo: sourceQr).limit(1).get();
    return snap.docs.isEmpty ? null : Shop.fromJson(snap.docs.first.data());
  }

  // ---- streaks (read-only) -------------------------------------------------

  @override
  Future<List<Streak>> getStreaksForUser(String userId) async =>
      _map(await _streaks.where('userId', isEqualTo: userId).get(), Streak.fromJson);

  @override
  Future<List<Streak>> getStreaksForOwner(String ownerId) async => _map(
        await _streaks.where('shopOwnerId', isEqualTo: ownerId).get(),
        Streak.fromJson,
      );

  @override
  Future<Streak?> getStreak(String userId, String shopId) async {
    final snap = await _streaks.doc('${userId}_$shopId').get();
    final data = snap.data();
    return data == null ? null : Streak.fromJson(data);
  }

  // ---- vouchers (read-only) ------------------------------------------------

  @override
  Future<List<Voucher>> getVouchersForUser(String userId) async =>
      _map(await _vouchers.where('userId', isEqualTo: userId).get(), Voucher.fromJson);

  @override
  Future<List<Voucher>> getVouchersForOwner(String ownerId) async => _map(
        await _vouchers.where('shopOwnerId', isEqualTo: ownerId).get(),
        Voucher.fromJson,
      );

  // ---- visits (read-only) --------------------------------------------------

  /// ISO-8601 timestamps sort lexicographically, so a `yyyy-MM-dd` string is a
  /// valid lower bound without storing a second field.
  Query<Map<String, dynamic>> _visitsSince(
    Query<Map<String, dynamic>> query,
    String? since,
  ) =>
      since == null
          ? query
          : query.where('timestamp', isGreaterThanOrEqualTo: since);

  @override
  Future<List<Visit>> getVisitsForUser(String userId, {String? since}) async =>
      _map(
        await _visitsSince(_visits.where('userId', isEqualTo: userId), since).get(),
        Visit.fromJson,
      );

  @override
  Future<List<Visit>> getVisitsForOwner(String ownerId, {String? since}) async =>
      _map(
        await _visitsSince(_visits.where('shopOwnerId', isEqualTo: ownerId), since)
            .get(),
        Visit.fromJson,
      );

  @override
  Future<List<Visit>> getVisitsForShop(String shopId) async =>
      _map(await _visits.where('shopId', isEqualTo: shopId).get(), Visit.fromJson);

  // ---- shop suggestions ----------------------------------------------------

  @override
  Future<void> addShopSuggestion({
    required String name,
    required String qrData,
    required String suggestedBy,
  }) =>
      _suggestions.add({
        'name': name,
        'qrData': qrData,
        'suggestedBy': suggestedBy,
        'createdAt': DateTime.now().toIso8601String(),
      });

  // ---- server-authoritative mutations --------------------------------------

  @override
  Future<CheckInToken> createCheckInToken(String shopId, {bool rotate = false}) async {
    final result = await _functions
        .httpsCallable('createCheckInToken')
        .call<Map<String, dynamic>>({'shopId': shopId, 'rotate': rotate});
    return CheckInToken.fromJson(Map<String, dynamic>.from(result.data));
  }

  @override
  Future<VisitResult> checkIn(String shopId, {String? token}) async {
    final result = await _functions.httpsCallable('checkIn').call<Map<String, dynamic>>({
      'shopId': shopId,
      if (token != null && token.isNotEmpty) 'token': token,
    });
    return VisitResult.fromJson(Map<String, dynamic>.from(result.data));
  }

  @override
  Future<Streak> repairStreak(String shopId) async {
    final result = await _functions
        .httpsCallable('repairStreak')
        .call<Map<String, dynamic>>({'shopId': shopId});
    final data = Map<String, dynamic>.from(result.data);
    return Streak.fromJson(Map<String, dynamic>.from(data['streak'] as Map));
  }

  @override
  Future<Voucher> redeemVoucherByCode(String code) async {
    final result = await _functions
        .httpsCallable('redeemVoucherByCode')
        .call<Map<String, dynamic>>({'code': code});
    return Voucher.fromJson(Map<String, dynamic>.from(result.data));
  }
}
