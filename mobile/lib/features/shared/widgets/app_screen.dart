import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// The standard screen frame: dark background, safe area, a scrolling body with
/// pull-to-refresh, and the app's title treatment. Every screen uses this, which
/// is what keeps headers and gutters identical across the app.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.children,
    this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.onRefresh,
    this.onBack,
    this.floatingActionButton,
    this.bottomPadding = Spacing.xxl,
    this.controller,
    this.backgroundColor = AppColors.bg,
  });

  /// Slivers-free: a plain list of widgets laid out in a column.
  final List<Widget> children;
  final String? title;

  /// Small all-caps line above the title.
  final String? eyebrow;
  final String? subtitle;

  /// Action pinned to the right of the title row.
  final Widget? trailing;
  final Future<void> Function()? onRefresh;

  /// Renders a back chevron above the title when provided.
  final VoidCallback? onBack;
  final Widget? floatingActionButton;
  final double bottomPadding;
  final ScrollController? controller;

  /// Set transparent to let a caller paint its own backdrop behind the screen.
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.md,
        bottomPadding,
      ),
      physics: onRefresh == null
          ? const BouncingScrollPhysics()
          : const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        if (onBack != null) ...[
          _BackButton(onTap: onBack!),
          const SizedBox(height: Spacing.sm),
        ],
        if (title != null) ...[
          _Header(
            title: title!,
            eyebrow: eyebrow,
            subtitle: subtitle,
            trailing: trailing,
          ),
          const SizedBox(height: Spacing.lg),
        ],
        ...children,
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: false,
        child: onRefresh == null
            ? body
            : RefreshIndicator(
                onRefresh: onRefresh!,
                color: AppColors.primary,
                backgroundColor: AppColors.card,
                child: body,
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!.toUpperCase(), style: AppText.eyebrow),
                const SizedBox(height: 6),
              ],
              Text(title, style: AppText.screenTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: AppText.body(size: 14, height: 1.4)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Spacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Back',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: Radii.mdAll,
              border: hairline,
            ),
            child: const Icon(Icons.arrow_back, size: 20, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// The app's standard raised panel. Cards across every screen share it so
/// padding, radius and border never drift apart.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.md),
    this.color = AppColors.card,
    this.borderColor,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: Radii.lgAll,
          border: borderColor == null
              ? hairline
              : Border.all(color: borderColor!),
          boxShadow: shadow ? Shadows.card : null,
        ),
        child: child,
      );
}

/// A labelled number. Used in KPI rows on the dashboard and profile screens.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = AppColors.ink,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(height: Spacing.sm),
          ],
          Text(value, style: AppText.stat(size: 24, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppText.body(size: 12)),
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing action, e.g. "Your streaks · All".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.sectionTitle)),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xs,
                  vertical: Spacing.xs,
                ),
                child: Text(
                  actionLabel!,
                  style: AppText.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
