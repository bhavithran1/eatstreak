import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class OwnerProfileScreen extends ConsumerWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storeControllerProvider).value ?? const StoreState();
    final user = state.currentUser;
    final shop = state.ownedShop;
    final isDemo = ref.watch(isDemoModeProvider);

    return AppScreen(
      title: 'Profile',
      children: [
        ProfileHeader(name: user?.name ?? '', email: user?.email ?? ''),
        if (shop != null) ...[
          const SizedBox(height: Spacing.sm),
          Center(child: _shopBadge(shop.name)),
        ],
        const SizedBox(height: Spacing.xl),
        _registerShopAction(context, hasShop: shop != null),
        const SizedBox(height: Spacing.lg),
        Text('Account mode', style: AppText.heading(size: 16)),
        const SizedBox(height: Spacing.sm),
        RoleSwitcher(
          currentRole: UserRole.owner,
          onSwitch: (role) => _switchRole(context, ref, role),
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

  Widget _shopBadge(String name) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.ember2.withValues(alpha: 0.08),
          borderRadius: Radii.pillAll,
          border: Border.all(color: AppColors.ember2.withValues(alpha: 0.19)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: AppText.heading(
                size: 14,
                weight: FontWeight.w500,
                color: AppColors.ember2,
              ),
            ),
          ],
        ),
      );

  Widget _registerShopAction(BuildContext context, {required bool hasShop}) =>
      GestureDetector(
        onTap: () => context.push(Routes.registerShop),
        behavior: HitTestBehavior.opaque,
        child: SurfaceCard(
          shadow: false,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.ember2.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: AppColors.ember2,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasShop ? 'Register another shop' : 'Register your shop',
                      style: AppText.heading(size: 15),
                    ),
                    Text(
                      'Scan a QR or enter details to add a shop',
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
      );

  Future<void> _switchRole(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
  ) async {
    if (role == UserRole.owner) return;
    await ref.read(storeControllerProvider.notifier).switchRole(role);
    if (context.mounted) context.go(Routes.customerHome);
  }
}
