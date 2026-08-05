import 'dart:convert';

import 'package:eatstreak/core/utils/pending_check_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The parked check-in has to survive sign-in, onboarding and process death,
/// then be spent exactly once — this is the very first thing a brand-new
/// customer does, so both halves matter: losing it drops their first check-in,
/// and replaying it logs a visit they never made.
void main() {
  // SharedPreferences namespaces its mock store under `flutter.`.
  const storeKey = 'flutter.eatstreak.pendingCheckIn';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Park an entry with a chosen age, to reach the TTL without waiting.
  Future<void> parkAgedMinutes(String shopId, String? token, int minutesAgo) async {
    SharedPreferences.setMockInitialValues({
      storeKey: jsonEncode({
        'shopId': shopId,
        'token': ?token,
        'at': DateTime.now()
            .subtract(Duration(minutes: minutesAgo))
            .millisecondsSinceEpoch,
      }),
    });
  }

  test('nothing parked means nothing to consume', () async {
    expect(await consumePendingCheckIn(), isNull);
  });

  test('round-trips the shop and its day code', () async {
    await setPendingCheckIn('shop1', token: 'code123');

    final pending = await consumePendingCheckIn();

    expect(pending, isNotNull);
    expect(pending!.shopId, 'shop1');
    expect(pending.token, 'code123');
  });

  // Read-and-clear. A second read must not resurrect it, or a resumed
  // check-in replays every time the routing hub runs.
  test('is consumed exactly once', () async {
    await setPendingCheckIn('shop1', token: 'code123');

    expect(await consumePendingCheckIn(), isNotNull);
    expect(await consumePendingCheckIn(), isNull);
  });

  test('clear removes it without consuming', () async {
    await setPendingCheckIn('shop1', token: 'code123');

    await clearPendingCheckIn();

    expect(await consumePendingCheckIn(), isNull);
  });

  test('the newest park wins', () async {
    await setPendingCheckIn('shop1', token: 'a');
    await setPendingCheckIn('shop2', token: 'b');

    final pending = await consumePendingCheckIn();

    expect(pending!.shopId, 'shop2');
    expect(pending.token, 'b');
  });

  group('the token', () {
    // Parking without a code guarantees the resumed check-in fails, so the
    // absence has to be represented honestly rather than as an empty string.
    test('is null when none was given', () async {
      await setPendingCheckIn('shop1');
      expect((await consumePendingCheckIn())!.token, isNull);
    });

    test('an empty code is stored as absent, not as ""', () async {
      await setPendingCheckIn('shop1', token: '');
      expect((await consumePendingCheckIn())!.token, isNull);
    });

    test('a non-string code is ignored rather than crashing', () async {
      SharedPreferences.setMockInitialValues({
        storeKey: jsonEncode({
          'shopId': 'shop1',
          'token': 42,
          'at': DateTime.now().millisecondsSinceEpoch,
        }),
      });

      final pending = await consumePendingCheckIn();

      expect(pending!.shopId, 'shop1');
      expect(pending.token, isNull);
    });
  });

  group('the 30-minute TTL', () {
    // The customer is standing in the restaurant when they scan. A check-in
    // resumed hours later would log a visit they never made.
    test('a fresh park is still good', () async {
      await parkAgedMinutes('shop1', 'code', 1);
      expect(await consumePendingCheckIn(), isNotNull);
    });

    test('just inside the window is still good', () async {
      await parkAgedMinutes('shop1', 'code', 29);
      expect(await consumePendingCheckIn(), isNotNull);
    });

    test('past the window is dropped', () async {
      await parkAgedMinutes('shop1', 'code', 31);
      expect(await consumePendingCheckIn(), isNull);
    });

    test('hours later is dropped', () async {
      await parkAgedMinutes('shop1', 'code', 60 * 5);
      expect(await consumePendingCheckIn(), isNull);
    });

    test('an expired entry is cleared, not left to be retried', () async {
      await parkAgedMinutes('shop1', 'code', 31);

      await consumePendingCheckIn();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('eatstreak.pendingCheckIn'), isNull);
    });
  });

  group('malformed storage', () {
    test('junk is dropped rather than thrown', () async {
      SharedPreferences.setMockInitialValues({storeKey: 'not json at all'});
      expect(await consumePendingCheckIn(), isNull);
    });

    test('a missing shopId is dropped', () async {
      SharedPreferences.setMockInitialValues({
        storeKey: jsonEncode({'at': DateTime.now().millisecondsSinceEpoch}),
      });
      expect(await consumePendingCheckIn(), isNull);
    });

    test('a missing timestamp is dropped', () async {
      SharedPreferences.setMockInitialValues({
        storeKey: jsonEncode({'shopId': 'shop1'}),
      });
      expect(await consumePendingCheckIn(), isNull);
    });

    test('a non-string shopId is dropped', () async {
      SharedPreferences.setMockInitialValues({
        storeKey: jsonEncode({
          'shopId': 42,
          'at': DateTime.now().millisecondsSinceEpoch,
        }),
      });
      expect(await consumePendingCheckIn(), isNull);
    });

    // Valid JSON of the wrong shape used to escape as a TypeError rather than
    // returning null: `on FormatException` only ever caught bad *syntax*.
    test('a JSON array is dropped rather than thrown', () async {
      SharedPreferences.setMockInitialValues({storeKey: jsonEncode([1, 2, 3])});
      expect(await consumePendingCheckIn(), isNull);
    });

    test('a bare JSON number is dropped rather than thrown', () async {
      SharedPreferences.setMockInitialValues({storeKey: jsonEncode(42)});
      expect(await consumePendingCheckIn(), isNull);
    });

    test('a bare JSON string is dropped rather than thrown', () async {
      SharedPreferences.setMockInitialValues({storeKey: jsonEncode('nope')});
      expect(await consumePendingCheckIn(), isNull);
    });

    test('JSON null is dropped rather than thrown', () async {
      SharedPreferences.setMockInitialValues({storeKey: 'null'});
      expect(await consumePendingCheckIn(), isNull);
    });

    test('malformed storage is cleared so it cannot jam the slot', () async {
      SharedPreferences.setMockInitialValues({storeKey: 'not json at all'});

      await consumePendingCheckIn();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('eatstreak.pendingCheckIn'), isNull);
    });
  });
}
