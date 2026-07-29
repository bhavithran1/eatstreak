import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../data/models/enums.dart';
import 'routes.dart';

/// Home-screen shortcuts: long-press the app icon and land on the one screen
/// that matters, instead of opening the app and hunting for a tab.
///
/// Role-dependent, because the counter is two different jobs. A customer is
/// standing there with a phone they need the camera on; an owner needs their
/// code up, or a voucher honoured. Neither wants the other's shortcuts, so the
/// list is rewritten whenever the role changes rather than showing everything
/// to everyone.
///
/// Best-effort by design. These are a shortcut to a screen already reachable in
/// two taps, so a platform that refuses them, or a cold start that arrives
/// before the router will accept a route, costs nothing — the app opens
/// normally. Nothing here is allowed to be on the path to a first frame.
class CounterShortcuts {
  CounterShortcuts(this._router, {QuickActions? quickActions})
      : _quickActions = quickActions ?? const QuickActions();

  final GoRouter _router;
  final QuickActions _quickActions;

  static const customerScan = 'customer_scan';
  static const ownerCode = 'owner_code';
  static const ownerRedeem = 'owner_redeem';

  bool _initialized = false;
  UserRole? _applied;

  /// Where each shortcut goes. Public so a test can assert the mapping without
  /// a platform channel behind it — the wiring is the part worth checking.
  static String? routeFor(String type) => switch (type) {
        customerScan => Routes.scanner,
        ownerCode => Routes.ownerQrCode,
        ownerRedeem => Routes.verifyVoucher,
        _ => null,
      };

  static List<ShortcutItem> itemsFor(UserRole? role) => switch (role) {
        UserRole.customer => const [
            ShortcutItem(type: customerScan, localizedTitle: 'Scan'),
          ],
        UserRole.owner => const [
            ShortcutItem(type: ownerCode, localizedTitle: 'Show code'),
            ShortcutItem(type: ownerRedeem, localizedTitle: 'Redeem voucher'),
          ],
        // Signed out: the shortcuts would open screens the auth gate bounces
        // straight back out of.
        null => const [],
      };

  /// Rewrite the shortcut list for [role], and start listening for taps.
  Future<void> applyFor(UserRole? role) async {
    if (_initialized && _applied == role) return;
    _applied = role;

    try {
      if (!_initialized) {
        _initialized = true;
        await _quickActions.initialize(_handle);
      }
      await _quickActions.setShortcutItems(itemsFor(role));
    } catch (e) {
      // A shortcut that cannot be registered is not worth a broken launch.
      debugPrint('Quick actions unavailable: $e');
    }
  }

  void _handle(String type) {
    final route = routeFor(type);
    if (route == null) return;

    // `go` rather than `push`: a shortcut is a way into the app, not a step
    // deeper into wherever it happened to be left. The router's redirect still
    // has the last word — tapping "Scan" while signed out lands on sign-in,
    // which is correct.
    _router.go(route);
  }
}
