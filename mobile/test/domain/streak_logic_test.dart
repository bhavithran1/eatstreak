import 'package:eatstreak/core/utils/dates.dart';
import 'package:eatstreak/data/models/enums.dart';
import 'package:eatstreak/data/models/reward_tier.dart';
import 'package:eatstreak/domain/streak_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from functions/src/streakLogic.test.ts. Same scenarios, same
/// expectations — this is what proves the Dart port of the check-in math
/// behaves identically to the Cloud Function that runs it for real.
void main() {
  const today = '2026-07-16';
  final yesterday = addDays(today, -1);
  final twoAgo = addDays(today, -2);
  final fourAgo = addDays(today, -4);

  group('computeCheckIn', () {
    test('new streak starts at 1', () {
      final r = computeCheckIn(null, today, 3);

      expect(r.status, CheckInStatus.success);
      expect(r.streak.currentStreakDays, 1);
      expect(r.streak.totalVisits, 1);
      expect(r.streak.isStreakAlive, isTrue);
    });

    test('same-day repeat does not mutate the streak', () {
      const existing = StreakCore(
        currentStreakDays: 5,
        longestStreakDays: 9,
        totalVisits: 12,
        lastVisitDate: today,
        streakStartDate: '2026-07-12',
        isStreakAlive: true,
      );

      final r = computeCheckIn(existing, today, 3);

      expect(r.status, CheckInStatus.alreadyVisitedToday);
      expect(r.streak.currentStreakDays, 5);
      expect(r.streak.totalVisits, 12);
      expect(identical(r.streak, existing), isTrue);
    });

    test('within the window increments and keeps the start date', () {
      final existing = StreakCore(
        currentStreakDays: 5,
        longestStreakDays: 5,
        totalVisits: 5,
        lastVisitDate: yesterday,
        streakStartDate: '2026-07-10',
        isStreakAlive: true,
      );

      final r = computeCheckIn(existing, today, 3);

      expect(r.streak.currentStreakDays, 6);
      expect(r.streak.totalVisits, 6);
      expect(r.streak.streakStartDate, '2026-07-10');
      expect(r.streak.longestStreakDays, 6);
    });

    test('exactly at the window boundary still increments', () {
      final existing = StreakCore(
        currentStreakDays: 2,
        longestStreakDays: 2,
        totalVisits: 2,
        lastVisitDate: twoAgo,
        streakStartDate: twoAgo,
        isStreakAlive: true,
      );

      final r = computeCheckIn(existing, today, 2);

      expect(r.streak.currentStreakDays, 3);
    });

    test('beyond the window resets to 1 but preserves totals and longest', () {
      final existing = StreakCore(
        currentStreakDays: 8,
        longestStreakDays: 8,
        totalVisits: 8,
        lastVisitDate: fourAgo,
        streakStartDate: '2026-07-05',
        isStreakAlive: true,
      );

      final r = computeCheckIn(existing, today, 2);

      expect(r.streak.currentStreakDays, 1);
      expect(r.streak.totalVisits, 9);
      expect(r.streak.streakStartDate, today);
      expect(r.streak.longestStreakDays, 8);
    });
  });

  group('qualifyingTiers', () {
    final tiers = [
      const RewardTier(id: 's_v5', shopId: 's', type: RewardType.visitCount, threshold: 5, discountPercent: 10, label: 'Regular', description: '', emoji: '⭐'),
      const RewardTier(id: 's_v10', shopId: 's', type: RewardType.visitCount, threshold: 10, discountPercent: 20, label: 'Loyal', description: '', emoji: '💎'),
      const RewardTier(id: 's_s3', shopId: 's', type: RewardType.streakDays, threshold: 3, discountPercent: 5, label: '3-Day', description: '', emoji: '🔥'),
    ];

    const atFiveVisitsThreeDays = StreakCore(
      currentStreakDays: 3,
      longestStreakDays: 3,
      totalVisits: 5,
      lastVisitDate: today,
      streakStartDate: today,
      isStreakAlive: true,
    );

    test('awards exactly the tiers met, none above', () {
      final ids = qualifyingTiers(atFiveVisitsThreeDays, tiers, {}).map((t) => t.id).toList()
        ..sort();

      expect(ids, ['s_s3', 's_v5']);
      expect(ids, isNot(contains('s_v10')));
    });

    test('already-awarded tiers are never re-awarded', () {
      final q = qualifyingTiers(atFiveVisitsThreeDays, tiers, {'s_v5', 's_s3'});

      expect(q, isEmpty);
    });

    test('nothing qualifies below all thresholds', () {
      const streak = StreakCore(
        currentStreakDays: 1,
        longestStreakDays: 1,
        totalVisits: 1,
        lastVisitDate: today,
        streakStartDate: today,
        isStreakAlive: true,
      );

      expect(qualifyingTiers(streak, tiers, {}), isEmpty);
    });
  });

  group('daysBetween', () {
    test('counts whole calendar days regardless of order', () {
      expect(daysBetween('2026-07-16', '2026-07-16'), 0);
      expect(daysBetween('2026-07-15', '2026-07-16'), 1);
      expect(daysBetween('2026-07-16', '2026-07-12'), 4);
    });

    test('is stable across a daylight-saving boundary', () {
      // Whatever the local zone does, a calendar month is a whole number of days.
      expect(daysBetween('2026-03-01', '2026-04-01'), 31);
    });
  });
}
