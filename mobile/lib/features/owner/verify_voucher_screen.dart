import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/qr_codec.dart';
import '../../data/models/voucher.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/gradient_button.dart';

/// Where the owner honours a discount.
///
/// Redemption used to be customer self-serve — they tapped "mark as used" and
/// the owner had no way to check the voucher was real, unspent, or even for
/// their shop. Applying it here is the authoritative act: the server verifies
/// it belongs to this owner, hasn't been used, and hasn't expired. Which way
/// the code arrives — scanned or typed — changes nothing about that.
///
/// The camera leads because the alternative was typing `EAT-XXXXXX` off a
/// customer's screen with a queue waiting, which is slow, and wrong often
/// enough that the server grew a normaliser for the mistakes. Typing is still
/// here underneath it: a cracked screen, a dark one, or a dead battery all end
/// with a code read aloud.
class VerifyVoucherScreen extends ConsumerStatefulWidget {
  const VerifyVoucherScreen({super.key});

  @override
  ConsumerState<VerifyVoucherScreen> createState() =>
      _VerifyVoucherScreenState();
}

class _VerifyVoucherScreenState extends ConsumerState<VerifyVoucherScreen> {
  final _controller = TextEditingController();
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _busy = false;
  Voucher? _honoured;

  /// Null until the permission check has run; false means type it instead.
  bool? _cameraAvailable;

  @override
  void initState() {
    super.initState();
    unawaited(_checkCamera());
  }

  Future<void> _checkCamera() async {
    var status = await Permission.camera.status;
    if (status.isDenied) status = await Permission.camera.request();
    if (mounted) setState(() => _cameraAvailable = status.isGranted);
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_scanner.dispose());
    super.dispose();
  }

  /// A scanned payload. Anything that isn't one of our voucher codes is said
  /// out loud rather than ignored — an owner pointing the camera at the wrong
  /// QR and getting silence has no way to tell that from a broken scanner.
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final code = parseVoucherCode(raw);
    if (code == null) {
      if (!mounted) return;
      AppToast.show(
        context,
        "That isn't a voucher code. Ask the customer to open their voucher.",
        type: ToastType.error,
      );
      return;
    }

    await _verify(code);
  }

  Future<void> _verify([String? scanned]) async {
    // Tidied here as well as on the server: staff type these at a counter with
    // a queue behind them, so "EAT" left off or a stray space should not come
    // back as "no voucher with that code".
    final code = scanned ?? normalizeVoucherCode(_controller.text);
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
      title: 'Redeem a voucher',
      subtitle: "Scan the customer's voucher, or type the code.",
      children: [
        _scannerPanel(),
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: Text(
                'or type it',
                style: AppText.body(size: 13, color: AppColors.muted2),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.line)),
          ],
        ),
        const SizedBox(height: Spacing.lg),
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
              _tip(Icons.smartphone,
                  'The customer taps "Show" on their voucher'),
              const SizedBox(height: Spacing.md),
              _tip(Icons.qr_code_scanner,
                  'You point this at their screen — that applies it'),
              const SizedBox(height: Spacing.md),
              _tip(Icons.keyboard,
                  "If their screen won't cooperate, type the code instead"),
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

  /// The camera, inline. Not a separate screen: the owner is standing at a
  /// till holding a phone, and a screen that has to be navigated to and backed
  /// out of costs more than the scan saves.
  Widget _scannerPanel() {
    final available = _cameraAvailable;

    return ClipRRect(
      borderRadius: Radii.lgAll,
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: Radii.lgAll,
          border: Border.all(color: AppColors.line2),
        ),
        child: switch (available) {
          null => const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          false => _cameraUnavailable(),
          true => Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  // Granted permission is not a working camera — a device may
                  // have none at all. Saying so in our own words keeps the
                  // answer next to the fallback rather than leaving the
                  // plugin's sentence sitting under an aiming frame.
                  errorBuilder: (_, _) => _noCamera(
                    'This device has no camera',
                    'Type the code underneath instead.',
                  ),
                ),
                // The frame is the only thing telling the owner where to aim; a
                // bare camera feed reads as a preview, not a target. Drawn only
                // while there is a feed to aim at.
                ValueListenableBuilder(
                  valueListenable: _scanner,
                  builder: (_, state, _) => state.error != null
                      ? const SizedBox.shrink()
                      : IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 168,
                              height: 168,
                              decoration: BoxDecoration(
                                borderRadius: Radii.mdAll,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                if (_busy)
                  Container(
                    color: AppColors.bg.withValues(alpha: 0.6),
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
        },
      ),
    );
  }

  Widget _cameraUnavailable() => _noCamera(
        'Camera access is off',
        'Turn it on to scan vouchers, or type the code below.',
        action: GradientButton(
          label: 'Open settings',
          variant: GradientButtonVariant.outline,
          size: GradientButtonSize.sm,
          onPressed: () => unawaited(openAppSettings()),
        ),
      );

  Widget _noCamera(String title, String detail, {Widget? action}) => Container(
        color: AppColors.card,
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined,
                size: 28, color: AppColors.muted),
            const SizedBox(height: Spacing.sm),
            Text(title, textAlign: TextAlign.center,
                style: AppText.heading(size: 15)),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: AppText.body(size: 13),
            ),
            if (action != null) ...[
              const SizedBox(height: Spacing.md),
              action,
            ],
          ],
        ),
      );

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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
