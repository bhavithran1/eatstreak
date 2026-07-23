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
import '../shared/widgets/store_scope.dart';

class OwnerProfileScreen extends ConsumerWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StoreScope(builder: (context, state) => _body(context, ref, state));

  Widget _body(BuildContext context, WidgetRef ref, StoreState state) {
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
        if (shop != null) ...[
          _action(
            context,
            icon: Icons.storefront_outlined,
            title: 'Edit shop details',
            subtitle: 'Name, category, address and description',
            route: Routes.editShop,
          ),
          const SizedBox(height: Spacing.sm),
        ],
        // Only offered when there is no shop yet: StoreState.ownedShop returns
        // the first match, so a second shop would be invisible everywhere in
        // the app. Inviting the owner to create one would silently swallow the
        // work.
        if (shop == null) _registerShopAction(context),
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

  Widget _registerShopAction(BuildContext context) => _action(
        context,
        icon: Icons.add_circle_outline,
        title: 'Register your shop',
        subtitle: 'Scan a QR or enter details to add a shop',
        route: Routes.registerShop,
      );

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) =>
      Semantics(
        button: true,
        label: '$title. $subtitle',
        child: GestureDetector(
          onTap: () => context.push(route),
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
                  child: Icon(icon, size: 22, color: AppColors.ember2),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.heading(size: 15)),
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
