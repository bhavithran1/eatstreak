/// Product analytics.
///
/// The app shipped with no analytics SDK at all, which is why the Firebase
/// console showed no users: nothing was ever sending events. This is the whole
/// surface, kept deliberately small — a named method per thing worth counting,
/// rather than a generic `log(name, params)` that lets event names drift and
/// spelling mistakes go unnoticed.
///
/// Two implementations, chosen the same way the repository is: [NoopAnalytics]
/// in demo mode (there is no Firebase app to talk to), and
/// FirebaseAnalyticsService once the live backend is configured. The Firebase
/// one lives in its own file so this one imports no firebase_* package —
/// state/providers.dart depends on it, and a demo build must not link the SDK.
library;

import '../../data/models/enums.dart';

abstract interface class Analytics {
  /// Ties subsequent events to a signed-in account, and is what makes users
  /// appear in the console at all. Pass null on sign-out.
  Future<void> setUser(String? uid, {UserRole? role});

  /// Someone signed in. [method] is 'google' or 'apple'.
  Future<void> signedIn(String method);

  /// Onboarding finished and the account picked a side.
  Future<void> onboarded(UserRole role);

  /// A visit was recorded. The single most important event in the product —
  /// everything else is upstream or downstream of it.
  Future<void> checkedIn({required int streakDays, required int newVouchers});

  /// A check-in was refused. [reason] mirrors the server's status so the funnel
  /// shows *why* scans fail, not just that they do.
  Future<void> checkInFailed(String reason);

  /// A customer spent embers to bring a broken streak back.
  Future<void> streakRepaired({required int lostDays, required int cost});

  /// An owner honoured a voucher at the counter.
  Future<void> voucherRedeemed({required int discountPercent});

  /// An owner finished registering their shop.
  Future<void> shopRegistered();

  /// An owner asked for a fresh code because the day's code leaked.
  Future<void> checkInCodeRotated();

  /// Route observer for automatic screen_view events, or null when analytics
  /// is disabled.
  Object? get navigatorObserver;
}

/// Demo mode, and any build without Firebase. Does nothing, on purpose.
class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  Future<void> setUser(String? uid, {UserRole? role}) async {}
  @override
  Future<void> signedIn(String method) async {}
  @override
  Future<void> onboarded(UserRole role) async {}
  @override
  Future<void> checkedIn({required int streakDays, required int newVouchers}) async {}
  @override
  Future<void> checkInFailed(String reason) async {}
  @override
  Future<void> streakRepaired({required int lostDays, required int cost}) async {}
  @override
  Future<void> voucherRedeemed({required int discountPercent}) async {}
  @override
  Future<void> shopRegistered() async {}
  @override
  Future<void> checkInCodeRotated() async {}
  @override
  Object? get navigatorObserver => null;
}
