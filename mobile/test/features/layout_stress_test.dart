import 'package:eatstreak/core/utils/dates.dart';
import 'package:eatstreak/data/models/enums.dart';
import 'package:eatstreak/data/models/shop.dart';
import 'package:eatstreak/data/models/streak.dart';
import 'package:eatstreak/data/models/user.dart';
import 'package:eatstreak/data/models/visit.dart';
import 'package:eatstreak/data/models/voucher.dart';
import 'package:eatstreak/features/customer/show_voucher_screen.dart';
import 'package:eatstreak/features/owner/counter_code_screen.dart';
import 'package:eatstreak/features/owner/customers_screen.dart';
import 'package:eatstreak/features/owner/dashboard_screen.dart';
import 'package:eatstreak/features/shared/widgets/store_scope.dart';
import 'package:eatstreak/features/shared/widgets/voucher_card.dart';
import 'package:eatstreak/state/store_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Renders the counter screens at every size and text setting a real customer
/// might be holding, and fails on an overflow.
///
/// These two screens are the app pointed at somebody else's camera, and both
/// were built around fixed pixel sizes — a 320pt sheet inside 24pt of padding
/// left 7pt of clearance on the narrowest phone still sold, which is not a
/// margin so much as a coincidence. Eyeballing one simulator cannot catch that,
/// and the failure lands in front of a paying customer.
///
/// Overflow in Flutter is a painted error, not a thrown one; [tester.takeException]
/// is what turns it back into a failing test.
void main() {
  setUpAll(() => WakelockPlusPlatformInterface.instance = _FakeWakelock());

  /// Phones the app has to survive, narrowest first. The first is an iPhone SE
  /// (1st gen) — beyond what the app targets, deliberately: passing there means
  /// the layouts bend rather than break.
  const sizes = <String, Size>{
    'SE 1st gen (320)': Size(320, 568),
    'SE 3rd gen (375)': Size(375, 667),
    'iPhone 17 Pro (402)': Size(402, 874),
    'Pro Max (440)': Size(440, 956),
  };

  /// 1.0 is the default; 2.0 is roughly iOS's largest accessibility setting.
  const textScales = [1.0, 1.35, 2.0];

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    double textScale,
    Widget child, {
    StoreController Function()? store,
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeControllerProvider.overrideWith(store ?? _FailingStore.new),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Every combination of [sizes] and [textScales], each its own test so a
  /// failure names the phone and the setting it happened on.
  void stress(
    String label,
    Widget Function() build, {
    StoreController Function()? store,
  }) {
    for (final entry in sizes.entries) {
      for (final scale in textScales) {
        testWidgets('$label fits on ${entry.key} at ${scale}x', (tester) async {
          await pumpAt(
            tester,
            entry.value,
            scale,
            build(),
            store: store,
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  stress('the counter sheet', () => CounterCodeScreen(args: _args));
  stress('a voucher held up to staff', () => ShowVoucherScreen(voucher: _voucher));
  stress(
    'a voucher card',
    () => Scaffold(
      body: Center(
        child: VoucherCard(voucher: _voucher, onShow: () {}, onTap: () {}),
      ),
    ),
  );
  // The real failure screen, not a hand-built copy of it: what has to survive
  // large text is the frame StoreScope actually renders, Retry button included.
  stress('the store failure screen', () => StoreScope(builder: (_, _) => _unused));

  // The owner's two data-heavy screens, against a shop with real numbers in it.
  //
  // Neither was covered here before, and both were built the way the counter
  // sheet was: fixed pixel boxes around text an owner can enlarge. The segment
  // rows gave "Regulars (30+ days)" a 124pt box and its count a 24pt one, and
  // the three KPI tiles split the width of the narrowest phone three ways for a
  // numeral that grows with the text setting. A four-figure day would not fit
  // at any accessibility size.
  //
  // The numbers below are deliberately awkward: a long shop name, a four-digit
  // visit count, a three-digit customer count and a long customer name are all
  // things a real shop produces and a designer's sample data does not.
  stress(
    'the owner dashboard',
    DashboardScreen.new,
    store: _BusyShopStore.new,
  );
  stress(
    'the customers list',
    CustomersScreen.new,
    store: _BusyShopStore.new,
  );
}

/// A shop doing enough trade to stress every figure on the dashboard at once.
class _BusyShopStore extends StoreController {
  @override
  Future<StoreState> build() async => _busyShop();
}

StoreState _busyShop() {
  final today = todayString();
  final now = DateTime.now();

  return StoreState(
    currentUser: const AppUser(
      id: 'owner_1',
      name: 'Owner',
      email: 'owner@example.com',
      role: UserRole.owner,
      joinedAt: '2026-01-01',
    ),
    shops: [
      Shop(
        id: 'shop_a',
        // Owners type their own names, and this one is longer than the header.
        name: 'Sweet Rise Bakery & Coffee House (Bangsar South)',
        ownerId: 'owner_1',
        category: ShopCategory.bakery,
        emoji: '🥐',
        description: 'Artisan pastries and sourdough.',
        address: '3 Flour Ct, Uptown',
        rewardTiers: const [],
        streakWindowDays: 3,
        createdAt: '2026-08-01',
      ),
    ],
    // A four-digit day, to prove the KPI tile scales its numeral rather than
    // clipping it.
    visits: [
      for (var i = 0; i < 1200; i++)
        Visit(
          id: 'v$i',
          userId: 'u${i % 130}',
          shopId: 'shop_a',
          timestamp: DateTime(now.year, now.month, now.day, 12)
              .subtract(Duration(days: i % 21, minutes: i))
              .toUtc()
              .toIso8601String(),
        ),
    ],
    streaks: [
      for (var i = 0; i < 130; i++)
        Streak(
          id: 'u${i}_shop_a',
          userId: 'u$i',
          shopId: 'shop_a',
          currentStreakDays: i % 44,
          longestStreakDays: i % 44,
          totalVisits: i + 1,
          // Spread across active, at-risk and lapsed.
          lastVisitDate: addDays(today, -(i % 6)),
          streakStartDate: today,
          isStreakAlive: true,
          userName: i == 0
              ? 'Maria-Fernanda Villanueva-Castellanos'
              : 'Customer $i',
        ),
    ],
    vouchers: [
      for (var i = 0; i < 40; i++)
        Voucher(
          id: 'vo$i',
          userId: 'u$i',
          shopId: 'shop_a',
          shopName: 'Sweet Rise Bakery & Coffee House (Bangsar South)',
          shopEmoji: '🥐',
          tierId: 't${i % 4}',
          type: RewardType.visitCount,
          discountPercent: 10 + (i % 4) * 10,
          tierLabel: 'Regular',
          earnedAt: '2026-08-01T00:00:00.000Z',
          expiresAt: now.add(Duration(days: i % 12)).toUtc().toIso8601String(),
          isRedeemed: i % 3 == 0,
          code: 'EAT-ABC12$i',
        ),
    ],
  );
}

const _args = CounterCodeArgs(
  shopId: 'shop_sweetrise',
  // A long name on purpose: shop names are typed by owners, not designers.
  shopName: 'Sweet Rise Bakery & Coffee House',
  token: 'demo_token_2026-08-01',
);

final _voucher = Voucher(
  id: 'v1',
  userId: 'u1',
  shopId: 'shop_sweetrise',
  shopName: 'Sweet Rise Bakery & Coffee House',
  shopEmoji: '🥐',
  tierId: 't1',
  type: RewardType.streakDays,
  discountPercent: 25,
  tierLabel: 'Loyal Fan',
  earnedAt: '2026-07-01T00:00:00.000',
  expiresAt: '2099-01-01T00:00:00.000',
  isRedeemed: false,
  code: 'EAT-ABC123',
);

/// Never built: the store override always fails, so [StoreScope] renders its
/// error frame instead of calling the builder.
const _unused = SizedBox.shrink();

/// Fails the store load so the failure frame is what gets measured.
class _FailingStore extends StoreController {
  @override
  Future<StoreState> build() async =>
      throw StoreLoadException('visits', _Denied());
}

class _Denied implements Exception {
  String get code => 'permission-denied';
}

/// The counter screens hold the screen awake; there is no platform to do it on
/// in a test, and an unhandled MissingPluginException would fail every case for
/// a reason that has nothing to do with layout.
class _FakeWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}
