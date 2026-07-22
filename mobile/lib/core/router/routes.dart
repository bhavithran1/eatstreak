/// Every route path in one place, so navigation calls never hand-write strings.
abstract final class Routes {
  static const splash = '/';
  static const signIn = '/sign-in';
  static const onboarding = '/onboarding';

  // Customer
  static const customerHome = '/home';
  static const scanner = '/scan';
  static const vouchers = '/vouchers';
  static const customerProfile = '/profile';
  static const scanSuccess = '/scan-success';
  static const shopNotFound = '/shop-not-found';
  static const shopDetailPattern = '/shop/:id';
  static String shopDetail(String id) => '/shop/$id';

  // Owner
  static const ownerDashboard = '/dashboard';
  static const ownerQrCode = '/qr-code';
  static const ownerRewards = '/rewards';
  static const ownerCustomers = '/customers';
  static const ownerProfile = '/owner-profile';

  // Shop setup
  static const registerShop = '/register-shop';
  static const choosePlan = '/choose-plan';

  /// Deep link target: `eatstreak://check-in/<shopId>` and `https://<host>/c/<id>`.
  static const checkIn = '/check-in/:shopId';
  static String checkInFor(String shopId) => '/check-in/$shopId';
}
