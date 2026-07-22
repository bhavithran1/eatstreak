import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/shop.dart';
import '../../domain/discount_plans.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/gradient_button.dart';

/// Details collected on the register-shop screen, carried into plan selection.
class ChoosePlanArgs {
  const ChoosePlanArgs({
    required this.shopName,
    required this.category,
    this.description = '',
    this.sourceQr = '',
  });

  final String shopName;
  final ShopCategory category;
  final String description;
  final String sourceQr;
}

const _planIcons = <IconData>[
  Icons.speed_outlined,
  Icons.swap_horiz,
  Icons.workspace_premium_outlined,
  Icons.local_cafe_outlined,
  Icons.calendar_month_outlined,
];

/// Shop registration, step two: pick a reward ladder. Nothing is written until
/// Confirm, and every threshold stays editable afterwards on the Rewards screen.
class ChoosePlanScreen extends ConsumerStatefulWidget {
  const ChoosePlanScreen({super.key, required this.args});

  final ChoosePlanArgs args;

  @override
  ConsumerState<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends ConsumerState<ChoosePlanScreen> {
  String? _selectedId;
  bool _submitting = false;

  DiscountPlan? get _selected => planById(_selectedId);

  Future<void> _confirm() async {
    final plan = _selected;
    final user = ref.read(storeControllerProvider).value?.currentUser;
    if (plan == null || user == null || _submitting) return;

    setState(() => _submitting = true);

    final shopId = 'shop_${generateId()}';
    final shop = Shop(
      id: shopId,
      name: widget.args.shopName,
      // Security rules enforce ownerId == request.auth.uid on creation, so this
      // must be the signed-in user and nothing else.
      ownerId: user.id,
      category: widget.args.category,
      emoji: '',
      description: widget.args.description,
      address: '',
      rewardTiers: plan.rewardTiersFor(shopId),
      streakWindowDays: plan.streakWindowDays,
      createdAt: todayString(),
      sourceQR: widget.args.sourceQr.isEmpty ? null : widget.args.sourceQr,
      planId: plan.id,
    );

    try {
      final store = ref.read(storeControllerProvider.notifier);
      await store.registerShop(shop);
      if (user.role != UserRole.owner) {
        await store.switchRole(UserRole.owner);
      }
      await store.refresh();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
      }
      return;
    }

    if (mounted) context.go(Routes.ownerDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          AppScreen(
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(Routes.ownerDashboard),
            title: 'Choose a reward plan',
            // Room for the floating confirm bar.
            bottomPadding: selected == null ? Spacing.xxl : 140,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Pick a discount strategy for '),
                    TextSpan(
                      text: widget.args.shopName,
                      style: AppText.body(
                        size: 15,
                        weight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(text: '. You can customize tiers later.'),
                  ],
                ),
                style: AppText.body(size: 15, height: 1.45),
              ),
              const SizedBox(height: Spacing.lg),
              for (var i = 0; i < discountPlans.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _PlanCard(
                    plan: discountPlans[i],
                    icon: _planIcons[i % _planIcons.length],
                    selected: _selectedId == discountPlans[i].id,
                    onSelect: () =>
                        setState(() => _selectedId = discountPlans[i].id),
                  ),
                ),
            ],
          ),
          if (selected != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _confirmBar(selected),
            ),
        ],
      ),
    );
  }

  Widget _confirmBar(DiscountPlan plan) {
    final tierCount = plan.visitTiers.length + plan.streakTiers.length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        MediaQuery.paddingOf(context).bottom + Spacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: AppText.heading(size: 16)),
                Text(
                  '$tierCount tiers  ·  ${plan.streakWindowDays}-day window',
                  style: AppText.body(size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          GradientButton(
            label: 'Confirm',
            busy: _submitting,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.icon,
    required this.selected,
    required this.onSelect,
  });

  final DiscountPlan plan;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: Radii.lgAll,
          border: Border.all(
            color: selected ? plan.color : AppColors.line,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? Shadows.card : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selected) ...[
              _selectedBadge(),
              const SizedBox(height: Spacing.sm),
            ],
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: plan.color.withValues(alpha: 0.09),
                    borderRadius: Radii.mdAll,
                  ),
                  child: Icon(icon, size: 23, color: plan.color),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name, style: AppText.heading(size: 17)),
                      Text(plan.tagline, style: AppText.body(size: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(plan.description, style: AppText.body(size: 14, height: 1.45)),
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _fact('${plan.stats.avgDiscountGiven}%', 'avg. reward'),
                _fact('${plan.streakWindowDays}d', 'return window'),
                _fact(
                  '${plan.visitTiers.length + plan.streakTiers.length}',
                  'reward tiers',
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            const Divider(color: AppColors.line, height: 1),
            const SizedBox(height: Spacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _tierColumn(
                      'Visit milestones',
                      plan.visitTiers,
                      'visits',
                    ),
                  ),
                  const VerticalDivider(color: AppColors.line, width: 25),
                  Expanded(
                    child: _tierColumn(
                      'Streak rewards',
                      plan.streakTiers,
                      'days',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'You can edit every threshold and discount after setup.',
                    style: AppText.body(size: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: plan.color,
          borderRadius: Radii.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 14, color: AppColors.primaryInk),
            const SizedBox(width: 4),
            Text(
              'Selected',
              style: AppText.body(
                size: 11,
                weight: FontWeight.w700,
                color: AppColors.primaryInk,
              ),
            ),
          ],
        ),
      );

  Widget _fact(String value, String label) => Column(
        children: [
          Text(value, style: AppText.heading(size: 18)),
          const SizedBox(height: 2),
          Text(label, style: AppText.body(size: 11)),
        ],
      );

  Widget _tierColumn(String title, List<PlanTier> tiers, String unit) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.body(size: 11, weight: FontWeight.w600),
          ),
          const SizedBox(height: Spacing.sm),
          for (final t in tiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: plan.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${t.threshold} $unit',
                      style: AppText.body(size: 12),
                    ),
                  ),
                  Text(
                    '${t.discountPercent}%',
                    style: AppText.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: plan.color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}
