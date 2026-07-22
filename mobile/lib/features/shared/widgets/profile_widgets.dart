/// Pieces shared by the customer and owner profile screens. Both screens show
/// the same avatar block, stat grid and settings list; only the numbers differ.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/auth_controller.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            gradient: AppColors.gradient,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isEmpty ? '?' : initialOf(name),
            style: AppText.heading(
              size: 32,
              weight: FontWeight.w700,
              color: AppColors.primaryInk,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(name, style: AppText.heading(size: 22, weight: FontWeight.w700)),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(email, style: AppText.body(size: 14)),
        ],
      ],
    );
  }
}

typedef ProfileStat = ({String label, String value, IconData icon});

class ProfileStatsGrid extends StatelessWidget {
  const ProfileStatsGrid({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - Spacing.sm) / 2;

        return Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: Radii.lgAll,
                    border: hairline,
                  ),
                  child: Column(
                    children: [
                      Icon(stat.icon, size: 20, color: AppColors.primary),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        stat.value,
                        style: AppText.heading(
                          size: 28,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        stat.label,
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SettingsRow {
  const SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.rows});

  final List<SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: Radii.lgAll,
        border: hairline,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 48),
                child: Divider(height: 1, color: AppColors.line),
              ),
            _row(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(SettingsRow row) => GestureDetector(
        onTap: row.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          child: Row(
            children: [
              Icon(row.icon, size: 20, color: AppColors.muted),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  row.label,
                  style: AppText.body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (row.trailingText != null) ...[
                Text(row.trailingText!, style: AppText.body(size: 13)),
                const SizedBox(width: Spacing.sm),
              ],
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.muted2,
              ),
            ],
          ),
        ),
      );
}

/// Outlined destructive action — sign out, reset demo data.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: Radii.mdAll,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: AppText.heading(
            size: 14,
            weight: FontWeight.w500,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}

Future<void> showInfoDialog(
  BuildContext context,
  String title,
  String message,
) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card2,
        shape: RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text(title, style: AppText.heading(size: 18)),
        content: Text(message, style: AppText.body(size: 14, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: AppText.body(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );

/// Sign-out confirmation. In demo mode this wipes the sample world, so the
/// wording says so rather than pretending an account is involved.
Future<void> confirmSignOut(
  BuildContext context,
  WidgetRef ref, {
  required bool isDemo,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card2,
      shape: RoundedRectangleBorder(borderRadius: Radii.lgAll),
      title: Text(
        isDemo ? 'Reset demo data' : 'Sign out',
        style: AppText.heading(size: 18),
      ),
      content: Text(
        isDemo
            ? 'This clears the sample streaks, visits and vouchers, and starts '
                'the demo over from onboarding.'
            : 'You can sign back in any time with the same account.',
        style: AppText.body(size: 14, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: AppText.body(size: 14)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            isDemo ? 'Reset' : 'Sign out',
            style: AppText.body(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await ref.read(authControllerProvider.notifier).signOut();
  if (context.mounted) context.go(Routes.splash);
}
