import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

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

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storeControllerProvider).value ?? const StoreState();
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

  Future<void> _switchRole(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
  ) async {
    if (role == UserRole.customer) return;
    await ref.read(storeControllerProvider.notifier).switchRole(role);
    if (context.mounted) context.go(Routes.ownerDashboard);
  }
}
