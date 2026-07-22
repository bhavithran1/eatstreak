import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../data/models/enums.dart';
import '../../domain/check_in_flow.dart';
import '../../state/auth_controller.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/brand_mark.dart';
import 'scan_success_screen.dart';
import 'shop_not_found_screen.dart';

/// Deep-link entry point for `https://<host>/c/<shopId>` and
/// `eatstreak://check-in/<shopId>`.
///
/// By the time this builds, the router's auth gate has already guaranteed a
/// signed-in, onboarded user — a signed-out link is parked as a pending
/// check-in and resumed after sign-in. All that's left is to run it once the
/// store has loaded, and land on the same destinations as the in-app scanner.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, required this.shopId});

  final String shopId;

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  /// A deep link can rebuild this screen several times as the store settles;
  /// the check-in itself must happen exactly once.
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(storeControllerProvider, (_, next) {
      if (next.hasValue) _maybeRun();
    });

    // Covers the case where the store was already loaded on first build.
    if (ref.read(storeControllerProvider).hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRun());
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(
              size: 56,
              color: AppColors.primary,
              accent: AppColors.ember1,
            ),
            const SizedBox(height: Spacing.lg),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Checking you in…',
              style: AppText.body(size: 15, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeRun() async {
    if (_handled || !mounted) return;
    _handled = true;

    // An owner scanning their own code has no streak to advance; say so rather
    // than failing silently.
    if (ref.read(authControllerProvider).role == UserRole.owner) {
      AppToast.show(
        context,
        'Switch to customer mode to check in.',
        type: ToastType.info,
      );
      context.go(Routes.ownerDashboard);
      return;
    }

    CheckInOutcome outcome;
    try {
      outcome = await runCheckIn(
        widget.shopId,
        ref.read(storeControllerProvider.notifier).checkIn,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
      context.go(Routes.customerHome);
      return;
    }

    if (!mounted) return;

    switch (outcome) {
      case CheckInAlreadyToday():
        AppToast.show(context, outcome.message, type: ToastType.info);
        context.go(Routes.customerHome);

      case CheckInUnknownShop():
        context.go(
          Routes.shopNotFound,
          extra: ShopNotFoundArgs(qrData: outcome.qrData),
        );

      case CheckInRecorded():
        context.go(
          Routes.scanSuccess,
          extra: ScanSuccessArgs(
            shopId: outcome.shopId,
            streakDays: outcome.streakDays,
            totalVisits: outcome.totalVisits,
            newVoucherCount: outcome.newVoucherCount,
          ),
        );
    }
  }
}
