/// Date helpers ported from the Expo app's src/utils/dates.ts. Streak dates are
/// plain `yyyy-MM-dd` strings, deliberately — comparing calendar days, not
/// instants, is what makes "did they visit today" well-defined.
library;

import 'package:intl/intl.dart';

final _dayFormat = DateFormat('yyyy-MM-dd');

String toDateString(DateTime date) => _dayFormat.format(date);

String todayString() => toDateString(DateTime.now());

DateTime _parseDay(String dateStr) => DateTime.parse('${dateStr}T00:00:00');

/// Absolute whole-day distance between two `yyyy-MM-dd` strings.
int daysBetween(String a, String b) {
  final d1 = _parseDay(a);
  final d2 = _parseDay(b);
  return (d2.difference(d1).inHours / 24).round().abs();
}

bool isWithinWindow(String lastVisitDate, int windowDays) =>
    daysBetween(lastVisitDate, todayString()) <= windowDays;

int daysUntilExpiry(String lastVisitDate, int windowDays) {
  final remaining = windowDays - daysBetween(lastVisitDate, todayString());
  return remaining < 0 ? 0 : remaining;
}

String dateNDaysAgo(int n) => toDateString(DateTime.now().subtract(Duration(days: n)));

String addDays(String dateStr, int n) =>
    toDateString(_parseDay(dateStr).add(Duration(days: n)));

String getGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Mar 3, 2026" from an ISO instant or a `yyyy-MM-dd` string.
String formatDate(String iso) {
  final parsed = DateTime.tryParse(iso.contains('T') ? iso : '${iso}T00:00:00');
  if (parsed == null) return iso;
  return DateFormat('MMM d, y').format(parsed);
}

/// Whole days from now until [iso], rounded up. Negative once past.
int daysFromNow(String iso) {
  final target = DateTime.tryParse(iso.contains('T') ? iso : '${iso}T00:00:00');
  if (target == null) return 0;
  return target.difference(DateTime.now()).inHours ~/ 24 +
      (target.difference(DateTime.now()).inHours % 24 > 0 ? 1 : 0);
}
