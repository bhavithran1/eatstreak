import 'package:eatstreak/data/models/enums.dart';
import 'package:eatstreak/data/models/voucher.dart';
import 'package:eatstreak/features/customer/show_voucher_screen.dart';
import 'package:eatstreak/features/owner/counter_code_screen.dart';
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
    Widget child,
  ) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeControllerProvider.overrideWith(_FailingStore.new),
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
  void stress(String label, Widget Function() build) {
    for (final entry in sizes.entries) {
      for (final scale in textScales) {
        testWidgets('$label fits on ${entry.key} at ${scale}x', (tester) async {
          await pumpAt(tester, entry.value, scale, build());

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
