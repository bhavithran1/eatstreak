import 'package:eatstreak/data/models/enums.dart';
import 'package:eatstreak/data/models/streak.dart';
import 'package:eatstreak/data/models/visit_result.dart';
import 'package:eatstreak/data/models/voucher.dart';
import 'package:eatstreak/domain/check_in_flow.dart';
import 'package:flutter_test/flutter_test.dart';

/// `runCheckIn` is the single place the in-app scanner and the deep-link route
/// agree on where a scan lands, so a wrong branch here sends a customer to the
/// wrong screen from *both* entry points at once. It was untested.
void main() {
  Streak streakWith({int days = 1, int visits = 1}) => Streak(
        id: 'u1_shop1',
        userId: 'u1',
        shopId: 'shop1',
        currentStreakDays: days,
        longestStreakDays: days,
        totalVisits: visits,
        lastVisitDate: '2026-03-01',
        streakStartDate: '2026-03-01',
        isStreakAlive: true,
      );

  Voucher voucherWith(String id) => Voucher(
        id: id,
        userId: 'u1',
        shopId: 'shop1',
        shopName: 'Nonna',
        shopEmoji: '',
        tierId: 't1',
        type: RewardType.streakDays,
        discountPercent: 10,
        tierLabel: 'Regular',
        earnedAt: '2026-03-01T00:00:00Z',
        expiresAt: '2026-03-31T23:59:59Z',
        isRedeemed: false,
        code: 'EAT-ABC123',
      );

  /// A stand-in for the repository's checkIn, recording what it was handed.
  ({Future<VisitResult> Function(String, {String? token}) fn, List<String?> tokens})
      recorder(VisitResult result) {
    final tokens = <String?>[];
    return (
      fn: (String shopId, {String? token}) async {
        tokens.add(token);
        return result;
      },
      tokens: tokens,
    );
  }

  test('success becomes CheckInRecorded carrying the streak figures', () async {
    final r = recorder(VisitResult(
      status: CheckInStatus.success,
      streak: streakWith(days: 5, visits: 12),
      newVouchers: [voucherWith('v1'), voucherWith('v2')],
    ));

    final outcome = await runCheckIn('shop1', r.fn, token: 'tok');

    expect(outcome, isA<CheckInRecorded>());
    final recorded = outcome as CheckInRecorded;
    expect(recorded.shopId, 'shop1');
    expect(recorded.streakDays, 5);
    expect(recorded.totalVisits, 12);
    expect(recorded.newVoucherCount, 2);
  });

  test('the day code is passed through to the backend', () async {
    final r = recorder(VisitResult(
      status: CheckInStatus.success,
      streak: streakWith(),
    ));

    await runCheckIn('shop1', r.fn, token: 'today-code');

    expect(r.tokens, ['today-code']);
  });

  // A check-in with no code must still reach the server, which is what turns it
  // into code_invalid — resolving it on the client would be a second, drifting
  // definition of a valid code.
  test('a missing code is still sent, not short-circuited', () async {
    final r = recorder(const VisitResult(status: CheckInStatus.codeInvalid));

    final outcome = await runCheckIn('shop1', r.fn);

    expect(r.tokens, [null]);
    expect(outcome, isA<CheckInCodeInvalid>());
  });

  test('already-visited toasts rather than navigating', () async {
    final r = recorder(const VisitResult(status: CheckInStatus.alreadyVisitedToday));

    final outcome = await runCheckIn('shop1', r.fn, token: 'tok');

    expect(outcome, isA<CheckInAlreadyToday>());
    expect((outcome as CheckInAlreadyToday).message, isNotEmpty);
  });

  test('an invalid code says to ask staff for a fresh one', () async {
    final r = recorder(const VisitResult(status: CheckInStatus.codeInvalid));

    final outcome = await runCheckIn('shop1', r.fn, token: 'stale');

    expect(outcome, isA<CheckInCodeInvalid>());
    expect((outcome as CheckInCodeInvalid).message, contains('staff'));
  });

  // The unknown-shop branch prefills the "suggest a shop" form, so it has to
  // carry the payload that was actually scanned rather than the shop id we
  // failed to resolve.
  test('an unknown shop carries the raw scanned payload', () async {
    final r = recorder(const VisitResult(status: CheckInStatus.shopNotFound));

    final outcome = await runCheckIn(
      'shop1',
      r.fn,
      token: 'tok',
      rawData: 'https://maps.example/place/42',
    );

    expect(outcome, isA<CheckInUnknownShop>());
    expect((outcome as CheckInUnknownShop).qrData, 'https://maps.example/place/42');
  });

  test('an unknown shop falls back to the shop id when there is no payload', () async {
    final r = recorder(const VisitResult(status: CheckInStatus.shopNotFound));

    final outcome = await runCheckIn('shop1', r.fn, token: 'tok');

    expect((outcome as CheckInUnknownShop).qrData, 'shop1');
  });

  // A success whose streak the backend omitted must not render as "0 days,
  // 0 visits" on the celebration screen.
  test('success without a streak falls back to 1 rather than 0', () async {
    final r = recorder(const VisitResult(status: CheckInStatus.success));

    final outcome = await runCheckIn('shop1', r.fn, token: 'tok');

    final recorded = outcome as CheckInRecorded;
    expect(recorded.streakDays, 1);
    expect(recorded.totalVisits, 1);
    expect(recorded.newVoucherCount, 0);
  });

  test('every status maps to an outcome — no unhandled branch', () async {
    for (final status in CheckInStatus.values) {
      final r = recorder(VisitResult(status: status, streak: streakWith()));
      expect(
        await runCheckIn('shop1', r.fn, token: 'tok'),
        isA<CheckInOutcome>(),
        reason: 'unmapped status: $status',
      );
    }
  });
}
