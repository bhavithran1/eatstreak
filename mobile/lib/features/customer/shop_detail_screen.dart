import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/enums.dart';
import '../../domain/streak_service.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_button.dart';
import '../shared/widgets/reward_ladder.dart';
import '../shared/widgets/shop_icon.dart';

/// One shop: its details, the user's standing there, and both reward ladders.
class ShopDetailScreen extends ConsumerWidget {
  const ShopDetailScreen({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storeControllerProvider).value ?? const StoreState();
    final shop = state.shopById(shopId);

    if (shop == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.search_off_outlined,
              title: 'Shop not found',
              subtitle: 'This shop may have been removed, or the QR code is no '
                  'longer valid.',
              actionLabel: 'Back to home',
              onAction: () => context.go(Routes.customerHome),
            ),
          ),
        ),
      );
    }

    final raw = state.streakForShop(shopId);
    final streak = raw == null ? null : refreshStreakAlive(raw, shop);
    final urgency = streak == null ? null : streakUrgency(streak, shop);
    final isDead = urgency == StreakUrgency.dead;

    final best = streak == null
        ? 0
        : [
            bestDiscount(streak, shop, RewardType.visitCount),
            bestDiscount(streak, shop, RewardType.streakDays),
          ].reduce((a, b) => a > b ? a : b);

    final activeVouchers = state.vouchers
        .where((v) => v.shopId == shopId && !v.isRedeemed)
        .length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, shop.name),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  0,
                  Spacing.md,
                  Spacing.md,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  _hero(shop.name, shop.category, shop.address, shop.description),
                  const SizedBox(height: Spacing.lg),
                  if (streak != null)
                    _standing(
                      days: streak.currentStreakDays,
                      visits: streak.totalVisits,
                      longest: streak.longestStreakDays,
                      bestDiscountPercent: best,
                      isDead: isDead,
                      activeVouchers: activeVouchers,
                    )
                  else
                    _noStreak(),
                  const SizedBox(height: Spacing.lg),
                  SurfaceCard(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: RewardLadder(
                      tiers: shop.rewardTiers,
                      currentValue: streak?.currentStreakDays ?? 0,
                      type: RewardType.streakDays,
                      title: 'Streak rewards',
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  SurfaceCard(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: RewardLadder(
                      tiers: shop.rewardTiers,
                      currentValue: streak?.totalVisits ?? 0,
                      type: RewardType.visitCount,
                      title: 'Visit rewards',
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: 12,
                    ),
                    shadow: false,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            'Visit within ${shop.streakWindowDays} '
                            '${shop.streakWindowDays > 1 ? 'days' : 'day'} '
                            'to keep your streak alive.',
                            style: AppText.body(size: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String name) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go(Routes.customerHome),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.heading(size: 17),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      );

  Widget _hero(
    String name,
    ShopCategory category,
    String address,
    String description,
  ) =>
      Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          borderRadius: Radii.xlAll,
          border: Border.all(color: AppColors.ember2.withValues(alpha: 0.08)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.14),
              AppColors.primary.withValues(alpha: 0.035),
              AppColors.card,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShopIcon(
                  category: category,
                  size: 56,
                  variant: ShopIconVariant.accent,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: Radii.pillAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Partner',
                        style: AppText.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(
              name,
              style: AppText.heading(size: 24, weight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              '${category.wire[0].toUpperCase()}${category.wire.substring(1)} · $address',
              style: AppText.body(size: 14),
            ),
            const SizedBox(height: Spacing.sm),
            Text(description, style: AppText.body(size: 14, height: 1.45)),
          ],
        ),
      );

  Widget _standing({
    required int days,
    required int visits,
    required int longest,
    required int bestDiscountPercent,
    required bool isDead,
    required int activeVouchers,
  }) =>
      SurfaceCard(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDead ? AppColors.card2 : AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    isDead ? Icons.pause : Icons.monitor_heart_outlined,
                    size: 26,
                    color: isDead ? AppColors.muted : AppColors.primaryInk,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$days',
                      style: AppText.heading(
                        size: 48,
                        weight: FontWeight.w700,
                        color: AppColors.ember2,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Text(
                      isDead ? 'streak broken' : 'day streak',
                      style: AppText.body(size: 16),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            const Divider(color: AppColors.line, height: 1),
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('$visits', 'visits'),
                _miniStat('$longest', 'best streak'),
                _miniStat(
                  '$bestDiscountPercent%',
                  'best discount',
                  color: AppColors.success,
                ),
              ],
            ),
            if (activeVouchers > 0) ...[
              const SizedBox(height: Spacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ember2.withValues(alpha: 0.06),
                  borderRadius: Radii.smAll,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number,
                      size: 16,
                      color: AppColors.ember2,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '$activeVouchers active '
                      '${activeVouchers > 1 ? 'vouchers' : 'voucher'}',
                      style: AppText.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.ember2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _miniStat(String value, String label, {Color color = AppColors.ink}) =>
      Column(
        children: [
          Text(value, style: AppText.heading(size: 20, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppText.body(size: 12)),
        ],
      );

  Widget _noStreak() => SurfaceCard(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.qr_code_2,
                size: 25,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text('No visits yet', style: AppText.heading(size: 18)),
            const SizedBox(height: Spacing.xs),
            Text(
              'Scan the QR code at this shop to start a streak!',
              textAlign: TextAlign.center,
              style: AppText.body(size: 14, height: 1.4),
            ),
          ],
        ),
      );

  Widget _bottomBar(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.sm,
          Spacing.md,
          MediaQuery.paddingOf(context).bottom + Spacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: GradientButton(
          label: 'Scan to check in',
          icon: Icons.qr_code_scanner,
          expand: true,
          onPressed: () => context.go(Routes.scanner),
        ),
      );
}
