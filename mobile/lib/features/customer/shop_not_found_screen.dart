import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/gradient_button.dart';

/// What was scanned, so the suggestion form can prefill from it.
class ShopNotFoundArgs {
  const ShopNotFoundArgs({required this.qrData, this.extractedName});

  final String qrData;
  final String? extractedName;
}

/// Reached when a scan isn't an EatStreak code. Rather than dead-ending, it
/// offers to record the place as a suggestion.
class ShopNotFoundScreen extends ConsumerStatefulWidget {
  const ShopNotFoundScreen({super.key, required this.args});

  final ShopNotFoundArgs args;

  @override
  ConsumerState<ShopNotFoundScreen> createState() => _ShopNotFoundScreenState();
}

class _ShopNotFoundScreenState extends ConsumerState<ShopNotFoundScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.args.extractedName ?? '');
  bool _submitted = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(storeControllerProvider.notifier)
          .addShopSuggestion(name, widget.args.qrData);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _submitted = true;
    });
    AppToast.show(context, 'Suggestion saved', type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final detected = widget.args.extractedName;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: const Alignment(0, -0.2),
            colors: [
              AppColors.error.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: AppScreen(
          // Transparent so the warning wash above shows through.
          backgroundColor: Colors.transparent,
          onBack: () =>
              context.canPop() ? context.pop() : context.go(Routes.scanner),
          children: [
            const SizedBox(height: Spacing.md),
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(
                  Icons.search_off,
                  size: 44,
                  color: AppColors.muted2,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              "This isn't an EatStreak code",
              textAlign: TextAlign.center,
              style: AppText.heading(size: 24, weight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'We can only check you in with an EatStreak partner code. You can '
              'still suggest this place for the network.',
              textAlign: TextAlign.center,
              style: AppText.body(size: 15, height: 1.5),
            ),
            const SizedBox(height: Spacing.lg),
            if (detected != null && detected.isNotEmpty) ...[
              SurfaceCard(
                borderColor: AppColors.ember2.withValues(alpha: 0.19),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 20,
                      color: AppColors.ember2,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('We detected', style: AppText.body(size: 12)),
                          Text(detected, style: AppText.heading(size: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
            ],
            if (_submitted) _thankYou() else _suggestForm(),
            const SizedBox(height: Spacing.lg),
            _infoCard(),
            const SizedBox(height: Spacing.lg),
            GradientButton(
              label: 'Back to scanner',
              expand: true,
              variant: GradientButtonVariant.outline,
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.scanner),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestForm() => SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggest this shop', style: AppText.heading(size: 17)),
            const SizedBox(height: Spacing.xs),
            Text(
              'Save the restaurant name so you can recognize it if it joins '
              'the network later.',
              style: AppText.body(size: 14, height: 1.45),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              style: AppText.body(size: 16, color: AppColors.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bg,
                hintText: 'Restaurant name',
                hintStyle: AppText.body(size: 16, color: AppColors.muted2),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: 14,
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
            const SizedBox(height: Spacing.md),
            GradientButton(
              label: 'Suggest restaurant',
              expand: true,
              busy: _busy,
              onPressed: _controller.text.trim().isEmpty ? null : _suggest,
            ),
          ],
        ),
      );

  Widget _thankYou() => Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.06),
          borderRadius: Radii.lgAll,
          border: Border.all(color: AppColors.success.withValues(alpha: 0.19)),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.check,
                size: 24,
                color: AppColors.primaryInk,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Suggestion saved',
              style: AppText.heading(
                size: 20,
                weight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _controller.text.trim(),
                    style: AppText.heading(size: 14, color: AppColors.primary),
                  ),
                  TextSpan(
                    text: ' is now on your suggestion list. For now, ask the '
                        'shop for its EatStreak QR code.',
                    style: AppText.body(size: 14, height: 1.45),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _infoCard() => SurfaceCard(
        child: Column(
          children: [
            _infoRow(
              Icons.monitor_heart_outlined,
              AppColors.primary,
              'EatStreak partners offer streak-based discounts up to 50% off',
            ),
            const SizedBox(height: Spacing.md),
            _infoRow(
              Icons.people_outline,
              AppColors.ember2,
              'When enough people suggest a shop, we prioritize reaching out',
            ),
            const SizedBox(height: Spacing.md),
            _infoRow(
              Icons.notifications_outlined,
              AppColors.ember3,
              'Only official EatStreak QR codes can record a visit',
            ),
          ],
        ),
      );

  Widget _infoRow(IconData icon, Color color, String text) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(text, style: AppText.body(size: 13, height: 1.4)),
          ),
        ],
      );
}
