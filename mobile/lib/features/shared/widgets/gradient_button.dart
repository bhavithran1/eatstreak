import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

enum GradientButtonSize { sm, md, lg }

enum GradientButtonVariant { gradient, outline }

/// The app's primary CTA. Springs slightly on press, matching the Reanimated
/// behaviour in the Expo original.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = GradientButtonSize.md,
    this.variant = GradientButtonVariant.gradient,
    this.icon,
    this.busy = false,
    this.expand = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final GradientButtonSize size;
  final GradientButtonVariant variant;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  ({double vertical, double horizontal, double fontSize}) get _metrics =>
      switch (widget.size) {
        GradientButtonSize.sm => (vertical: 10, horizontal: 20, fontSize: 14),
        GradientButtonSize.md => (vertical: 14, horizontal: 28, fontSize: 16),
        GradientButtonSize.lg => (vertical: 18, horizontal: 36, fontSize: 18),
      };

  @override
  Widget build(BuildContext context) {
    final m = _metrics;
    final isOutline = widget.variant == GradientButtonVariant.outline;
    final foreground = isOutline ? AppColors.ink : AppColors.primaryInk;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy)
          SizedBox(
            width: m.fontSize + 2,
            height: m.fontSize + 2,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: m.fontSize + 2, color: foreground),
            const SizedBox(width: Spacing.sm),
          ],
          Text(
            widget.label,
            style: AppText.heading(
              size: m.fontSize,
              weight: FontWeight.w600,
              color: foreground,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _enabled ? 1 : 0.5,
            duration: const Duration(milliseconds: 120),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: m.vertical,
                horizontal: m.horizontal,
              ),
              decoration: BoxDecoration(
                gradient: isOutline ? null : AppColors.gradient,
                borderRadius: Radii.mdAll,
                border: isOutline
                    ? Border.all(color: AppColors.line2, width: 1.5)
                    : null,
                boxShadow: isOutline || !_enabled ? null : Shadows.primaryGlow,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
