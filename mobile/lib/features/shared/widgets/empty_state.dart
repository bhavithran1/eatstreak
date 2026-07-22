import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'gradient_button.dart';

/// Shown wherever a list has nothing in it yet. Always says what the user can
/// do next rather than just reporting emptiness.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.auto_awesome_outlined,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.xxl,
        horizontal: Spacing.xl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: Radii.lgAll,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.heading(size: 18, weight: FontWeight.w600),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppText.body(size: 14, height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Spacing.lg),
            GradientButton(
              label: actionLabel!,
              onPressed: onAction,
              size: GradientButtonSize.sm,
            ),
          ],
        ],
      ),
    );
  }
}
