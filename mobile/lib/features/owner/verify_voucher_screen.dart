import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../data/models/voucher.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/gradient_button.dart';

/// Where the owner honours a discount.
///
/// Redemption used to be customer self-serve — they tapped "mark as used" and
/// the owner had no way to check the voucher was real, unspent, or even for
/// their shop. Entering the code here is the authoritative act: the server
/// verifies it belongs to this owner, hasn't been used, and hasn't expired.
class VerifyVoucherScreen extends ConsumerStatefulWidget {
  const VerifyVoucherScreen({super.key});

  @override
  ConsumerState<VerifyVoucherScreen> createState() =>
      _VerifyVoucherScreenState();
}

class _VerifyVoucherScreenState extends ConsumerState<VerifyVoucherScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  Voucher? _honoured;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      final voucher = await ref
          .read(storeControllerProvider.notifier)
          .redeemVoucherByCode(code)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _honoured = voucher;
        _busy = false;
      });
      _controller.clear();
      unawaited(HapticFeedback.heavyImpact());
      AppToast.show(
        context,
        '${voucher.discountPercent}% discount applied',
        type: ToastType.success,
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(
        context,
        "Couldn't reach the server. Check your connection and try again.",
        type: ToastType.error,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // The server's message is the useful part here — "already used",
      // "expired", "not your shop" are all things staff need to hear verbatim.
      AppToast.show(context, _messageFor(e), type: ToastType.error);
    }
  }

  static String _messageFor(Object error) {
    final dynamic dyn = error;
    try {
      final message = dyn.message;
      if (message is String && message.isNotEmpty) return message;
    } on NoSuchMethodError {
      // Not a coded exception — fall through.
    }
    return friendlyErrorMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      onBack: () => context.canPop()
          ? context.pop()
          : context.go(Routes.ownerDashboard),
      title: 'Verify a voucher',
      subtitle: "Enter the code on the customer's voucher to apply it.",
      children: [
        TextField(
          controller: _controller,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => unawaited(_verify()),
          style: AppText.heading(size: 20, letterSpacing: 3),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            hintText: 'EAT-XXXXXX',
            hintStyle: AppText.heading(
              size: 20,
              letterSpacing: 3,
              color: AppColors.muted2,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: Radii.mdAll,
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: Radii.mdAll,
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        GradientButton(
          label: 'Apply discount',
          size: GradientButtonSize.lg,
          expand: true,
          busy: _busy,
          onPressed: _controller.text.trim().isEmpty ? null : () => unawaited(_verify()),
        ),
        if (_honoured != null) ...[
          const SizedBox(height: Spacing.xl),
          _honouredCard(_honoured!),
        ],
        const SizedBox(height: Spacing.xl),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How this works', style: AppText.heading(size: 15)),
              const SizedBox(height: Spacing.md),
              _tip(Icons.smartphone, 'The customer opens their voucher'),
              const SizedBox(height: Spacing.md),
              _tip(Icons.keyboard, 'You type the code here and apply it'),
              const SizedBox(height: Spacing.md),
              _tip(
                Icons.lock_outline,
                'A code works once, and only at your shop',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _honouredCard(Voucher v) => SurfaceCard(
        borderColor: AppColors.success.withValues(alpha: 0.35),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${v.discountPercent}% off applied',
                    style: AppText.heading(size: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${v.tierLabel} · ${v.code}',
                    style: AppText.body(size: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _tip(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.ember2),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(text, style: AppText.body(size: 14))),
        ],
      );
}
