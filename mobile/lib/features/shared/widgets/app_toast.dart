import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

enum ToastType { success, warning, error, info }

extension _ToastStyle on ToastType {
  Color get color => switch (this) {
        ToastType.success => AppColors.success,
        ToastType.warning => AppColors.warning,
        ToastType.error => AppColors.error,
        ToastType.info => AppColors.ember2,
      };

  IconData get icon => switch (this) {
        ToastType.success => Icons.check_circle,
        ToastType.warning => Icons.warning_rounded,
        ToastType.error => Icons.cancel,
        ToastType.info => Icons.info,
      };
}

/// Transient feedback, sliding down from the top the way the Expo Toast did.
///
/// Implemented on the root Overlay rather than a ScaffoldMessenger so it floats
/// above bottom navigation and full-screen surfaces like the scanner.
abstract final class AppToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();

    final entry = OverlayEntry(
      builder: (context) => _ToastView(
        message: message,
        type: type,
        duration: duration,
        onDismiss: dismiss,
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, _close);
  }

  Future<void> _close() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    return Positioned(
      top: MediaQuery.paddingOf(context).top + Spacing.sm,
      left: Spacing.md,
      right: Spacing.md,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: _controller,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _close,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card2,
                  borderRadius: Radii.mdAll,
                  border: Border(
                    left: BorderSide(color: widget.type.color, width: 4),
                  ),
                  boxShadow: Shadows.floating,
                ),
                child: Row(
                  children: [
                    Icon(widget.type.icon, size: 20, color: widget.type.color),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppText.body(
                          size: 14,
                          weight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
