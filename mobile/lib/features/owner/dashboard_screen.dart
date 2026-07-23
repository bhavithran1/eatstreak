import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../data/models/streak.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/store_scope.dart';
import 'widgets/visits_sparkline.dart';

/// The owner's home: today's numbers, the 30-day trend, and who's slipping away.
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
    final visits = state.visits.where((v) => v.shopId == shop.id).toList();
    final streaks = state.streaks.where((s) => s.shopId == shop.id).toList();

    bool isLapsed(Streak s) =>
        daysBetween(s.lastVisitDate, today) > shop.streakWindowDays;

    final lapsed = streaks.where(isLapsed).toList();
    final active = streaks.where((s) => !isLapsed(s)).toList();

    final repeatRate = streaks.isEmpty
        ? 0
        : ((streaks.where((s) => s.totalVisits > 1).length / streaks.length) *
                100)
            .round();

    // What the reward programme has actually cost and promised. Outstanding is
    // the number that matters most: unredeemed, unexpired vouchers are a
    // discount the shop has already committed to and could be handed any day.
    final vouchers = state.vouchers.where((v) => v.shopId == shop.id).toList();
    final redeemed = vouchers.where((v) => v.isRedeemed).toList();
    final outstanding = vouchers
        .where((v) => !v.isRedeemed && daysFromNow(v.expiresAt) > 0)
        .toList();
    final redemptionRate = vouchers.isEmpty
        ? 0
        : ((redeemed.length / vouchers.length) * 100).round();
    final avgDiscount = redeemed.isEmpty
        ? 0
        : (redeemed.fold<int>(0, (sum, v) => sum + v.discountPercent) /
                redeemed.length)
            .round();

    final segments = <({String label, int count, Color color, IconData icon})>[
      (
        label: 'Regulars (30+ days)',
        count: active.where((s) => s.currentStreakDays >= 30).length,
        color: AppColors.success,
        icon: Icons.workspace_premium_outlined,
      ),
      (
        label: 'Growing (7–29 days)',
        count: active
            .where((s) => s.currentStreakDays >= 7 && s.currentStreakDays < 30)
            .length,
        color: AppColors.primary,
        icon: Icons.trending_up,
      ),
      (
        label: 'New (1–6 days)',
        count: active
            .where((s) => s.currentStreakDays >= 1 && s.currentStreakDays < 7)
            .length,
        color: AppColors.warning,
        icon: Icons.person_add_alt,
      ),
      (
        label: 'Lapsed',
        count: lapsed.length,
        color: AppColors.error,
        icon: Icons.schedule,
      ),
    ];

    final dailyCounts = [
      for (var i = 29; i >= 0; i--)
        visits.where((v) => v.timestamp.startsWith(dateNDaysAgo(i))).length,
    ];

    return AppScreen(
      onRefresh: ref.read(storeControllerProvider.notifier).refresh,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TODAY'S OVERVIEW", style: AppText.eyebrow),
                  const SizedBox(height: 2),
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.heading(
                      size: 24,
                      weight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            _liveBadge(),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Expanded(
              child: _kpi(
                '${visits.where((v) => v.timestamp.startsWith(today)).length}',
                'Visits today',
                AppColors.primary,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _kpi('$repeatRate%', 'Repeat rate', AppColors.success),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _kpi(
                '${active.length}',
                'Active streaks',
                AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
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
        if (lapsed.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          _lapsedBanner(
            lapsed.length,
            () => context.go('${Routes.ownerCustomers}?status=lapsed'),
          ),
        ],
        const SizedBox(height: Spacing.md),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Visits (30 days)', style: AppText.heading(size: 15)),
              const SizedBox(height: Spacing.sm),
              VisitsSparkline(counts: dailyCounts),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reward programme', style: AppText.heading(size: 15)),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: _miniStat('${vouchers.length}', 'Earned'),
                  ),
                  Expanded(
                    child: _miniStat('${redeemed.length}', 'Redeemed'),
                  ),
                  Expanded(
                    child: _miniStat(
                      '${outstanding.length}',
                      'Outstanding',
                      color: outstanding.isEmpty
                          ? AppColors.ink
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              const Divider(color: AppColors.line, height: 1),
              const SizedBox(height: Spacing.md),
              _programmeRow(
                'Redemption rate',
                vouchers.isEmpty ? '—' : '$redemptionRate%',
              ),
              const SizedBox(height: Spacing.sm),
              _programmeRow(
                'Average discount redeemed',
                redeemed.isEmpty ? '—' : '$avgDiscount%',
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                outstanding.isEmpty
                    ? 'No unredeemed rewards are outstanding.'
                    : '${outstanding.length} reward'
                        '${outstanding.length == 1 ? '' : 's'} could still be '
                        'claimed before expiry.',
                style: AppText.body(size: 12, color: AppColors.muted2),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer segments', style: AppText.heading(size: 15)),
              const SizedBox(height: Spacing.md),
              for (final seg in segments) ...[
                _segmentRow(seg, streaks.length),
                if (seg != segments.last) const SizedBox(height: Spacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _liveBadge() => Container(
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
            Text(
              'Live',
              style: AppText.body(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );

  Widget _kpi(String value, String label, Color color) => Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: Radii.lgAll,
          border: hairline,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppText.heading(
                size: 26,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.body(size: 11),
            ),
          ],
        ),
      );

  Widget _miniStat(String value, String label, {Color color = AppColors.ink}) =>
      Column(
        children: [
          Text(
            value,
            style: AppText.heading(size: 20, weight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.body(size: 11)),
        ],
      );

  Widget _programmeRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body(size: 13)),
          Text(
            value,
            style: AppText.heading(size: 14, weight: FontWeight.w600),
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
          height: 48,
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
              Text(
                label,
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        ),
      );

  Widget _lapsedBanner(int count, VoidCallback onTap) => Semantics(
        button: true,
        label: '$count ${count == 1 ? 'customer has' : 'customers have'} '
            'lapsed. Review the segment.',
        child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.06),
            borderRadius: Radii.lgAll,
            border: Border.all(color: AppColors.error.withValues(alpha: 0.19)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.person_remove_outlined,
                  size: 20,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ${count == 1 ? 'customer has' : 'customers have'} lapsed',
                      style: AppText.heading(size: 14),
                    ),
                    Text(
                      'Review the segment and plan a win-back offer.',
                      style: AppText.body(size: 12),
                    ),
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

  Widget _segmentRow(
    ({String label, int count, Color color, IconData icon}) seg,
    int total,
  ) =>
      Row(
        children: [
          SizedBox(width: 24, child: Icon(seg.icon, size: 17, color: seg.color)),
          const SizedBox(width: Spacing.sm),
          SizedBox(
            width: 124,
            child: Text(seg.label, style: AppText.body(size: 13)),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: AppColors.line2),
                    ),
                    // Positioned.fill so the fraction box gets a tight height:
                    // a bare ColoredBox collapses to nothing under a Stack's
                    // loose constraints.
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        // A 4% floor keeps a nonzero segment visible rather
                        // than rendering as an empty track.
                        widthFactor: total == 0
                            ? 0.04
                            : (seg.count / total).clamp(0.04, 1.0),
                        child: ColoredBox(color: seg.color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          SizedBox(
            width: 24,
            child: Text(
              '${seg.count}',
              textAlign: TextAlign.right,
              style: AppText.heading(size: 14, color: seg.color),
            ),
          ),
        ],
      );
}
