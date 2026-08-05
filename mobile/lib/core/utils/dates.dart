/// Date helpers ported from the Expo app's src/utils/dates.ts. Streak dates are
/// plain `yyyy-MM-dd` strings, deliberately — comparing calendar days, not
/// instants, is what makes "did they visit today" well-defined.
library;

import 'package:intl/intl.dart';

final _dayFormat = DateFormat('yyyy-MM-dd');

String toDateString(DateTime date) => _dayFormat.format(date);

String todayString() => toDateString(DateTime.now());

/// Distance reported for a date we cannot read.
///
/// Large on purpose, and never an exception: these helpers run on server data
/// inside `build()`, so throwing takes out a whole screen. `Streak.fromJson`
/// defaults `lastVisitDate` to `''`, and the owner dashboard, the customers
/// list and `streak_service` all measure it without an empty check — one
/// malformed document used to red-screen the owner's home.
///
/// The value has to read as "long ago" rather than "today": an unreadable last
/// visit means the streak lapses, which is the conservative answer. Returning 0
/// would keep a streak alive off a corrupt record.
///
/// Mirrored by `UNKNOWN_DATE_DISTANCE_DAYS` in `functions/src/dates.ts`, and
/// asserted literally on both sides — the two implementations used to disagree
/// here, Dart throwing where TypeScript returned a silent NaN.
const unknownDateDistanceDays = 99999;

/// Accepts both a `yyyy-MM-dd` day and a full ISO instant. Null when neither.
DateTime? _tryParseDay(String dateStr) =>
    DateTime.tryParse(dateStr.contains('T') ? dateStr : '${dateStr}T00:00:00');

/// Absolute whole-day distance between two `yyyy-MM-dd` strings.
/// [unknownDateDistanceDays] if either side is missing or unparseable.
int daysBetween(String a, String b) {
  final d1 = _tryParseDay(a);
  final d2 = _tryParseDay(b);
  if (d1 == null || d2 == null) return unknownDateDistanceDays;
  return (d2.difference(d1).inHours / 24).round().abs();
}

bool isWithinWindow(String lastVisitDate, int windowDays) =>
    daysBetween(lastVisitDate, todayString()) <= windowDays;

int daysUntilExpiry(String lastVisitDate, int windowDays) {
  final remaining = windowDays - daysBetween(lastVisitDate, todayString());
  return remaining < 0 ? 0 : remaining;
}

String dateNDaysAgo(int n) => toDateString(DateTime.now().subtract(Duration(days: n)));

/// Unparseable input is returned unchanged rather than throwing, for the same
/// reason as [daysBetween].
String addDays(String dateStr, int n) {
  final parsed = _tryParseDay(dateStr);
  if (parsed == null) return dateStr;
  return toDateString(parsed.add(Duration(days: n)));
}

String getGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Mar 3, 2026" from an ISO instant or a `yyyy-MM-dd` string.
String formatDate(String iso) {
  final parsed = _tryParseDay(iso);
  if (parsed == null) return iso;
  return DateFormat('MMM d, y').format(parsed);
}

/// Whole days from now until [iso], rounded up. `> 0` exactly while [iso] is
/// still in the future, so callers can use the sign as "not expired yet":
/// 1 is "expires today", 0 is "expired within the last day".
///
/// Rounded up from fractional days rather than assembled out of `inHours ~/ 24`
/// and `inHours % 24`. Dart's `%` returns a **non-negative** result for a
/// positive divisor, so `-5.hours % 24` is 19, not -5 — the old arithmetic
/// added a day to everything that had *just* expired and answered 1. A voucher
/// that lapsed overnight therefore sat in the Vouchers "Active" tab reading
/// "Expires today"; the customer held it up and the counter rejected it as
/// expired, because the server checks the real timestamp. The same slip pushed
/// a voucher with an hour left into "Expired", where it could not be shown at
/// all. Vouchers expire at 23:59:59Z — 07:59 local — so the wrong answer
/// landed every morning.
int daysFromNow(String iso) {
  final target = _tryParseDay(iso);
  if (target == null) return 0;
  final minutes = target.difference(DateTime.now()).inMinutes;
  return (minutes / (60 * 24)).ceil();
}
