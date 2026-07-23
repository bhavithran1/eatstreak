import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/qr_codec.dart';
import '../../data/models/enums.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/gradient_button.dart';
import '../shared/widgets/scan_overlay.dart';
import 'choose_plan_screen.dart';
import 'widgets/shop_details_fields.dart';

enum _Step { scan, confirm }

/// Shop registration, step one of two. Scanning an existing business QR (Google
/// Maps, a payment code) prefills the name — but it's strictly a shortcut, and
/// "enter details manually" is always one tap away.
class RegisterShopScreen extends ConsumerStatefulWidget {
  const RegisterShopScreen({super.key});

  @override
  ConsumerState<RegisterShopScreen> createState() => _RegisterShopScreenState();
}

class _RegisterShopScreenState extends ConsumerState<RegisterShopScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  _Step _step = _Step.scan;
  bool _scanned = false;
  bool? _cameraAvailable;
  ShopCategory _category = ShopCategory.other;
  String _sourceQr = '';
  ExternalQrType? _qrType;

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
    unawaited(_controller.dispose());
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    _handleRawQr(raw);
  }

  void _handleRawQr(String raw) {
    final parsed = parseExternalQr(raw);
    setState(() {
      _scanned = true;
      _sourceQr = raw;
      _qrType = parsed.type;
      if (parsed.extractedName != null && parsed.extractedName!.isNotEmpty) {
        _nameController.text = parsed.extractedName!;
      }
      _step = _Step.confirm;
    });
  }

  /// Import a QR from a saved photo — the alternative to live-scanning for
  /// owners whose code lives in their camera roll rather than in front of them.
  Future<void> _pickFromGallery() async {
    final file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    final capture = await _controller.analyzeImage(file.path);
    final raw = capture?.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);

    if (!mounted) return;
    if (raw == null) {
      AppToast.show(
        context,
        "Couldn't find a QR code in that photo. Try another, or enter details "
        'manually.',
        type: ToastType.error,
      );
      return;
    }
    _handleRawQr(raw);
  }

  void _proceed() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    context.push(
      Routes.choosePlan,
      extra: ChoosePlanArgs(
        shopName: name,
        category: _category,
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim(),
        sourceQr: _sourceQr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      _step == _Step.confirm ? _confirmStep() : _scanStep();

  // ---- step 1: scan --------------------------------------------------------

  Widget _scanStep() {
    if (_cameraAvailable == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_cameraAvailable == false) return _noCameraStep();

    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          ScanOverlay(scanSize: size.width * 0.65),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _backButton(
                          () => context.canPop()
                              ? context.pop()
                              : context.go(Routes.ownerDashboard),
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        'Scan your shop QR',
                        style: AppText.heading(size: 20, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Google Maps, payment, or any business QR',
                        style: AppText.body(size: 14),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.xl,
                    Spacing.xl,
                    Spacing.xl,
                    Spacing.md,
                  ),
                  child: GradientButton(
                    label: 'Upload QR from gallery',
                    icon: Icons.photo_library_outlined,
                    variant: GradientButtonVariant.outline,
                    expand: true,
                    onPressed: () => unawaited(_pickFromGallery()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.xl,
                    0,
                    Spacing.xl,
                    Spacing.xl,
                  ),
                  child: GradientButton(
                    label: 'Enter details manually',
                    variant: GradientButtonVariant.outline,
                    expand: true,
                    onPressed: () => setState(() => _step = _Step.confirm),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noCameraStep() => Scaffold(
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
                      Icons.qr_code_scanner,
                      size: 30,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Scan your shop QR',
                    textAlign: TextAlign.center,
                    style: AppText.heading(size: 22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Scan an existing QR code (Google Maps, payment QR, etc.) '
                    "and we'll detect your shop name automatically.",
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 15, height: 1.45),
                  ),
                  const SizedBox(height: Spacing.lg),
                  GradientButton(
                    label: 'Allow camera',
                    icon: Icons.photo_camera_outlined,
                    onPressed: () => unawaited(openAppSettings()),
                  ),
                  const SizedBox(height: Spacing.md),
                  GradientButton(
                    label: 'Upload QR from gallery',
                    icon: Icons.photo_library_outlined,
                    variant: GradientButtonVariant.outline,
                    onPressed: () => unawaited(_pickFromGallery()),
                  ),
                  const SizedBox(height: Spacing.md),
                  GestureDetector(
                    onTap: () => setState(() => _step = _Step.confirm),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.sm),
                      child: Text(
                        'Enter details manually instead',
                        style: AppText.body(
                          size: 14,
                          weight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  // ---- step 2: confirm -----------------------------------------------------

  Widget _confirmStep() => AppScreen(
        onBack: () => setState(() {
          _step = _Step.scan;
          _scanned = false;
        }),
        title: _sourceQr.isEmpty ? 'Enter your shop details' : 'Confirm your shop',
        children: [
          if (_qrType == ExternalQrType.googleMaps)
            _detectedBadge(Icons.place, 'Extracted from Google Maps')
          else if (_qrType == ExternalQrType.upi)
            _detectedBadge(Icons.credit_card, 'Extracted from payment QR'),
          const SizedBox(height: Spacing.lg),
          ShopDetailsFields(
            nameController: _nameController,
            addressController: _addressController,
            descriptionController: _descriptionController,
            category: _category,
            onCategoryChanged: (c) => setState(() => _category = c),
            onNameChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.xl),
          GradientButton(
            label: 'Choose reward plan',
            size: GradientButtonSize.lg,
            expand: true,
            onPressed: _nameController.text.trim().isEmpty ? null : _proceed,
          ),
        ],
      );

  Widget _detectedBadge(IconData icon, String text) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: Radii.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                text,
                style: AppText.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _backButton(VoidCallback onTap) => Semantics(
        button: true,
        label: 'Back',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(
              Icons.arrow_back,
              size: 20,
              color: AppColors.ink,
            ),
          ),
        ),
      );
}
