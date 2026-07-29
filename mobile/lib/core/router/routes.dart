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

  /// The voucher held up at the counter for staff to scan. Takes the voucher
  /// itself as `extra` rather than an id in the path: it is only ever opened
  /// from a card the customer is already looking at, and a link into someone's
  /// discount is not a thing worth existing.
  static const showVoucher = '/voucher';
  static const scanSuccess = '/scan-success';
  static const shopNotFound = '/shop-not-found';
  static const shopDetailPattern = '/shop/:id';
  static String shopDetail(String id) => '/shop/$id';

  // Owner
  static const ownerDashboard = '/dashboard';
  static const ownerQrCode = '/qr-code';

  /// Today's code full-screen, for propping on the counter or printing.
  static const counterCode = '/counter-code';
  static const ownerRewards = '/rewards';
  static const ownerCustomers = '/customers';
  static const ownerProfile = '/owner-profile';

  // Shop setup
  static const registerShop = '/register-shop';
  static const choosePlan = '/choose-plan';
  static const editShop = '/edit-shop';
  static const verifyVoucher = '/verify-voucher';

  /// Debug-only: open the scanner as though [raw] had just come off the camera.
  /// Reached from `eatstreak://scan?data=<raw>`, which is how the end-to-end
  /// harness drives a scan on a simulator that has no camera. Release builds
  /// ignore the parameter entirely — see app_router.dart.
  static String scannerInject(String raw) =>
      '$scanner?inject=${Uri.encodeComponent(raw)}';

  /// Deep link target: `eatstreak://check-in/<shopId>` and `https://<host>/c/<id>`.
  static const checkIn = '/check-in/:shopId';
  static String checkInFor(String shopId, {String? token}) {
    final path = '/check-in/${Uri.encodeComponent(shopId)}';
    return token == null || token.isEmpty
        ? path
        : '$path?t=${Uri.encodeComponent(token)}';
  }
}
