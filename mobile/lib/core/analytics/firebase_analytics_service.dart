/// The Firebase implementation of [Analytics].
///
/// Deliberately separate from analytics.dart: that file is reachable from
/// state/providers.dart, and importing firebase_* there would link the SDK into
/// demo builds that never call Firebase.initializeApp. Only
/// bootstrap/firebase_bootstrap.dart imports this.
library;

import 'package:firebase_analytics/firebase_analytics.dart' as fa;
import 'package:flutter/foundation.dart';

import '../../data/models/enums.dart';
import 'analytics.dart';

/// Firebase Analytics.
///
/// Every call swallows its own errors. Analytics is never worth failing a
/// check-in for — if the SDK is misconfigured or offline, the visit still has
/// to be recorded and the customer still has to see their streak.
class FirebaseAnalyticsService implements Analytics {
  FirebaseAnalyticsService(this._analytics);

  final fa.FirebaseAnalytics _analytics;

  factory FirebaseAnalyticsService.instance() =>
      FirebaseAnalyticsService(fa.FirebaseAnalytics.instance);

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('analytics: $name failed: $e');
    }
  }

  @override
  Future<void> setUser(String? uid, {UserRole? role}) async {
    try {
      await _analytics.setUserId(id: uid);
      if (role != null) {
        // Lets every report be split by customer vs owner, which is the one
        // dimension that changes what a number means here.
        await _analytics.setUserProperty(name: 'role', value: role.wire);
      }
    } catch (e) {
      debugPrint('analytics: setUser failed: $e');
    }
  }

  @override
  Future<void> signedIn(String method) => _log('login', {'method': method});

  @override
  Future<void> onboarded(UserRole role) => _log('onboarded', {'role': role.wire});

  @override
  Future<void> checkedIn({required int streakDays, required int newVouchers}) =>
      _log('check_in', {'streak_days': streakDays, 'new_vouchers': newVouchers});

  @override
  Future<void> checkInFailed(String reason) => _log('check_in_failed', {'reason': reason});

  @override
  Future<void> streakRepaired({required int lostDays, required int cost}) =>
      _log('streak_repaired', {'lost_days': lostDays, 'ember_cost': cost});

  @override
  Future<void> voucherRedeemed({required int discountPercent}) =>
      _log('voucher_redeemed', {'discount_percent': discountPercent});

  @override
  Future<void> shopRegistered() => _log('shop_registered');

  @override
  Future<void> checkInCodeRotated() => _log('check_in_code_rotated');

  @override
  Object? get navigatorObserver => fa.FirebaseAnalyticsObserver(analytics: _analytics);
}
