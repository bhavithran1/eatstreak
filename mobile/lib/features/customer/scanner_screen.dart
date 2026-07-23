import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/env.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/qr_codec.dart';
import '../../domain/check_in_flow.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/gradient_button.dart';
import '../shared/widgets/scan_overlay.dart';
import 'scan_success_screen.dart';
import 'shop_not_found_screen.dart';

/// "Simulate a scan" builds a check-in link carrying no day code, because the
/// customer isn't the owner and so cannot mint one. Only demo mode accepts
/// that: against the live backend a codeless check-in is rejected by design, so
/// the button could never do anything but fail. Gate it on demo mode rather
/// than on debug alone, so a debug build pointed at the real backend doesn't
/// offer an affordance that cannot work.
const _canSimulateScan = kDebugMode && Env.demoMode;

/// The camera check-in. Also the app's only write path for customers, so every
/// failure mode here has to say something useful rather than just stalling.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Guards against the detector firing again while we're mid-navigation.
  bool _handling = false;
  bool _torchOn = false;
  bool _showSuccess = false;
  bool? _cameraAvailable;

  @override
  void initState() {
    super.initState();
    _checkCamera();
  }

  Future<void> _checkCamera() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _cameraAvailable = true);
      return;
    }
    if (status.isPermanentlyDenied) {
      setState(() => _cameraAvailable = false);
      return;
    }
    final result = await Permission.camera.request();
    if (mounted) setState(() => _cameraAvailable = result.isGranted);
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    setState(() => _handling = true);
    await _route(raw);
  }

  /// Resolve a scanned payload, then send the user where it belongs.
  Future<void> _route(String raw) async {
    final target = parseCheckInTarget(raw);

    if (target == null) {
      final parsed = parseExternalQr(raw);
      if (!mounted) return;
      await context.push(
        Routes.shopNotFound,
        extra: ShopNotFoundArgs(
          qrData: raw,
          extractedName: parsed.extractedName,
        ),
      );
      _rearm();
      return;
    }

    CheckInOutcome outcome;
    try {
      outcome = await runCheckIn(
        target.shopId,
        ref.read(storeControllerProvider.notifier).checkIn,
        token: target.token,
        rawData: raw,
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
      }
      _rearm();
      return;
    }

    if (!mounted) return;

    switch (outcome) {
      case CheckInAlreadyToday():
        AppToast.show(context, outcome.message, type: ToastType.info);
        _rearm();

      case CheckInCodeInvalid():
        AppToast.show(context, outcome.message, type: ToastType.error);
        _rearm();

      case CheckInUnknownShop():
        await context.push(
          Routes.shopNotFound,
          extra: ShopNotFoundArgs(qrData: outcome.qrData),
        );
        _rearm();

      case CheckInRecorded():
        // A beat of confirmation before the screen changes, so the scan reads
        // as having landed rather than the UI just jumping. The thump matters
        // as much as the flash — the phone is often already moving away from
        // the code by the time this fires.
        unawaited(HapticFeedback.heavyImpact());
        setState(() => _showSuccess = true);
        await Future<void>.delayed(const Duration(milliseconds: 520));
        if (!mounted) return;
        setState(() => _showSuccess = false);
        await context.push(
          Routes.scanSuccess,
          extra: ScanSuccessArgs(
            shopId: outcome.shopId,
            streakDays: outcome.streakDays,
            totalVisits: outcome.totalVisits,
            newVoucherCount: outcome.newVoucherCount,
          ),
        );
        _rearm();
    }
  }

  void _rearm() {
    if (mounted) setState(() => _handling = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraAvailable == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_cameraAvailable == false) return _permissionScreen();

    final size = MediaQuery.sizeOf(context);
    final scanSize = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) => unawaited(_onDetect(capture)),
            onDetectError: (error, _) => AppToast.show(
              context,
              friendlyErrorMessage(error),
              type: ToastType.error,
            ),
          ),
          ScanOverlay(scanSize: scanSize),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                _bottomHelp(scanSize, size.height),
              ],
            ),
          ),
          if (_showSuccess) _successFlash(),
        ],
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _cameraControl(
              icon: Icons.close,
              label: 'Close scanner',
              onTap: () => context.go(Routes.customerHome),
            ),
            Text('Scan to check in', style: AppText.heading(size: 15)),
            _cameraControl(
              icon: _torchOn ? Icons.flash_on : Icons.flash_off,
              label: 'Toggle torch',
              active: _torchOn,
              onTap: () async {
                await _controller.toggleTorch();
                if (mounted) setState(() => _torchOn = !_torchOn);
              },
            ),
          ],
        ),
      );

  Widget _cameraControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) =>
      Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? AppColors.primaryInk : AppColors.ink,
            ),
          ),
        ),
      );

  Widget _bottomHelp(double scanSize, double screenHeight) => Padding(
        padding: EdgeInsets.only(
          bottom: (screenHeight - scanSize) / 4,
          left: Spacing.lg,
          right: Spacing.lg,
        ),
        child: Column(
          children: [
            Text(
              'Point at a restaurant QR code',
              style: AppText.body(
                size: 16,
                weight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Scanning happens automatically.',
              style: AppText.body(size: 13),
            ),
            if (_canSimulateScan) ...[
              const SizedBox(height: Spacing.md),
              _SimulateScanButton(onPick: (shopId) async {
                if (_handling) return;
                setState(() => _handling = true);
                await _route(buildCheckInLink(shopId));
              }),
            ],
          ],
        ),
      );

  Widget _successFlash() => Container(
        color: AppColors.bg.withValues(alpha: 0.82),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  size: 56,
                  color: AppColors.primaryInk,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'Checked in!',
              style: AppText.heading(size: 20, weight: FontWeight.w700),
            ),
          ],
        ),
      );

  Widget _permissionScreen() => Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      size: 30,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Camera access needed',
                    textAlign: TextAlign.center,
                    style: AppText.heading(size: 22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'EatStreak needs your camera to scan QR codes at '
                    'restaurants and track your eating streaks.',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 15, height: 1.45),
                  ),
                  const SizedBox(height: Spacing.lg),
                  GradientButton(
                    label: 'Open settings',
                    icon: Icons.photo_camera_outlined,
                    onPressed: () => unawaited(openAppSettings()),
                  ),
                  if (_canSimulateScan) ...[
                    const SizedBox(height: Spacing.xxl),
                    Text(
                      'No camera here — the Simulator has none. '
                      'Pick a shop to try a check-in.',
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 13, color: AppColors.muted2),
                    ),
                    const SizedBox(height: Spacing.sm),
                    _SimulateScanButton(
                      onPick: (shopId) => _route(buildCheckInLink(shopId)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

/// Debug-only shortcut past the camera. Essential on the iOS Simulator, which
/// has no camera at all — without it the check-in flow can't be exercised.
class _SimulateScanButton extends ConsumerStatefulWidget {
  const _SimulateScanButton({required this.onPick});

  final Future<void> Function(String shopId) onPick;

  @override
  ConsumerState<_SimulateScanButton> createState() =>
      _SimulateScanButtonState();
}

class _SimulateScanButtonState extends ConsumerState<_SimulateScanButton> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final shops =
        ref.watch(storeControllerProvider).value?.shops ?? const [];

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: Radii.smAll,
              border: Border.all(color: AppColors.muted2),
            ),
            child: Text(
              _open ? 'Hide shops' : 'Simulate a scan',
              style: AppText.body(size: 13, weight: FontWeight.w500),
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: Spacing.sm),
          for (final shop in shops)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: GestureDetector(
                onTap: () {
                  setState(() => _open = false);
                  unawaited(widget.onPick(shop.id));
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card2,
                    borderRadius: Radii.mdAll,
                    border: hairline,
                  ),
                  child: Text(
                    shop.name,
                    textAlign: TextAlign.center,
                    style: AppText.heading(size: 15, weight: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
