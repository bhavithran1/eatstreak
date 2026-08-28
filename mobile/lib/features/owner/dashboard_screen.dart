import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../domain/owner_analytics.dart';
import '../../domain/subscription.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/store_scope.dart';
import 'widgets/visits_sparkline.dart';
import 'widgets/weekday_bars.dart';

/// The owner's home: today's numbers, the trend, when the shop is busy, and who
/// is about to slip away.
///
/// All the arithmetic lives in `domain/owner_analytics.dart` — this file only
/// decides what to show and in what order. It used to compute every figure
/// inline here, which meant the numbers an owner staffs and prices against were
/// recomputed on each rebuild and had never been tested against a known set of
/// visits. One of them was wrong by most of a morning.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StoreScope(builder: (context, state) => _body(context, ref, state));

  Widget _body(BuildContext context, WidgetRef ref, StoreState state) {
    final shop = state.ownedShop;

    // Reached only once the store has loaded, so this really is "no shop".
    if (shop == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No shop yet',
              subtitle: 'Register your shop to start tracking visits and '
                  'customer retention.',
              actionLabel: 'Register shop',
              onAction: () => context.push(Routes.registerShop),
            ),
          ),
        ),
      );
    }

    final today = todayString();
    final a = OwnerAnalytics.of(
      shop: shop,
      visits: state.visits,
      streaks: state.streaks,
      vouchers: state.vouchers,
      today: today,
    );
    final subscription = subscriptionFor(shop.createdAt, today);

    return AppScreen(
      onRefresh: ref.read(storeControllerProvider.notifier).refresh,
      children: [
        _header(shop.name, shop.streakWindowDays),
        const SizedBox(height: Spacing.lg),
        _kpiRow(a),
        const SizedBox(height: Spacing.md),
        _quickActions(context),
        if (subscription.isTrialing) ...[
          const SizedBox(height: Spacing.md),
          _trialStatus(subscription.daysLeftInTrial),
        ],

        // Attention first, and at-risk above lapsed: one is a customer the
        // owner can still keep today, the other is a post-mortem.
        if (a.hasAtRisk) ...[
          const SizedBox(height: Spacing.md),
          _atRiskBanner(
            a.atRiskCustomers,
            () => context.go('${Routes.ownerCustomers}?status=at-risk'),
          ),
        ],
        if (a.lapsedCustomers > 0) ...[
          const SizedBox(height: Spacing.md),
          _lapsedBanner(
            a.lapsedCustomers,
            () => context.go('${Routes.ownerCustomers}?status=lapsed'),
          ),
        ],

        const SizedBox(height: Spacing.md),
        _visitsCard(a),
        const SizedBox(height: Spacing.md),
        _busiestTimesCard(a),
        const SizedBox(height: Spacing.md),
        _customerBaseCard(a),
        const SizedBox(height: Spacing.md),
        _rewardCard(a),
        const SizedBox(height: Spacing.md),
        _segmentsCard(a),
      ],
    );
  }

  // ---- header --------------------------------------------------------------

  /// Shop name on the left, return window on the right.
  ///
  /// A [Wrap] rather than a Row with an [Expanded] title, because the pill
  /// cannot shrink: "3-day window" at the largest text setting is wider than a
  /// 375pt phone has left over, and a Row simply overflows — it did, by 20pt.
  /// Wrapping drops the pill onto its own line when the name (which owners
  /// type, and can be long) or the text setting leaves no room beside it.
  Widget _header(String shopName, int windowDays) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("TODAY'S OVERVIEW", style: AppText.eyebrow),
              const SizedBox(height: 2),
              Text(
                shopName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.heading(
                  size: 24,
                  weight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          _windowBadge(windowDays),
        ],
      );

  /// The shop's return window. This slot used to render a hardcoded "Live"
  /// pill that was true regardless of connection or data age — decoration
  /// pretending to be status. The window is the number that actually governs
  /// whether a customer's streak survives.
  Widget _windowBadge(int windowDays) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: Radii.pillAll,
          border: Border.all(color: AppColors.success.withValues(alpha: 0.19)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$windowDays-day window',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      );

  // ---- the three numbers ---------------------------------------------------

  /// [IntrinsicHeight] so the three tiles match the tallest of them — only the
  /// middle one carries a trend chip, and without this it is visibly taller
  /// than its neighbours. A bare `CrossAxisAlignment.stretch` cannot do it: a
  /// Row inside the dashboard's ListView has unbounded height, and stretching
  /// against that asks every tile to be infinitely tall.
  Widget _kpiRow(OwnerAnalytics a) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _kpi(
                '${a.visitsToday}',
                'Visits today',
                AppColors.primary,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _kpi(
                '${a.visitsThisPeriod}',
                'This week',
                AppColors.ink,
                trend: a.trendPercent,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _kpi(
                '${a.activeCustomers}',
                'Active streaks',
                AppColors.success,
              ),
            ),
          ],
        ),
      );

  /// One headline number. [trend] adds the week-on-week arrow beneath it.
  ///
  /// The value is wrapped in a [FittedBox]: three of these share the width of
  /// the narrowest phone, and a four-digit count at accessibility text sizes is
  /// wider than the third it gets. Scaling the numeral down keeps it whole
  /// where a fixed size would clip it.
  Widget _kpi(String value, String label, Color color, {int? trend}) =>
      Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: Radii.lgAll,
          border: hairline,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppText.heading(
                  size: 26,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.body(size: 11),
            ),
            if (trend != null) ...[
              const SizedBox(height: Spacing.xs),
              _trendChip(trend),
            ],
          ],
        ),
      );

  /// Week-on-week change. Flat is its own state — an unchanged week is news,
  /// and rendering it as a green "+0%" is not true.
  Widget _trendChip(int percent) {
    final (icon, color) = switch (percent) {
      > 0 => (Icons.arrow_upward, AppColors.success),
      < 0 => (Icons.arrow_downward, AppColors.error),
      _ => (Icons.remove, AppColors.muted2),
    };

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            '${percent.abs()}%',
            style: AppText.body(size: 11, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  // ---- shortcuts -----------------------------------------------------------

  Widget _quickActions(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _quickAction(
                  Icons.qr_code_2,
                  'Show QR',
                  () => context.go(Routes.ownerQrCode),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _quickAction(
                  Icons.confirmation_number_outlined,
                  'Verify voucher',
                  () => context.push(Routes.verifyVoucher),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: _quickAction(
                  Icons.tune,
                  'Edit rewards',
                  () => context.go(Routes.ownerRewards),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _quickAction(
                  Icons.people_outline,
                  'Customers',
                  () => context.go(Routes.ownerCustomers),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            // Minimum rather than fixed: the label has to stay inside the box
            // when the text setting grows it.
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: Radii.mdAll,
              border: hairline,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// Where the free month stands. Status only — no price, no way to pay. See
  /// showsPricingInApp in domain/subscription.dart for why.
  Widget _trialStatus(int daysLeft) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.06),
          borderRadius: Radii.lgAll,
          border: Border.all(color: AppColors.success.withValues(alpha: 0.19)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.card_giftcard_outlined,
              size: 20,
              color: AppColors.success,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                daysLeft == 1
                    ? 'Last day of your free month'
                    : '$daysLeft days left in your free month',
                style: AppText.body(size: 13, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  // ---- attention -----------------------------------------------------------

  /// Customers whose streak ends today or tomorrow. Unlike the lapsed banner,
  /// this one is still winnable — which is why it sits above it.
  Widget _atRiskBanner(int count, VoidCallback onTap) => _banner(
        onTap: onTap,
        color: AppColors.warning,
        icon: Icons.timer_outlined,
        title: '$count ${count == 1 ? 'streak ends' : 'streaks end'} within a day',
        subtitle: 'Still savable — one visit keeps them going.',
      );

  Widget _lapsedBanner(int count, VoidCallback onTap) => _banner(
        onTap: onTap,
        color: AppColors.error,
        icon: Icons.person_remove_outlined,
        title: '$count ${count == 1 ? 'customer has' : 'customers have'} lapsed',
        subtitle: 'Review the segment and plan a win-back offer.',
      );

  Widget _banner({
    required VoidCallback onTap,
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      Semantics(
        button: true,
        label: '$title. $subtitle',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: Radii.lgAll,
              border: Border.all(color: color.withValues(alpha: 0.19)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.heading(size: 14)),
                      Text(subtitle, style: AppText.body(size: 12)),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.muted2,
                ),
              ],
            ),
          ),
        ),
      );

  // ---- cards ---------------------------------------------------------------

  Widget _visitsCard(OwnerAnalytics a) => _card(
        'Visits (30 days)',
        // The chart is deliberately axis-free — it answers "are we trending
        // up" at a glance — but with no scale at all a peak of 3 and a peak of
        // 300 draw the same picture. The caption is the scale. Both halves are
        // counts, so both are worded as counts: "busiest day 5" read like a
        // date.
        caption: '${a.visitsInWindow} visits · best day ${a.busiestDayVisits}',
        children: [
          VisitsSparkline(counts: a.dailyVisits),
          const SizedBox(height: Spacing.sm),
          Text(
            _trendSentence(a),
            style: AppText.body(size: 12, color: AppColors.muted2),
          ),
        ],
      );

  String _trendSentence(OwnerAnalytics a) {
    final trend = a.trendPercent;
    if (trend == null) {
      return '${a.visitsThisPeriod} '
          '${a.visitsThisPeriod == 1 ? 'visit' : 'visits'} this week. '
          'No previous week to compare against yet.';
    }
    if (trend == 0) {
      return 'Level with last week at ${a.visitsThisPeriod} '
          '${a.visitsThisPeriod == 1 ? 'visit' : 'visits'}.';
    }
    return '${trend > 0 ? 'Up' : 'Down'} ${trend.abs()}% on last week '
        '(${a.visitsThisPeriod} vs ${a.visitsPreviousPeriod}).';
  }

  Widget _busiestTimesCard(OwnerAnalytics a) {
    final weekday = a.busiestWeekday;
    final hour = a.busiestHour;

    return _card(
      'Busiest times',
      caption: weekday == null
          ? null
          : '${weekdayLabel(weekday)}${hour == null ? '' : ' · ${hourRangeLabel(hour)}'}',
      children: [
        WeekdayBars(counts: a.visitsByWeekday),
        const SizedBox(height: Spacing.sm),
        Text(
          weekday == null
              ? 'Once customers start checking in, this shows which days and '
                  'hours to staff for.'
              : 'Your busiest hour is ${hourRangeLabel(hour!)}, and '
                  '${weekdayFullLabel(weekday)} is your busiest day. '
                  "Counted in your phone's timezone.",
          style: AppText.body(size: 12, color: AppColors.muted2),
        ),
      ],
    );
  }

  Widget _customerBaseCard(OwnerAnalytics a) => _card(
        'Customer base',
        children: [
          Row(
            children: [
              Expanded(child: _miniStat('${a.totalCustomers}', 'Customers')),
              Expanded(
                child: _miniStat(
                  '${a.newCustomersThisPeriod}',
                  'New this week',
                  color: a.newCustomersThisPeriod > 0
                      ? AppColors.success
                      : AppColors.ink,
                ),
              ),
              Expanded(
                child: _miniStat(
                  '${a.uniqueVisitorsThisPeriod}',
                  'Seen this week',
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: Spacing.md),
          _statRow(
            'Repeat rate',
            a.totalCustomers == 0 ? '—' : '${a.repeatRatePercent}%',
          ),
          const SizedBox(height: Spacing.sm),
          _statRow(
            'Average visits per customer',
            a.totalCustomers == 0
                ? '—'
                : a.visitsPerCustomer.toStringAsFixed(1),
          ),
          const SizedBox(height: Spacing.sm),
          _statRow(
            'Longest live streak',
            a.longestActiveStreak == 0
                ? '—'
                : '${a.longestActiveStreak} days',
          ),
          if (a.topCustomerName != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              '${a.topCustomerName} is your longest-running regular.',
              style: AppText.body(size: 12, color: AppColors.muted2),
            ),
          ],
        ],
      );

  /// What the reward programme has cost and what it still promises.
  /// Outstanding is the number that matters most: unredeemed, unexpired
  /// vouchers are a discount the shop has committed to and could be handed any
  /// day.
  Widget _rewardCard(OwnerAnalytics a) => _card(
        'Reward programme',
        children: [
          Row(
            children: [
              Expanded(child: _miniStat('${a.vouchersEarned}', 'Earned')),
              Expanded(child: _miniStat('${a.vouchersRedeemed}', 'Redeemed')),
              Expanded(
                child: _miniStat(
                  '${a.vouchersOutstanding}',
                  'Outstanding',
                  color: a.vouchersOutstanding == 0
                      ? AppColors.ink
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: Spacing.md),
          _statRow(
            'Redemption rate',
            a.vouchersEarned == 0 ? '—' : '${a.redemptionRatePercent}%',
          ),
          const SizedBox(height: Spacing.sm),
          _statRow(
            'Average discount redeemed',
            a.vouchersRedeemed == 0 ? '—' : '${a.averageDiscountPercent}%',
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            _rewardSentence(a),
            style: AppText.body(size: 12, color: AppColors.muted2),
          ),
        ],
      );

  String _rewardSentence(OwnerAnalytics a) {
    if (a.vouchersOutstanding == 0) {
      return 'No unredeemed rewards are outstanding.';
    }
    final plural = a.vouchersOutstanding == 1 ? '' : 's';
    if (a.vouchersExpiringSoon == 0) {
      return '${a.vouchersOutstanding} reward$plural could still be claimed '
          'before expiry.';
    }
    // Worth saying out loud: these are discounts already promised that are
    // about to stop being owed, which is both a cost and a reason to visit.
    return '${a.vouchersOutstanding} reward$plural outstanding, '
        '${a.vouchersExpiringSoon} expiring within $expiringSoonDays days.';
  }

  Widget _segmentsCard(OwnerAnalytics a) {
    // Read once: `segments` builds its list on every call, and asking for it
    // again inside the loop just to find the last band rebuilt it per row.
    final segments = a.segments;

    return _card(
      'Customer segments',
      children: [
        for (final seg in segments) ...[
          _segmentRow(seg, a.totalCustomers),
          if (seg.band != segments.last.band) const SizedBox(height: Spacing.md),
        ],
      ],
    );
  }

  /// One band of the customer base.
  ///
  /// Laid out as a label row above a full-width bar, rather than the label,
  /// bar and count all on one line. The old version gave the label a fixed
  /// 124pt box and the count a fixed 24pt one, both of which "Regulars (30+
  /// days)" and a three-digit count overflow well before the largest
  /// accessibility text size.
  Widget _segmentRow(Segment seg, int total) {
    final (color, icon) = _bandStyle(seg.band);

    return Semantics(
      label: '${seg.band.label}: ${seg.count}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(seg.band.label, style: AppText.body(size: 13)),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '${seg.count}',
                style: AppText.heading(size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: AppColors.line2),
                  ),
                  // Positioned.fill so the fraction box gets a tight height: a
                  // bare ColoredBox collapses to nothing under a Stack's loose
                  // constraints.
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      // A floor keeps a nonzero segment visible rather than
                      // rendering as an empty track; an actual zero stays empty.
                      widthFactor: total == 0 || seg.count == 0
                          ? 0.0
                          : (seg.count / total).clamp(0.04, 1.0),
                      child: ColoredBox(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _bandStyle(StreakBand band) => switch (band) {
        StreakBand.regulars => (
            AppColors.success,
            Icons.workspace_premium_outlined
          ),
        StreakBand.growing => (AppColors.primary, Icons.trending_up),
        StreakBand.starting => (AppColors.warning, Icons.person_add_alt),
        StreakBand.lapsed => (AppColors.error, Icons.schedule),
      };

  // ---- shared card chrome --------------------------------------------------

  Widget _card(
    String title, {
    String? caption,
    required List<Widget> children,
  }) =>
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap rather than Row: at large text sizes the caption cannot
            // share a line with the title on a narrow phone, and it should
            // drop beneath instead of overflowing.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Spacing.sm,
              runSpacing: 2,
              children: [
                Text(title, style: AppText.heading(size: 15)),
                if (caption != null)
                  Text(
                    caption,
                    style: AppText.body(size: 12, color: AppColors.muted2),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            ...children,
          ],
        ),
      );

  Widget _miniStat(String value, String label, {Color color = AppColors.ink}) =>
      Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppText.heading(
                size: 20,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.body(size: 11),
          ),
        ],
      );

  Widget _statRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppText.body(size: 13))),
          const SizedBox(width: Spacing.sm),
          Text(value, style: AppText.heading(size: 14, weight: FontWeight.w600)),
        ],
      );
}
