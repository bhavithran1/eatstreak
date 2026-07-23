/// Shop subscription: the free month, and what follows it.
///
/// Deliberately provider-agnostic. Nothing here knows about Stripe, Curlec or
/// Billplz — the app only ever reads *status*, and billing happens wherever the
/// backend says it happens.
library;

import '../core/utils/dates.dart';

/// Every new shop gets a full month before anything is owed.
const trialDays = 30;

/// Monthly price once the trial ends, in Malaysian ringgit.
const monthlyPriceMyr = 49;

/// Annual price — two months free, the usual SaaS discount for paying up front.
const annualPriceMyr = 490;

/// Whether the app itself may display prices or a way to pay.
///
/// **Off on purpose.** Outside the United States, Apple requires that a
/// subscription unlocking features in an iOS app go through In-App Purchase
/// (App Review Guideline 3.1.1), which takes 15–30%. The route that avoids
/// that is 3.1.3(b) Multiplatform Services: the owner subscribes on the web,
/// signs in here, and the app presents *no commerce at all* — no prices, no
/// buy buttons, no links to checkout.
///
/// Turning this on without either an IAP implementation or that entitlement is
/// how the app gets rejected. It is a single switch so the decision can be made
/// once, deliberately, rather than by leaking price copy into screens.
const showsPricingInApp = false;

enum SubscriptionStatus { trialing, trialExpired, active, inactive }

class ShopSubscription {
  const ShopSubscription({required this.status, required this.daysLeftInTrial});

  final SubscriptionStatus status;

  /// Days remaining in the free month. 0 once it has run out.
  final int daysLeftInTrial;

  bool get isTrialing => status == SubscriptionStatus.trialing;
  bool get needsPayment =>
      status == SubscriptionStatus.trialExpired ||
      status == SubscriptionStatus.inactive;
}

/// Work out where a shop stands from its creation date and whatever billing
/// state the backend has recorded.
///
/// [createdAt] is a `yyyy-MM-dd` string. Note this is currently written by the
/// client at registration, so it is fine for *display* but must not be the
/// thing that gates paid features — when billing goes live the status has to
/// come from the payment provider's webhook, server-side, or an owner could
/// forward-date their own trial.
ShopSubscription subscriptionFor(
  String createdAt,
  String todayStr, {
  bool hasActiveSubscription = false,
}) {
  if (hasActiveSubscription) {
    return const ShopSubscription(
      status: SubscriptionStatus.active,
      daysLeftInTrial: 0,
    );
  }

  if (createdAt.isEmpty) {
    return const ShopSubscription(
      status: SubscriptionStatus.trialing,
      daysLeftInTrial: trialDays,
    );
  }

  final elapsed = daysBetween(createdAt, todayStr);
  final left = trialDays - elapsed;

  return left > 0
      ? ShopSubscription(
          status: SubscriptionStatus.trialing,
          daysLeftInTrial: left,
        )
      : const ShopSubscription(
          status: SubscriptionStatus.trialExpired,
          daysLeftInTrial: 0,
        );
}
