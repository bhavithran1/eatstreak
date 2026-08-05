import 'package:eatstreak/core/utils/dates.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors `functions/src/dates.test.ts`.
///
/// `daysBetween` is the other half of a ported pair, and the two disagreed on
/// unreadable input for as long as neither was tested on it: TypeScript
/// returned a NaN that compared false against every threshold — quietly
/// *preserving* a streak — while this side threw a FormatException out of
/// `build()` and took the owner dashboard with it.
///
/// `daysFromNow` is tested here because its sign decides whether a voucher is
/// offered to a customer at all, and it had the sign wrong on both sides of
/// zero.
void main() {
  group('daysBetween', () {
    test('same day is 0', () {
      expect(daysBetween('2026-03-01', '2026-03-01'), 0);
    });

    test('consecutive days is 1', () {
      expect(daysBetween('2026-03-01', '2026-03-02'), 1);
    });

    test('order does not matter', () {
      expect(daysBetween('2026-03-05', '2026-03-01'), 4);
    });

    test('across a month boundary', () {
      expect(daysBetween('2026-02-27', '2026-03-02'), 3);
    });

    test('across a leap day', () {
      expect(daysBetween('2028-02-28', '2028-03-01'), 2);
    });

    test('across a year boundary', () {
      expect(daysBetween('2025-12-31', '2026-01-01'), 1);
    });

    test('a full year', () {
      expect(daysBetween('2026-01-01', '2027-01-01'), 365);
    });
  });

  group('daysBetween on unreadable input', () {
    test('the parity constant is 99999 (must match UNKNOWN_DATE_DISTANCE_DAYS)', () {
      expect(unknownDateDistanceDays, 99999);
    });

    // Streak.fromJson defaults lastVisitDate to '', and the owner dashboard,
    // the customers list and streak_service all measure it with no empty check.
    // This used to throw, which is a red screen on the owner's home.
    test('an empty date does not throw', () {
      expect(daysBetween('', '2026-03-01'), unknownDateDistanceDays);
    });

    test('an empty second date does not throw', () {
      expect(daysBetween('2026-03-01', ''), unknownDateDistanceDays);
    });

    test('both empty does not throw', () {
      expect(daysBetween('', ''), unknownDateDistanceDays);
    });

    test('junk does not throw', () {
      expect(daysBetween('not-a-date', '2026-03-01'), unknownDateDistanceDays);
    });

    // The point of the sentinel: an unreadable last visit has to lapse a
    // streak, not preserve one.
    test('unknown exceeds any real streak window', () {
      expect(unknownDateDistanceDays, greaterThan(90));
    });
  });

  // Documents in the wild carry both shapes. The contract for an instant is
  // only that it is *read* rather than thrown away — comparing an instant to a
  // bare day mixes zones (this side parses a bare day in device-local time,
  // the TypeScript side in UTC), so the exact figure is not something either
  // side promises. Two bare days, the documented input, agree exactly.
  group('daysBetween on ISO instants', () {
    test('an ISO instant is accepted, not treated as unreadable', () {
      expect(
        daysBetween('2026-03-01T10:30:00Z', '2026-03-01'),
        isNot(unknownDateDistanceDays),
      );
    });

    test('an ISO instant on the same day is within a day of it', () {
      expect(daysBetween('2026-03-01T10:30:00Z', '2026-03-01'),
          lessThanOrEqualTo(1));
    });

    test('an instant a week out is a week away, zone skew aside', () {
      expect(daysBetween('2026-03-08T10:30:00Z', '2026-03-01'),
          inInclusiveRange(6, 8));
    });
  });

  group('addDays', () {
    test('adds within a month', () => expect(addDays('2026-03-01', 5), '2026-03-06'));
    test('crosses a month boundary', () => expect(addDays('2026-02-27', 3), '2026-03-02'));
    test('crosses a leap day', () => expect(addDays('2028-02-28', 2), '2028-03-01'));
    test('subtracts with a negative n', () => expect(addDays('2026-03-01', -1), '2026-02-28'));
    test('adding zero is identity', () => expect(addDays('2026-03-01', 0), '2026-03-01'));

    test('junk is returned unchanged rather than throwing', () {
      expect(addDays('not-a-date', 30), 'not-a-date');
    });

    test('an empty string is returned unchanged', () {
      expect(addDays('', 30), '');
    });
  });

  // The regression. `daysFromNow`'s sign is what `vouchers_screen`,
  // `home_screen` and `dashboard_screen` use to split active vouchers from
  // expired ones, and what `voucher_card` turns into "Expires today".
  //
  // The old implementation was `inHours ~/ 24 + (inHours % 24 > 0 ? 1 : 0)`.
  // Dart's `%` is non-negative for a positive divisor — `-5 % 24` is 19, not
  // -5 — so everything that had just expired gained a day and came back 1.
  group('daysFromNow', () {
    String hoursOut(int h) =>
        DateTime.now().add(Duration(hours: h)).toIso8601String();

    test('an hour in the future is 1 ("Expires today")', () {
      expect(daysFromNow(hoursOut(1)), 1);
    });

    test('five hours in the future is still 1', () {
      expect(daysFromNow(hoursOut(5)), 1);
    });

    test('25 hours out rounds up to 2 ("Expires tomorrow")', () {
      expect(daysFromNow(hoursOut(25)), 2);
    });

    test('48 hours out is 2', () {
      expect(daysFromNow(hoursOut(48)), 2);
    });

    // Each of these used to answer 1, putting an expired voucher in the Active
    // tab labelled "Expires today". The customer held it up and the counter
    // rejected it — the server checks the real timestamp.
    test('expired an hour ago is not positive', () {
      expect(daysFromNow(hoursOut(-1)), lessThanOrEqualTo(0));
    });

    test('expired five hours ago is not positive', () {
      expect(daysFromNow(hoursOut(-5)), lessThanOrEqualTo(0));
    });

    test('expired 23 hours ago is not positive', () {
      expect(daysFromNow(hoursOut(-23)), lessThanOrEqualTo(0));
    });

    test('expired two days ago is negative', () {
      expect(daysFromNow(hoursOut(-48)), lessThan(0));
    });

    // The sign is the contract every caller relies on, so state it directly.
    test('is positive exactly while the instant is in the future', () {
      for (final h in [-72, -48, -25, -23, -5, -1]) {
        expect(daysFromNow(hoursOut(h)), lessThanOrEqualTo(0),
            reason: 'expired ${-h}h ago must not read as active');
      }
      for (final h in [1, 5, 23, 25, 48, 72]) {
        expect(daysFromNow(hoursOut(h)), greaterThan(0),
            reason: '${h}h in the future must read as active');
      }
    });

    test('unparseable input is 0, not an exception', () {
      expect(daysFromNow(''), 0);
      expect(daysFromNow('not-a-date'), 0);
    });

    test('accepts a bare yyyy-MM-dd as well as an instant', () {
      final tomorrow = addDays(todayString(), 2);
      expect(daysFromNow(tomorrow), greaterThan(0));
    });
  });

  group('formatDate', () {
    test('formats a bare day', () => expect(formatDate('2026-03-03'), 'Mar 3, 2026'));
    test('formats an ISO instant', () {
      expect(formatDate('2026-03-03T10:00:00'), 'Mar 3, 2026');
    });
    test('returns junk unchanged rather than throwing', () {
      expect(formatDate('not-a-date'), 'not-a-date');
    });
    test('returns empty unchanged', () => expect(formatDate(''), ''));
  });

  group('isWithinWindow and daysUntilExpiry', () {
    test('today is within any window', () {
      expect(isWithinWindow(todayString(), 3), isTrue);
    });

    test('beyond the window is outside it', () {
      expect(isWithinWindow(dateNDaysAgo(5), 3), isFalse);
    });

    test('an unreadable last visit is outside the window, not inside', () {
      expect(isWithinWindow('', 3), isFalse);
    });

    test('daysUntilExpiry counts down and floors at 0', () {
      expect(daysUntilExpiry(todayString(), 3), 3);
      expect(daysUntilExpiry(dateNDaysAgo(1), 3), 2);
      expect(daysUntilExpiry(dateNDaysAgo(99), 3), 0);
    });

    test('daysUntilExpiry is 0 for an unreadable date, never negative', () {
      expect(daysUntilExpiry('', 3), 0);
    });
  });
}
