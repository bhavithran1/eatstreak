import 'package:eatstreak/core/router/counter_shortcuts.dart';
import 'package:eatstreak/core/router/routes.dart';
import 'package:eatstreak/data/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Home-screen shortcuts are role-dependent, and the mapping is the part that
/// breaks silently: a wrong route sends someone to a screen the auth gate
/// bounces them out of, and the only symptom is a shortcut that "does nothing".
void main() {
  group('what each role is offered', () {
    test('a customer gets the camera, and nothing an owner would use', () {
      final types =
          CounterShortcuts.itemsFor(UserRole.customer).map((i) => i.type);

      expect(types, [CounterShortcuts.customerScan]);
    });

    test('an owner gets both counter jobs', () {
      final types =
          CounterShortcuts.itemsFor(UserRole.owner).map((i) => i.type);

      expect(types, [CounterShortcuts.ownerCode, CounterShortcuts.ownerRedeem]);
    });

    test('signed out, nothing is offered', () {
      // Every one of these routes redirects straight back to sign-in, so a
      // shortcut here is a button that looks broken.
      expect(CounterShortcuts.itemsFor(null), isEmpty);
    });

    test('every shortcut has a title a person can read', () {
      for (final role in [UserRole.customer, UserRole.owner]) {
        for (final item in CounterShortcuts.itemsFor(role)) {
          expect(item.localizedTitle, isNotEmpty, reason: item.type);
        }
      }
    });
  });

  group('where each shortcut goes', () {
    test('every offered shortcut resolves to a real route', () {
      for (final role in [UserRole.customer, UserRole.owner]) {
        for (final item in CounterShortcuts.itemsFor(role)) {
          expect(CounterShortcuts.routeFor(item.type), isNotNull,
              reason: '${item.type} is offered but goes nowhere');
        }
      }
    });

    test('the routes are the counter screens', () {
      expect(CounterShortcuts.routeFor(CounterShortcuts.customerScan),
          Routes.scanner);
      expect(CounterShortcuts.routeFor(CounterShortcuts.ownerCode),
          Routes.ownerQrCode);
      expect(CounterShortcuts.routeFor(CounterShortcuts.ownerRedeem),
          Routes.verifyVoucher);
    });

    test('an unknown type is ignored rather than guessed at', () {
      // Shortcut types outlive installs: iOS keeps them until the app rewrites
      // the list, so an old build's type can arrive at a new build.
      expect(CounterShortcuts.routeFor('legacy_thing'), isNull);
    });
  });
}
