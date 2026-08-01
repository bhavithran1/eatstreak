import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/qr_codec.dart';
import '../../data/models/voucher.dart';

/// The customer's half of redemption: hold this up, staff scan it.
///
/// Redemption is still the owner's act — nothing here spends the voucher, and
/// there is deliberately no button that could. All this screen does is make the
/// code readable by a camera held a foot away, and by a person if the camera
/// won't cooperate. Both are on screen at once because the fallback has to be
/// there before it is needed: a queue is the worst possible moment to discover
/// that the QR won't scan.
class ShowVoucherScreen extends StatefulWidget {
  const ShowVoucherScreen({super.key, required this.voucher});

  final Voucher voucher;

  @override
  State<ShowVoucherScreen> createState() => _ShowVoucherScreenState();
}

class _ShowVoucherScreenState extends State<ShowVoucherScreen> {
  @override
  void initState() {
    super.initState();
    // Held up at a counter and then handed over, this screen spends most of its
    // life untouched. Auto-lock would take it away mid-scan.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.voucher;
    final daysLeft = daysFromNow(v.expiresAt);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(Routes.vouchers),
                icon: const Icon(Icons.close, color: AppColors.muted),
                tooltip: 'Close',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                child: Column(
                  children: [
                    Text(
                      '${v.discountPercent}% off',
                      style: AppText.heading(size: 34, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.shopEmoji} ${v.shopName}',
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 15),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _qrPanel(v),
                    const SizedBox(height: Spacing.lg),
                    Text(
                      'Show this to staff',
                      style: AppText.heading(size: 17),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'They scan it to apply your discount.',
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 14),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _codeRow(v),
                    const SizedBox(height: Spacing.md),
                    Text(
                      daysLeft <= 0
                          ? 'Expired'
                          : daysLeft == 1
                              ? 'Expires today'
                              : 'Expires in $daysLeft days',
                      style: AppText.body(
                        size: 13,
                        color: daysLeft <= 3
                            ? AppColors.warning
                            : AppColors.muted2,
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qrPanel(Voucher v) {
    // Sized off the screen rather than fixed: this panel is held up to someone
    // else's camera, so it should be as big as the phone allows, and must not
    // run off the narrow ones.
    final side =
        (MediaQuery.sizeOf(context).width - Spacing.xl * 2).clamp(220.0, 268.0);

    return Container(
        width: side,
        height: side,
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.xlAll,
        ),
        child: Center(
          child: QrImageView(
            data: buildVoucherPayload(v.code),
            size: side - Spacing.lg * 2,
            backgroundColor: Colors.white,
            // Same reason as the owner's code: a phone screen held at an angle
            // under a shop's lighting is a bad surface to read a QR off.
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
        ),
    );
  }

  /// The code in type big enough to read aloud across a counter, and copyable
  /// for the times it gets sent rather than shown.
  Widget _codeRow(Voucher v) => GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: v.code));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code copied')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: Radii.lgAll,
            border: Border.all(color: AppColors.line2),
          ),
          // A letter-spaced code at 26pt is already most of a narrow screen;
          // one step up in text size and it is off the edge. Scaling down is
          // the right trade here — smaller but whole beats large and cut off,
          // when the entire job of the line is to be read out loud.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v.code,
                  style: AppText.heading(
                    size: 26,
                    weight: FontWeight.w700,
                    color: AppColors.ember1,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                const Icon(Icons.copy_rounded,
                    size: 16, color: AppColors.muted2),
              ],
            ),
          ),
        ),
      );
}
