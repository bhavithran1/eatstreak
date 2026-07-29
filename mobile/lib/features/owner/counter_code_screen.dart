import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/qr_codec.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/gradient_button.dart';

/// Arguments for [CounterCodeScreen] — the shop, and the code it is showing.
class CounterCodeArgs {
  const CounterCodeArgs({
    required this.shopId,
    required this.shopName,
    required this.token,
  });

  final String shopId;
  final String shopName;
  final String token;
}

/// Today's code, big, on a white sheet — the thing a customer actually points a
/// camera at.
///
/// One widget doing two jobs on purpose. Propped on the counter it is a display
/// that never sleeps; shared, it is the same sheet as a PNG, which iOS will
/// print or AirDrop to whatever sits by the till. That works only because the
/// code is stable for the whole day: a printed sheet is worth exactly as much
/// as holding the phone up, and stops being worth anything at the same moment,
/// tonight. Anything per-scan or per-minute could never leave the screen.
class CounterCodeScreen extends StatefulWidget {
  const CounterCodeScreen({super.key, required this.args});

  final CounterCodeArgs args;

  @override
  State<CounterCodeScreen> createState() => _CounterCodeScreenState();
}

class _CounterCodeScreenState extends State<CounterCodeScreen> {
  final _sheetKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    // The whole point of this screen is to be left alone facing a queue.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      // Position matters on iPad, where the share sheet is a popover anchored
      // to whatever opened it. Without it UIKit throws rather than guessing.
      // Read before the await: after one, this context may be gone.
      final box = context.findRenderObject() as RenderBox?;

      final bytes = await _captureSheet();
      if (bytes == null) throw StateError('nothing to capture');

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'eatstreak-code.png',
            ),
          ],
          fileNameOverrides: const ['eatstreak-code.png'],
          subject: "${widget.args.shopName} — today's EatStreak code",
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "Couldn't prepare the code sheet. Try again.",
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Rasterise the sheet exactly as drawn, at print resolution.
  ///
  /// Captured from the live widget rather than rebuilt for export, so what gets
  /// printed cannot drift from what the owner just looked at and approved.
  Future<Uint8List?> _captureSheet() async {
    final boundary =
        _sheetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    // 3x: a QR printed at screen density is soft enough that scanners hunt.
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.ownerQrCode),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                  tooltip: 'Close',
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: GradientButton(
                    label: 'Share or print',
                    icon: Icons.ios_share,
                    variant: GradientButtonVariant.outline,
                    size: GradientButtonSize.sm,
                    busy: _sharing,
                    onPressed: () => unawaited(_share()),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  child: RepaintBoundary(
                    key: _sheetKey,
                    child: _sheet(args),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.xl,
                0,
                Spacing.xl,
                Spacing.md,
              ),
              child: Text(
                "Stays on screen — this code works until midnight, then it's "
                'replaced automatically.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 12, color: AppColors.muted2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The printable sheet. Black on white, nothing else: a scanner reading this
  /// off paper or off a screen has no use for the app's palette, and a dark
  /// sheet costs a shop a page of toner.
  Widget _sheet(CounterCodeArgs args) => Container(
        width: 320,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xl,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.xlAll,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              args.shopName,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppText.heading(
                size: 22,
                weight: FontWeight.w700,
                color: AppColors.primaryInk,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Scan to log your visit',
              style: AppText.body(size: 14, color: const Color(0xFF5A6472)),
            ),
            const SizedBox(height: Spacing.lg),
            QrImageView(
              data: buildCheckInLink(args.shopId, token: args.token),
              size: 240,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.primaryInk,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.primaryInk,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'Open EatStreak and tap Scan',
              style: AppText.body(
                size: 13,
                weight: FontWeight.w600,
                color: const Color(0xFF5A6472),
              ),
            ),
            const SizedBox(height: 2),
            // Dated on purpose. A sheet printed on Tuesday and still taped to
            // the till on Wednesday is the one failure this design can have,
            // and it should be readable from the customer's side of the
            // counter before anyone wonders why nothing is scanning.
            Text(
              'Valid ${formatDate(todayString())}',
              style: AppText.body(size: 12, color: const Color(0xFF8A94A3)),
            ),
          ],
        ),
      );
}
