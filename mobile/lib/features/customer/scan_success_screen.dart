import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/gradient_button.dart';

/// What the check-in produced, handed to this screen as go_router `extra`.
class ScanSuccessArgs {
  const ScanSuccessArgs({
    required this.shopId,
    required this.streakDays,
    required this.totalVisits,
    required this.newVoucherCount,
  });

  final String shopId;
  final int streakDays;
  final int totalVisits;
  final int newVoucherCount;
}

/// The payoff screen. Everything lands in sequence — check, streak count, shop,
/// stats, vouchers — so the number the user came for is what they see first.
class ScanSuccessScreen extends ConsumerStatefulWidget {
  const ScanSuccessScreen({super.key, required this.args});

  final ScanSuccessArgs args;

  @override
  ConsumerState<ScanSuccessScreen> createState() => _ScanSuccessScreenState();
}

class _ScanSuccessScreenState extends ConsumerState<ScanSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A spring-in that starts at [begin] of the timeline (0..1).
  Animation<double> _pop(double begin) => CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, (begin + 0.35).clamp(0.0, 1.0),
            curve: Curves.elasticOut),
      );

  Animation<double> _fade(double begin) => CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, (begin + 0.25).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      );

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final state = ref.watch(storeControllerProvider).value ?? const StoreState();
    final shop = state.shopById(args.shopId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: const Alignment(0, 0.2),
            colors: [
              AppColors.primary.withValues(alpha: 0.16),
              AppColors.primary.withValues(alpha: 0.035),
              AppColors.bg,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pop(0),
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 38,
                            color: AppColors.primaryInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        'CHECK-IN COMPLETE',
                        style: AppText.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                      ScaleTransition(
                        scale: _pop(0.22),
                        child: Column(
                          children: [
                            Text(
                              '${args.streakDays}',
                              style: AppText.heading(
                                size: 72,
                                weight: FontWeight.w700,
                                color: AppColors.ember2,
                                letterSpacing: -2,
                              ),
                            ),
                            Text(
                              'day streak',
                              style: AppText.body(size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                      FadeTransition(
                        opacity: _fade(0.4),
                        child: Column(
                          children: [
                            Text(
                              shop?.name ?? '',
                              textAlign: TextAlign.center,
                              style: AppText.heading(size: 20),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              args.streakDays == 1
                                  ? 'Your streak starts today. '
                                      "We'll keep track from here."
                                  : "You've kept this going for "
                                      '${args.streakDays} days.',
                              textAlign: TextAlign.center,
                              style: AppText.body(size: 15, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                      FadeTransition(
                        opacity: _fade(0.55),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _statCard('${args.totalVisits}', 'total visits'),
                            const SizedBox(width: Spacing.md),
                            _statCard('${args.streakDays}', 'current streak'),
                          ],
                        ),
                      ),
                      if (args.newVoucherCount > 0) ...[
                        const SizedBox(height: Spacing.lg),
                        FadeTransition(
                          opacity: _fade(0.7),
                          child: _voucherBanner(args.newVoucherCount),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              FadeTransition(
                opacity: _fade(0.75),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.xl,
                    0,
                    Spacing.xl,
                    Spacing.xl,
                  ),
                  child: Column(
                    children: [
                      GradientButton(
                        label: 'View shop',
                        expand: true,
                        onPressed: () =>
                            context.go(Routes.shopDetail(args.shopId)),
                      ),
                      const SizedBox(height: Spacing.sm),
                      GradientButton(
                        label: 'Back to home',
                        expand: true,
                        variant: GradientButtonVariant.outline,
                        onPressed: () => context.go(Routes.customerHome),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label) => Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: Radii.lgAll,
          border: hairline,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppText.heading(size: 28, weight: FontWeight.w700),
            ),
            Text(label, style: AppText.body(size: 12)),
          ],
        ),
      );

  Widget _voucherBanner(int count) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: Radii.mdAll,
          border: Border.all(color: AppColors.success.withValues(alpha: 0.19)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                size: 20,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Text(
                'You earned $count new '
                '${count > 1 ? 'vouchers' : 'voucher'}!',
                style: AppText.heading(size: 15, color: AppColors.success),
              ),
            ),
          ],
        ),
      );
}
