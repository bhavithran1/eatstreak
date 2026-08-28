import 'package:eatstreak/core/utils/dates.dart';
import 'package:eatstreak/data/models/enums.dart';
import 'package:eatstreak/data/models/shop.dart';
import 'package:eatstreak/data/models/streak.dart';
import 'package:eatstreak/data/models/visit.dart';
import 'package:eatstreak/data/models/voucher.dart';
import 'package:eatstreak/domain/owner_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

/// The owner's numbers, against a known set of visits.
///
/// All of this used to be computed inline in `dashboard_screen.build()` and was
/// therefore never asserted — including "Visits today", which was wrong by a
/// whole morning in any timezone east of UTC.
void main() {
  final today = todayString();

  Shop shop({int windowDays = 3, String id = 'shop_a'}) => Shop(
        id: id,
        name: 'Sweet Rise Bakery',
        ownerId: 'owner_1',
        category: ShopCategory.bakery,
        emoji: '🥐',
        description: '',
        address: '',
        rewardTiers: const [],
        streakWindowDays: windowDays,
        createdAt: '2026-01-01',
      );

  /// A visit at a **local** wall-clock time, stored the way the server stores
  /// it: `toISOString()`, i.e. UTC with a trailing Z.
  Visit visitAt(
    DateTime localTime, {
    String user = 'u1',
    String shopId = 'shop_a',
  }) =>
      Visit(
        id: 'v_${localTime.microsecondsSinceEpoch}_$user',
        userId: user,
        shopId: shopId,
        timestamp: localTime.toUtc().toIso8601String(),
      );

  /// Local midday `n` days ago — far from either day boundary, so it lands on
  /// the day it says regardless of the machine's timezone.
  DateTime middayDaysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 12).subtract(Duration(days: n));
  }

  Streak streak({
    String user = 'u1',
    String shopId = 'shop_a',
    int current = 5,
    int longest = 5,
    int total = 5,
    String? lastVisit,
    String? name,
  }) =>
      Streak(
        id: '${user}_$shopId',
        userId: user,
        shopId: shopId,
        currentStreakDays: current,
        longestStreakDays: longest,
        totalVisits: total,
        lastVisitDate: lastVisit ?? today,
        streakStartDate: today,
        isStreakAlive: true,
        userName: name,
      );

  Voucher voucher({
    String id = 'vo1',
    String shopId = 'shop_a',
    bool redeemed = false,
    int discount = 20,
    String? expires,
  }) =>
      Voucher(
        id: id,
        userId: 'u1',
        shopId: shopId,
        shopName: 'Sweet Rise Bakery',
        shopEmoji: '🥐',
        tierId: 't1',
        type: RewardType.visitCount,
        discountPercent: discount,
        tierLabel: 'Regular',
        earnedAt: '2026-01-01T00:00:00.000Z',
        expiresAt: expires ?? '2099-01-01T00:00:00.000Z',
        isRedeemed: redeemed,
        code: 'EAT-ABC123',
      );

  OwnerAnalytics compute({
    Shop? forShop,
    List<Visit> visits = const [],
    List<Streak> streaks = const [],
    List<Voucher> vouchers = const [],
  }) =>
      OwnerAnalytics.of(
        shop: forShop ?? shop(),
        visits: visits,
        streaks: streaks,
        vouchers: vouchers,
        today: today,
      );

  group('the window', () {
    test('is the 30 days the store actually loads', () {
      // store_controller.dart reads visits from dateNDaysAgo(29) — 29 days back
      // plus today. A figure here that claimed a longer span would be counting
      // days the store never fetched.
      expect(analyticsWindowDays, 30);
      expect(dateNDaysAgo(analyticsWindowDays - 1), addDays(today, -29));
    });

    test('a day of counts exists for every day in it', () {
      expect(compute().dailyVisits, hasLength(analyticsWindowDays));
    });
  });

  group('an untouched shop', () {
    test('reports zeros rather than throwing', () {
      final a = compute();
      expect(a.visitsToday, 0);
      expect(a.visitsInWindow, 0);
      expect(a.totalCustomers, 0);
      expect(a.repeatRatePercent, 0);
      expect(a.redemptionRatePercent, 0);
      expect(a.averageDiscountPercent, 0);
      expect(a.visitsPerCustomer, 0);
      expect(a.topCustomerName, isNull);
    });

    test('has no trend, rather than a made-up one', () {
      // The first week has no previous week. Reporting "+100%" or "0%" would
      // invent a direction out of data that does not exist.
      expect(compute().trendPercent, isNull);
      expect(compute().busiestWeekday, isNull);
      expect(compute().busiestHour, isNull);
    });

    test('empty() agrees with computing over nothing', () {
      final empty = OwnerAnalytics.empty();
      final computed = compute();
      expect(empty.dailyVisits, computed.dailyVisits);
      expect(empty.visitsByHour.length, computed.visitsByHour.length);
      expect(empty.visitsByWeekday.length, computed.visitsByWeekday.length);
      expect(empty.trendPercent, computed.trendPercent);
    });
  });

  group('visits today', () {
    test('counts a visit at midday today', () {
      expect(compute(visits: [visitAt(middayDaysAgo(0))]).visitsToday, 1);
    });

    // The regression this module was extracted for. `timestamp` is UTC and
    // `todayString()` is device-local, so the old `timestamp.startsWith(today)`
    // test dropped a whole band of the day into yesterday — in UTC+8 that is
    // every visit before 08:00, which for a bakery is the morning rush.
    //
    // One of these two lands on a different UTC day in any zone that is not
    // UTC itself: the first for zones ahead of UTC, the second for zones
    // behind it. On a machine running in UTC there is nothing to convert and
    // both simply pass.
    test('counts the first customer of the morning', () {
      final now = DateTime.now();
      final justAfterMidnight = DateTime(now.year, now.month, now.day, 0, 30);
      expect(compute(visits: [visitAt(justAfterMidnight)]).visitsToday, 1);
    });

    test('counts the last customer of the night', () {
      final now = DateTime.now();
      final lateEvening = DateTime(now.year, now.month, now.day, 23, 30);
      expect(compute(visits: [visitAt(lateEvening)]).visitsToday, 1);
    });

    test('does not count yesterday as today', () {
      final a = compute(visits: [visitAt(middayDaysAgo(1))]);
      expect(a.visitsToday, 0);
      expect(a.visitsInWindow, 1);
    });

    test('ignores another shop entirely', () {
      // Owner queries are scoped by owner, not by shop, so a second shop's
      // visits arrive in the same list.
      final a = compute(
        visits: [
          visitAt(middayDaysAgo(0)),
          visitAt(middayDaysAgo(0), shopId: 'shop_b'),
        ],
      );
      expect(a.visitsToday, 1);
    });

    test('skips a timestamp it cannot read instead of guessing today', () {
      final a = compute(
        visits: [
          Visit(id: 'bad', userId: 'u1', shopId: 'shop_a', timestamp: 'nonsense'),
          Visit(id: 'empty', userId: 'u1', shopId: 'shop_a', timestamp: ''),
          visitAt(middayDaysAgo(0)),
        ],
      );
      // An inflated "visits today" is worse than a missing one: it is the
      // number the owner trusts most.
      expect(a.visitsToday, 1);
      expect(a.visitsInWindow, 1);
    });
  });

  group('the 30-day series', () {
    test('runs oldest first and ends on today', () {
      final a = compute(
        visits: [
          visitAt(middayDaysAgo(0)),
          visitAt(middayDaysAgo(0), user: 'u2'),
          visitAt(middayDaysAgo(29)),
        ],
      );
      expect(a.dailyVisits.last, 2);
      expect(a.dailyVisits.first, 1);
      expect(a.visitsInWindow, 3);
    });

    test('drops a visit older than the window rather than folding it into day 0', () {
      final a = compute(visits: [visitAt(middayDaysAgo(45))]);
      expect(a.visitsInWindow, 0);
      expect(a.dailyVisits.first, 0);
    });
  });

  group('the weekly trend', () {
    test('compares the last seven days against the seven before', () {
      final a = compute(
        visits: [
          for (var d = 0; d < 7; d++) visitAt(middayDaysAgo(d)),
          for (var d = 7; d < 12; d++) visitAt(middayDaysAgo(d)),
        ],
      );
      expect(a.visitsThisPeriod, 7);
      expect(a.visitsPreviousPeriod, 5);
      expect(a.trendPercent, 40);
    });

    test('reports a fall as a negative', () {
      final a = compute(
        visits: [
          visitAt(middayDaysAgo(1)),
          for (var d = 7; d < 11; d++) visitAt(middayDaysAgo(d)),
        ],
      );
      expect(a.trendPercent, -75);
    });

    test('today counts toward this period, not the previous one', () {
      final a = compute(visits: [visitAt(middayDaysAgo(0))]);
      expect(a.visitsThisPeriod, 1);
      expect(a.visitsPreviousPeriod, 0);
    });

    test('day 7 is the previous period, day 6 is this one', () {
      // The boundary, pinned: an off-by-one here moves a day of trade from one
      // side of the comparison to the other and inverts the arrow.
      expect(compute(visits: [visitAt(middayDaysAgo(6))]).visitsThisPeriod, 1);
      expect(compute(visits: [visitAt(middayDaysAgo(7))]).visitsThisPeriod, 0);
      expect(compute(visits: [visitAt(middayDaysAgo(7))]).visitsPreviousPeriod, 1);
      expect(compute(visits: [visitAt(middayDaysAgo(13))]).visitsPreviousPeriod, 1);
      expect(compute(visits: [visitAt(middayDaysAgo(14))]).visitsPreviousPeriod, 0);
    });

    test('counts unique visitors, not visits', () {
      final a = compute(
        visits: [
          visitAt(middayDaysAgo(0), user: 'u1'),
          visitAt(middayDaysAgo(1), user: 'u1'),
          visitAt(middayDaysAgo(2), user: 'u2'),
        ],
      );
      expect(a.visitsThisPeriod, 3);
      expect(a.uniqueVisitorsThisPeriod, 2);
    });
  });

  group('busiest times', () {
    test('finds the busiest weekday', () {
      final target = middayDaysAgo(3);
      final a = compute(
        visits: [
          visitAt(target),
          visitAt(target, user: 'u2'),
          visitAt(middayDaysAgo(4)),
        ],
      );
      expect(a.busiestWeekday, target.weekday);
      expect(weekdayLabel(a.busiestWeekday!), isNotEmpty);
    });

    test('finds the busiest hour of the local day', () {
      final base = middayDaysAgo(2);
      final lunch = DateTime(base.year, base.month, base.day, 13);
      final quiet = DateTime(base.year, base.month, base.day, 16);
      final a = compute(
        visits: [
          visitAt(lunch),
          visitAt(lunch, user: 'u2'),
          visitAt(lunch, user: 'u3'),
          visitAt(quiet, user: 'u4'),
        ],
      );
      expect(a.busiestHour, 13);
      expect(a.visitsByHour[13], 3);
      expect(hourRangeLabel(a.busiestHour!), '1pm–2pm');
    });

    test('a shop with one visit still has a busiest hour', () {
      final a = compute(visits: [visitAt(middayDaysAgo(1))]);
      expect(a.busiestHour, 12);
    });
  });

  group('where a customer stands', () {
    test('a visit today is comfortably active on a 3-day window', () {
      expect(standingOf(streak(lastVisit: today), 3, today),
          CustomerStanding.active);
    });

    test('the last day to save a streak is at risk, not active', () {
      // Window 3: three days since the last visit means today is the final day
      // they can come in. Yesterday-plus-two is the day before that.
      expect(standingOf(streak(lastVisit: addDays(today, -2)), 3, today),
          CustomerStanding.atRisk);
      expect(standingOf(streak(lastVisit: addDays(today, -3)), 3, today),
          CustomerStanding.atRisk);
    });

    test('past the window it is lapsed', () {
      expect(standingOf(streak(lastVisit: addDays(today, -4)), 3, today),
          CustomerStanding.lapsed);
    });

    test('a tight window puts yesterday at risk already', () {
      expect(standingOf(streak(lastVisit: addDays(today, -1)), 2, today),
          CustomerStanding.atRisk);
      expect(standingOf(streak(lastVisit: today), 2, today),
          CustomerStanding.active);
    });

    test('an unreadable last visit lapses rather than looking healthy', () {
      // daysBetween answers unknownDateDistanceDays, which exceeds any window.
      expect(standingOf(streak(lastVisit: ''), 3, today),
          CustomerStanding.lapsed);
      expect(standingOf(streak(lastVisit: 'not-a-date'), 3, today),
          CustomerStanding.lapsed);
    });

    test('at risk is a small group, not everyone who skipped a day', () {
      // The customers screen used to call anyone who had not visited *today*
      // "at risk", which on a 3-day window selects almost the whole book.
      final a = compute(
        streaks: [
          streak(user: 'u1', lastVisit: today),
          streak(user: 'u2', lastVisit: addDays(today, -1)),
          streak(user: 'u3', lastVisit: addDays(today, -3)),
          streak(user: 'u4', lastVisit: addDays(today, -9)),
        ],
      );
      expect(a.activeCustomers, 2);
      expect(a.atRiskCustomers, 1);
      expect(a.lapsedCustomers, 1);
      expect(a.hasAtRisk, isTrue);
    });
  });

  group('the customer base', () {
    test('counts repeat customers as a share of the whole book', () {
      final a = compute(
        streaks: [
          streak(user: 'u1', total: 1),
          streak(user: 'u2', total: 4),
          streak(user: 'u3', total: 9),
          streak(user: 'u4', total: 1),
        ],
      );
      expect(a.totalCustomers, 4);
      expect(a.repeatRatePercent, 50);
      expect(a.lifetimeVisits, 15);
      expect(a.visitsPerCustomer, 3.75);
    });

    test('a customer whose every visit is this week is a new one', () {
      final a = compute(
        visits: [
          visitAt(middayDaysAgo(0), user: 'newcomer'),
          visitAt(middayDaysAgo(2), user: 'newcomer'),
          visitAt(middayDaysAgo(1), user: 'regular'),
        ],
        streaks: [
          streak(user: 'newcomer', total: 2),
          // Visited this week too, but has been coming for months.
          streak(user: 'regular', total: 40),
        ],
      );
      expect(a.newCustomersThisPeriod, 1);
    });

    test('a returning customer is not counted as new', () {
      // streakStartDate resets on a break, so a start date inside this week
      // describes plenty of long-standing customers. Lifetime visit count is
      // what actually separates them.
      final a = compute(
        visits: [visitAt(middayDaysAgo(0), user: 'u1')],
        streaks: [streak(user: 'u1', current: 1, total: 30)],
      );
      expect(a.newCustomersThisPeriod, 0);
    });

    test('names the best live streak, and ignores a lapsed longer one', () {
      final a = compute(
        streaks: [
          streak(user: 'u1', current: 12, lastVisit: today, name: 'Priya Raman'),
          streak(
            user: 'u2',
            current: 40,
            lastVisit: addDays(today, -20),
            name: 'Ade Bakare',
          ),
        ],
      );
      expect(a.longestActiveStreak, 12);
      expect(a.topCustomerName, 'Priya Raman');
    });

    test('bands the live customers by streak length', () {
      final a = compute(
        streaks: [
          streak(user: 'u1', current: 34, lastVisit: today),
          streak(user: 'u2', current: 12, lastVisit: today),
          streak(user: 'u3', current: 7, lastVisit: today),
          streak(user: 'u4', current: 3, lastVisit: today),
          streak(user: 'u5', current: 6, lastVisit: addDays(today, -9)),
        ],
      );
      expect(a.segments.map((s) => s.count).toList(), [1, 2, 1, 1]);
      // Every customer lands in exactly one band.
      expect(
        a.segments.fold<int>(0, (sum, s) => sum + s.count),
        a.totalCustomers,
      );
    });
  });

  group('the reward programme', () {
    test('separates redeemed, outstanding and expired', () {
      final a = compute(
        vouchers: [
          voucher(id: 'v1', redeemed: true, discount: 10),
          voucher(id: 'v2', redeemed: true, discount: 30),
          voucher(id: 'v3'),
          voucher(id: 'v4', expires: '2020-01-01T00:00:00.000Z'),
        ],
      );
      expect(a.vouchersEarned, 4);
      expect(a.vouchersRedeemed, 2);
      expect(a.vouchersOutstanding, 1);
      expect(a.redemptionRatePercent, 50);
      expect(a.averageDiscountPercent, 20);
    });

    test('flags what is about to expire', () {
      final soon = DateTime.now().add(const Duration(days: 3));
      final later = DateTime.now().add(const Duration(days: 20));
      final a = compute(
        vouchers: [
          voucher(id: 'v1', expires: soon.toUtc().toIso8601String()),
          voucher(id: 'v2', expires: later.toUtc().toIso8601String()),
        ],
      );
      expect(a.vouchersOutstanding, 2);
      expect(a.vouchersExpiringSoon, 1);
    });

    test('a redeemed voucher is never also outstanding', () {
      final a = compute(
        vouchers: [voucher(id: 'v1', redeemed: true)],
      );
      expect(a.vouchersOutstanding, 0);
      expect(a.vouchersExpiringSoon, 0);
    });

    test('another shop\'s vouchers are not this shop\'s liability', () {
      final a = compute(
        vouchers: [voucher(id: 'v1'), voucher(id: 'v2', shopId: 'shop_b')],
      );
      expect(a.vouchersEarned, 1);
    });
  });

  group('labels', () {
    test('an hour reads the way an owner says it', () {
      expect(hourLabel(0), '12am');
      expect(hourLabel(9), '9am');
      expect(hourLabel(12), '12pm');
      expect(hourLabel(13), '1pm');
      expect(hourLabel(23), '11pm');
    });

    test('the band wraps past midnight without producing 24pm', () {
      expect(hourRangeLabel(23), '11pm–12am');
      expect(hourRangeLabel(11), '11am–12pm');
    });

    test('weekdays run Monday first, matching DateTime.weekday', () {
      expect(weekdayLabel(DateTime.monday), 'Mon');
      expect(weekdayLabel(DateTime.sunday), 'Sun');
      expect(weekdayFullLabel(DateTime.monday), 'Monday');
      expect(weekdayFullLabel(DateTime.wednesday), 'Wednesday');
      expect(weekdayFullLabel(DateTime.sunday), 'Sunday');
    });
  });
}
