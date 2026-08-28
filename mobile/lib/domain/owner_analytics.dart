/// Everything the owner dashboard reports, computed in one pass over the data
/// the store already holds.
///
/// This lives here rather than inside `dashboard_screen.build()` — where all of
/// it used to — for two reasons. It ran on every rebuild, recomputing thirty
/// `DateTime.now()` calls to draw one chart; and none of it was testable, so the
/// numbers an owner makes staffing decisions from had never been asserted
/// against a known set of visits.
///
/// **No new reads.** Every figure below is derived from the shops, streaks,
/// vouchers and visits [StoreController] already loads, so adding a metric costs
/// no query, no index and no security rule. What that buys is also what bounds
/// it: the store fetches [analyticsWindowDays] of visits, so anything counted
/// from visits is capped at that window and says so in its name or its label.
/// Lifetime figures come off the streak documents instead, which carry
/// `totalVisits` and `longestStreakDays` for all time.
///
/// **Not ported logic.** Unlike `streak_logic.dart` and `dates.dart`, nothing
/// here has a TypeScript counterpart to stay in agreement with — the server
/// decides streaks, vouchers and day boundaries, and this only reports what it
/// already wrote. There is no parity test to add because there is nothing on the
/// other side to disagree with.
library;

import '../core/utils/dates.dart';
import '../data/models/shop.dart';
import '../data/models/streak.dart';
import '../data/models/visit.dart';
import '../data/models/voucher.dart';

/// Days of visit history the store loads, and therefore the longest span any
/// visit-derived figure here can cover. Mirrors `_visitWindowStart` in
/// `state/store_controller.dart`; asserted in `owner_analytics_test.dart`.
const analyticsWindowDays = 30;

/// The rolling comparison period. Seven days rather than a calendar week so the
/// figure means the same thing whichever day the owner opens the app — a
/// Tuesday-to-Tuesday comparison is stable, "this week so far vs all of last
/// week" is not, and would report a collapse in trade every Monday morning.
const comparisonPeriodDays = 7;

/// How much warning counts as "at risk": a customer whose streak dies today or
/// tomorrow unless they come in.
///
/// The customers list used to call anyone who had not visited *today* at risk,
/// which on a three-day window is most of a healthy customer base — the filter
/// selected almost everyone and so pointed at nobody. Risk is about the window
/// running out, not about a quiet day.
const atRiskLeadDays = 1;

/// A voucher expiring within this many days is worth chasing: it is a discount
/// the shop has already promised and is about to stop owing.
const expiringSoonDays = 7;

/// How a customer stands against the shop's return window.
enum CustomerStanding {
  /// Visited recently enough that the window is not a concern yet.
  active,

  /// The streak dies within [atRiskLeadDays] unless they come in.
  atRisk,

  /// The window has already closed.
  lapsed,
}

/// Where a customer's streak stands, and how long they have left to save it.
CustomerStanding standingOf(Streak streak, int windowDays, String today) {
  final since = daysBetween(streak.lastVisitDate, today);
  if (since > windowDays) return CustomerStanding.lapsed;
  // An unreadable date measures as `unknownDateDistanceDays`, so it lapses
  // above rather than reaching here — the same conservative answer the streak
  // logic itself gives.
  return windowDays - since <= atRiskLeadDays
      ? CustomerStanding.atRisk
      : CustomerStanding.active;
}

/// One band of the customer base, sized by current streak length. The bands
/// are named rather than positional: a screen reading `segments[0]` breaks
/// silently the day a band is inserted, and the compiler cannot see it.
enum StreakBand {
  regulars('Regulars (30+ days)'),
  growing('Growing (7–29 days)'),
  starting('New (1–6 days)'),
  lapsed('Lapsed');

  const StreakBand(this.label);
  final String label;
}

typedef Segment = ({StreakBand band, int count});

/// The shop's numbers. Construct with [OwnerAnalytics.of].
class OwnerAnalytics {
  const OwnerAnalytics({
    required this.visitsToday,
    required this.visitsThisPeriod,
    required this.visitsPreviousPeriod,
    required this.visitsInWindow,
    required this.dailyVisits,
    required this.visitsByWeekday,
    required this.visitsByHour,
    required this.uniqueVisitorsThisPeriod,
    required this.totalCustomers,
    required this.activeCustomers,
    required this.atRiskCustomers,
    required this.lapsedCustomers,
    required this.newCustomersThisPeriod,
    required this.repeatRatePercent,
    required this.lifetimeVisits,
    required this.longestActiveStreak,
    required this.topCustomerName,
    required this.vouchersEarned,
    required this.vouchersRedeemed,
    required this.vouchersOutstanding,
    required this.vouchersExpiringSoon,
    required this.redemptionRatePercent,
    required this.averageDiscountPercent,
    required this.regularCustomers,
    required this.growingCustomers,
    required this.startingCustomers,
  });

  /// The zero state — a shop that has never been visited. Also what an owner
  /// sees before their first customer, which is a real screen, not a fallback.
  factory OwnerAnalytics.empty() => OwnerAnalytics(
        visitsToday: 0,
        visitsThisPeriod: 0,
        visitsPreviousPeriod: 0,
        visitsInWindow: 0,
        dailyVisits: List<int>.filled(analyticsWindowDays, 0),
        visitsByWeekday: List<int>.filled(DateTime.daysPerWeek, 0),
        visitsByHour: List<int>.filled(Duration.hoursPerDay, 0),
        uniqueVisitorsThisPeriod: 0,
        totalCustomers: 0,
        activeCustomers: 0,
        atRiskCustomers: 0,
        lapsedCustomers: 0,
        newCustomersThisPeriod: 0,
        repeatRatePercent: 0,
        lifetimeVisits: 0,
        longestActiveStreak: 0,
        topCustomerName: null,
        vouchersEarned: 0,
        vouchersRedeemed: 0,
        vouchersOutstanding: 0,
        vouchersExpiringSoon: 0,
        redemptionRatePercent: 0,
        averageDiscountPercent: 0,
        regularCustomers: 0,
        growingCustomers: 0,
        startingCustomers: 0,
      );

  // ---- traffic -------------------------------------------------------------

  final int visitsToday;

  /// The last [comparisonPeriodDays] including today.
  final int visitsThisPeriod;

  /// The [comparisonPeriodDays] before that, for the trend.
  final int visitsPreviousPeriod;
  final int visitsInWindow;

  /// One count per day, **oldest first**, length [analyticsWindowDays]. The
  /// last entry is today.
  final List<int> dailyVisits;

  /// Seven counts, index 0 = Monday, matching `DateTime.weekday - 1`.
  final List<int> visitsByWeekday;

  /// Twenty-four counts, index = hour of the local day.
  final List<int> visitsByHour;

  final int uniqueVisitorsThisPeriod;

  // ---- people --------------------------------------------------------------

  final int totalCustomers;
  final int activeCustomers;
  final int atRiskCustomers;
  final int lapsedCustomers;

  /// Customers whose every recorded visit falls inside this period — that is,
  /// people who found the shop this week. Derived by comparing visits seen in
  /// the period against the streak's lifetime `totalVisits`, so it is exact
  /// rather than inferred from a streak start date (which resets on a break and
  /// would report every returning customer as a new one).
  final int newCustomersThisPeriod;

  /// Share of customers who have come back at least once.
  final int repeatRatePercent;

  /// All visits ever, across all customers — from the streak documents, so not
  /// bounded by the visit window.
  final int lifetimeVisits;

  final int longestActiveStreak;

  /// Who holds [longestActiveStreak]. Null when there are no live streaks.
  final String? topCustomerName;

  // ---- rewards -------------------------------------------------------------

  final int vouchersEarned;
  final int vouchersRedeemed;

  /// Unredeemed and unexpired: a discount already promised and still claimable.
  final int vouchersOutstanding;

  /// Of those, the ones lapsing within [expiringSoonDays].
  final int vouchersExpiringSoon;

  final int redemptionRatePercent;
  final int averageDiscountPercent;

  // ---- streak bands --------------------------------------------------------
  //
  // Live customers only. A lapsed customer keeps whatever streak length they
  // had when the window closed, so counting them by band as well would put
  // them in two places at once and make the bands sum to more than the book.

  /// A live streak of 30 days or more.
  final int regularCustomers;

  /// 7 to 29 days.
  final int growingCustomers;

  /// 1 to 6 days.
  final int startingCustomers;

  /// The bands as a display list, in the order they are shown. Every customer
  /// falls in exactly one, so these sum to [totalCustomers] — asserted in the
  /// tests, because a band that quietly double-counts is invisible on screen.
  List<Segment> get segments => [
        (band: StreakBand.regulars, count: regularCustomers),
        (band: StreakBand.growing, count: growingCustomers),
        (band: StreakBand.starting, count: startingCustomers),
        (band: StreakBand.lapsed, count: lapsedCustomers),
      ];

  /// Percentage change in visits against the previous period, or null when
  /// there is nothing to compare against.
  ///
  /// Null rather than 0 or 100 on purpose: a shop's first week has no previous
  /// week, and reporting that as "+100%" or "0%" invents a trend out of missing
  /// data. The caller shows a dash.
  int? get trendPercent {
    if (visitsPreviousPeriod == 0) return null;
    final change = visitsThisPeriod - visitsPreviousPeriod;
    return ((change / visitsPreviousPeriod) * 100).round();
  }

  /// Busiest day of the week over the window, as `DateTime.monday`..`sunday`.
  /// Null when nothing has been recorded. Ties go to the earlier weekday.
  int? get busiestWeekday {
    final peak = _peakIndex(visitsByWeekday);
    return peak == null ? null : peak + 1;
  }

  /// Busiest hour of the local day, 0–23. Null when nothing was recorded.
  int? get busiestHour => _peakIndex(visitsByHour);

  /// Average lifetime visits per customer, to one decimal.
  double get visitsPerCustomer =>
      totalCustomers == 0 ? 0 : lifetimeVisits / totalCustomers;

  /// Customers the owner can still do something about today. The lapsed have
  /// already gone; these have not.
  bool get hasAtRisk => atRiskCustomers > 0;

  static int? _peakIndex(List<int> counts) {
    var best = -1;
    var bestAt = -1;
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] > best) {
        best = counts[i];
        bestAt = i;
      }
    }
    return best <= 0 ? null : bestAt;
  }

  /// Compute the shop's numbers.
  ///
  /// [visits], [streaks] and [vouchers] may cover several shops — the owner's
  /// queries are scoped by owner, not by shop — so they are filtered to
  /// [shop] here. [today] is injected rather than read from the clock so the
  /// tests can pin a day.
  factory OwnerAnalytics.of({
    required Shop shop,
    required List<Visit> visits,
    required List<Streak> streaks,
    required List<Voucher> vouchers,
    required String today,
  }) {
    final shopVisits = [for (final v in visits) if (v.shopId == shop.id) v];
    final shopStreaks = [for (final s in streaks) if (s.shopId == shop.id) s];
    final shopVouchers = [for (final v in vouchers) if (v.shopId == shop.id) v];

    // ---- traffic, bucketed by local calendar day ---------------------------
    //
    // A visit's `timestamp` is the server's `toISOString()`, i.e. UTC. The day
    // strings this app compares against are the device's. Bucketing by
    // `timestamp.startsWith(day)` — which is what the dashboard used to do —
    // therefore compares a UTC day against a local one, and every visit before
    // 08:00 in UTC+8 fell into *yesterday*: a bakery's entire morning was
    // missing from "Visits today" until eight in the morning, while the server
    // had already counted it and extended the streak. Parse the instant and
    // convert before asking what day it was.
    //
    // Local means the device's zone, which for an owner standing in their own
    // shop is the shop's. An owner checking in from another country sees their
    // own day boundaries; the server stays authoritative for streaks either way.
    final dailyVisits = List<int>.filled(analyticsWindowDays, 0);
    final byWeekday = List<int>.filled(DateTime.daysPerWeek, 0);
    final byHour = List<int>.filled(Duration.hoursPerDay, 0);

    // Index the window's days once, rather than formatting a date per visit
    // per day. Oldest first, so `dayIndex[today]` is the last slot.
    final dayIndex = <String, int>{};
    for (var i = 0; i < analyticsWindowDays; i++) {
      final day = addDays(today, -(analyticsWindowDays - 1 - i));
      dayIndex[day] = i;
    }

    final periodVisitors = <String, int>{};
    var visitsThisPeriod = 0;
    var visitsPreviousPeriod = 0;

    for (final visit in shopVisits) {
      final at = DateTime.tryParse(visit.timestamp)?.toLocal();
      // A visit we cannot place in time is counted nowhere rather than
      // guessed into today — an inflated "visits today" is worse than a
      // missing one, because it is the number the owner trusts most.
      if (at == null) continue;

      final day = toDateString(at);
      final slot = dayIndex[day];
      if (slot != null) {
        dailyVisits[slot]++;
        byWeekday[at.weekday - 1]++;
        byHour[at.hour]++;
      }

      final age = daysBetween(day, today);
      if (age < comparisonPeriodDays) {
        visitsThisPeriod++;
        periodVisitors[visit.userId] = (periodVisitors[visit.userId] ?? 0) + 1;
      } else if (age < comparisonPeriodDays * 2) {
        visitsPreviousPeriod++;
      }
    }

    // ---- people ------------------------------------------------------------
    var active = 0;
    var atRisk = 0;
    var lapsed = 0;
    var repeat = 0;
    var newThisPeriod = 0;
    var lifetimeVisits = 0;
    var longestActive = 0;
    String? topCustomer;
    var regulars = 0;
    var growing = 0;
    var starting = 0;

    for (final streak in shopStreaks) {
      lifetimeVisits += streak.totalVisits;
      if (streak.totalVisits > 1) repeat++;

      // Every visit this customer has ever made happened inside the period, so
      // this week is when they found the shop.
      final seenThisPeriod = periodVisitors[streak.userId] ?? 0;
      if (seenThisPeriod > 0 && seenThisPeriod >= streak.totalVisits) {
        newThisPeriod++;
      }

      final standing = standingOf(streak, shop.streakWindowDays, today);
      switch (standing) {
        case CustomerStanding.lapsed:
          lapsed++;
        case CustomerStanding.atRisk:
          atRisk++;
        case CustomerStanding.active:
          active++;
      }

      if (standing != CustomerStanding.lapsed) {
        if (streak.currentStreakDays > longestActive) {
          longestActive = streak.currentStreakDays;
          topCustomer = streak.userName?.trim().isNotEmpty == true
              ? streak.userName!.trim()
              : null;
        }
        if (streak.currentStreakDays >= 30) {
          regulars++;
        } else if (streak.currentStreakDays >= 7) {
          growing++;
        } else if (streak.currentStreakDays >= 1) {
          starting++;
        }
      }
    }

    // ---- rewards -----------------------------------------------------------
    var redeemed = 0;
    var outstanding = 0;
    var expiringSoon = 0;
    var discountTotal = 0;

    for (final voucher in shopVouchers) {
      if (voucher.isRedeemed) {
        redeemed++;
        discountTotal += voucher.discountPercent;
        continue;
      }
      // `daysFromNow > 0` is the app-wide "not expired yet" contract — the same
      // test the Vouchers screen splits Active from Expired on. See dates.dart.
      final left = daysFromNow(voucher.expiresAt);
      if (left > 0) {
        outstanding++;
        if (left <= expiringSoonDays) expiringSoon++;
      }
    }

    final total = shopStreaks.length;

    return OwnerAnalytics(
      visitsToday: dailyVisits.last,
      visitsThisPeriod: visitsThisPeriod,
      visitsPreviousPeriod: visitsPreviousPeriod,
      visitsInWindow: dailyVisits.fold(0, (a, b) => a + b),
      dailyVisits: dailyVisits,
      visitsByWeekday: byWeekday,
      visitsByHour: byHour,
      uniqueVisitorsThisPeriod: periodVisitors.length,
      totalCustomers: total,
      activeCustomers: active,
      atRiskCustomers: atRisk,
      lapsedCustomers: lapsed,
      newCustomersThisPeriod: newThisPeriod,
      repeatRatePercent: total == 0 ? 0 : ((repeat / total) * 100).round(),
      lifetimeVisits: lifetimeVisits,
      longestActiveStreak: longestActive,
      topCustomerName: topCustomer,
      vouchersEarned: shopVouchers.length,
      vouchersRedeemed: redeemed,
      vouchersOutstanding: outstanding,
      vouchersExpiringSoon: expiringSoon,
      redemptionRatePercent: shopVouchers.isEmpty
          ? 0
          : ((redeemed / shopVouchers.length) * 100).round(),
      averageDiscountPercent:
          redeemed == 0 ? 0 : (discountTotal / redeemed).round(),
      regularCustomers: regulars,
      growingCustomers: growing,
      startingCustomers: starting,
    );
  }
}

/// "Mon", "Tue"… from `DateTime.monday`..`DateTime.sunday`. For chart labels,
/// where the column is narrow and the reader has six neighbours for context.
String weekdayLabel(int weekday) => const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][(weekday - 1).clamp(0, 6)];

/// "Monday", "Tuesday"… For prose, where the abbreviation has to be pluralised
/// and "Weds" is not a word anybody writes.
String weekdayFullLabel(int weekday) => const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][(weekday - 1).clamp(0, 6)];

/// "8am", "12pm", "5pm" — an hour as an owner would say it out loud.
String hourLabel(int hour) {
  final h = hour % 24;
  final suffix = h < 12 ? 'am' : 'pm';
  final display = h % 12 == 0 ? 12 : h % 12;
  return '$display$suffix';
}

/// "12–1pm": the hour-long band an owner staffs against.
String hourRangeLabel(int hour) => '${hourLabel(hour)}–${hourLabel(hour + 1)}';
