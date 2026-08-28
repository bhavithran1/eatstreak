import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../shared/widgets/app_toast.dart';
import '../../core/utils/errors.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/profile_widgets.dart';
import '../shared/widgets/role_switcher.dart';
import '../shared/widgets/store_scope.dart';
import 'how_it_works_sheet.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StoreScope(builder: (context, state) => _body(context, ref, state));

  Widget _body(BuildContext context, WidgetRef ref, StoreState state) {
    final user = state.currentUser;
    final isDemo = ref.watch(isDemoModeProvider);

    final shopsVisited = state.streaks.map((s) => s.shopId).toSet().length;
    final totalVisits =
        state.streaks.fold<int>(0, (sum, s) => sum + s.totalVisits);
    final activeStreaks = state.streaks.where((s) => s.isStreakAlive).length;

    return AppScreen(
      title: 'Profile',
      children: [
        ProfileHeader(name: user?.name ?? '', email: user?.email ?? ''),
        const SizedBox(height: Spacing.xl),
        ProfileStatsGrid(
          stats: [
            (
              label: 'Shops visited',
              value: '$shopsVisited',
              icon: Icons.storefront_outlined
            ),
            (
              label: 'Total visits',
              value: '$totalVisits',
              icon: Icons.place_outlined
            ),
            (
              label: 'Active streaks',
              value: '$activeStreaks',
              icon: Icons.monitor_heart_outlined
            ),
            (
              label: 'Rewards earned',
              value: '${state.vouchers.length}',
              icon: Icons.confirmation_number_outlined
            ),
            (
              label: 'Embers',
              value: '${user?.embers ?? 0}',
              icon: Icons.local_fire_department_outlined
            ),
          ],
        ),
        const SizedBox(height: Spacing.xl),
        Text('Account mode', style: AppText.heading(size: 16)),
        const SizedBox(height: Spacing.sm),
        RoleSwitcher(
          currentRole: UserRole.customer,
          onSwitch: (role) => _switchRole(context, ref, role),
        ),
        const SizedBox(height: Spacing.lg),
        SettingsGroup(
          rows: [
            SettingsRow(
              icon: Icons.help_outline,
              label: 'How streaks work',
              onTap: () => showHowItWorks(context),
            ),
            SettingsRow(
              icon: Icons.camera_alt_outlined,
              label: 'Camera permissions',
              onTap: openAppSettings,
            ),
            SettingsRow(
              icon: Icons.verified_user_outlined,
              label: 'Privacy & data',
              onTap: () => showInfoDialog(
                context,
                'Your data',
                isDemo
                    ? 'This is a demo build. Your streaks and rewards are '
                        'stored only on this device and never leave it.'
                    : 'Your streaks and rewards are stored securely in the '
                        'cloud and synced to your EatStreak account across '
                        'devices.',
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xl),
        DangerButton(
          label: isDemo ? 'Reset demo data' : 'Sign out',
          onPressed: () => confirmSignOut(context, ref, isDemo: isDemo),
        ),
        const SizedBox(height: Spacing.xl),
        Center(
          child: Text(
            'EatStreak · Version 1.0.0',
            style: AppText.body(size: 12, color: AppColors.muted2),
          ),
        ),
      ],
    );
  }

  /// Switch which side of the app this account is looking at.
  ///
  /// Wrapped, because it writes to Firestore and can fail. It used to be a bare
  /// `await` followed by a `context.go`: a rejected write threw, the navigation
  /// line never ran, and the tap did nothing at all with nothing on screen to
  /// say why — which is indistinguishable from a dead button. The role field
  /// was in fact immutable in the security rules, so on the live backend this
  /// was *always* the outcome, while demo mode wrote locally and worked.
  Future<void> _switchRole(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
  ) async {
    if (role == UserRole.customer) return;
    try {
      await ref
          .read(storeControllerProvider.notifier)
          .switchRole(role)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (context.mounted) {
        AppToast.show(
          context,
          "Couldn't reach the server. Check your connection and try again.",
          type: ToastType.error,
        );
      }
      return;
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
      }
      return;
    }
    // Only on success — navigating regardless lands you on the other shell
    // while the account still says otherwise.
    if (context.mounted) context.go(Routes.ownerDashboard);
  }
}
