import 'package:eatstreak/domain/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

/// The trial countdown an owner sees, and the switch that keeps commerce out of
/// the iOS build. Both were untested.
void main() {
  group('showsPricingInApp', () {
    // Apple 3.1.1 requires IAP for a digital subscription sold inside the app.
    // The route the project took instead is 3.1.3(b) — subscribe on the web,
    // present no commerce at all here. Flipping this without an IAP
    // implementation is a rejected build, so assert the value literally rather
    // than trusting a comment.
    test('is off — no prices or checkout in the app', () {
      expect(showsPricingInApp, isFalse);
    });
  });

  group('subscriptionFor', () {
    test('a shop registered today is trialing with the full month', () {
      final s = subscriptionFor('2026-03-01', '2026-03-01');
      expect(s.status, SubscriptionStatus.trialing);
      expect(s.daysLeftInTrial, trialDays);
      expect(s.isTrialing, isTrue);
      expect(s.needsPayment, isFalse);
    });

    test('counts down day by day', () {
      expect(subscriptionFor('2026-03-01', '2026-03-02').daysLeftInTrial, trialDays - 1);
      expect(subscriptionFor('2026-03-01', '2026-03-11').daysLeftInTrial, trialDays - 10);
    });

    test('the last day of the trial still has a day left', () {
      final s = subscriptionFor('2026-03-01', '2026-03-30');
      expect(s.status, SubscriptionStatus.trialing);
      expect(s.daysLeftInTrial, 1);
    });

    test('day 30 is expired, not a zero-day trial', () {
      final s = subscriptionFor('2026-03-01', '2026-03-31');
      expect(s.status, SubscriptionStatus.trialExpired);
      expect(s.daysLeftInTrial, 0);
      expect(s.needsPayment, isTrue);
    });

    test('long past the trial stays expired, never negative', () {
      final s = subscriptionFor('2026-01-01', '2026-12-01');
      expect(s.status, SubscriptionStatus.trialExpired);
      expect(s.daysLeftInTrial, 0);
    });

    // Entitlement comes from the webhook, so a paid shop is active regardless
    // of how old its client-written createdAt is.
    test('an active subscription outranks an expired trial', () {
      final s = subscriptionFor('2020-01-01', '2026-03-01', hasActiveSubscription: true);
      expect(s.status, SubscriptionStatus.active);
      expect(s.needsPayment, isFalse);
    });

    test('an active subscription outranks a running trial too', () {
      final s = subscriptionFor('2026-03-01', '2026-03-02', hasActiveSubscription: true);
      expect(s.status, SubscriptionStatus.active);
      expect(s.isTrialing, isFalse);
    });

    test('a missing createdAt is treated as a fresh trial, not an expiry', () {
      final s = subscriptionFor('', '2026-03-01');
      expect(s.status, SubscriptionStatus.trialing);
      expect(s.daysLeftInTrial, trialDays);
    });

    // The dashboard calls this inside build() on a document it did not write.
    // An unreadable createdAt used to throw a FormatException out of
    // daysBetween and red-screen the owner's home; it now reads as an expired
    // trial, which is wrong-but-visible rather than fatal.
    test('an unreadable createdAt does not throw', () {
      expect(() => subscriptionFor('not-a-date', '2026-03-01'), returnsNormally);
      expect(() => subscriptionFor('2026-03-01T10:00:00.000', '2026-03-01'),
          returnsNormally);
    });

    test('needsPayment is true only when something is actually owed', () {
      expect(subscriptionFor('2026-03-01', '2026-03-02').needsPayment, isFalse);
      expect(subscriptionFor('2026-01-01', '2026-06-01').needsPayment, isTrue);
      expect(
        subscriptionFor('2026-01-01', '2026-06-01', hasActiveSubscription: true)
            .needsPayment,
        isFalse,
      );
    });
  });

  group('pricing constants', () {
    // Not shown in the app, but the billing page quotes them; the annual price
    // is meant to be two months free.
    test('annual is twelve months less two', () {
      expect(annualPriceMyr, monthlyPriceMyr * 10);
    });

    test('the trial is a full month', () => expect(trialDays, 30));
  });
}
