import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';

/// One account, two views. Sits on both profile screens.
class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({
    super.key,
    required this.currentRole,
    required this.onSwitch,
  });

  final UserRole currentRole;
  final ValueChanged<UserRole> onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.xs),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: Radii.mdAll,
        border: hairline,
      ),
      child: Row(
        children: [
          _option(UserRole.customer, Icons.person_outline, 'Customer'),
          _option(UserRole.owner, Icons.storefront_outlined, 'Shop Owner'),
        ],
      ),
    );
  }

  Widget _option(UserRole role, IconData icon, String label) {
    final active = currentRole == role;
    final color = active ? AppColors.primaryInk : AppColors.muted;

    return Expanded(
      child: GestureDetector(
        onTap: active ? null : () => onSwitch(role),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: Radii.smAll,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.heading(
                  size: 14,
                  weight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
