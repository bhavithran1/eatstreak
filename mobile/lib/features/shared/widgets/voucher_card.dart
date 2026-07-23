import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/dates.dart';
import '../../../data/models/voucher.dart';
import 'pressable_scale.dart';

/// An earned discount, drawn as a torn ticket: the discount on the stub, the
/// shop and code on the body.
class VoucherCard extends StatelessWidget {
  const VoucherCard({
    super.key,
    required this.voucher,
    this.onRedeem,
    this.onTap,
  });

  final Voucher voucher;

  /// Redemption is the owner's to confirm, so customers never see this. Kept
  /// for the owner-side verification screen, which shows the voucher it is
  /// about to honour.
  final VoidCallback? onRedeem;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final daysLeft = daysFromNow(voucher.expiresAt);
    final isExpired = daysLeft <= 0 && !voucher.isRedeemed;
    final isExpiringSoon = !voucher.isRedeemed && !isExpired && daysLeft <= 3;
    final isSpent = voucher.isRedeemed || isExpired;

    final expiryLabel = switch (daysLeft) {
      1 => 'Expires today',
      2 => 'Expires tomorrow',
      _ => 'Expires in $daysLeft days',
    };

    final borderColor = voucher.isRedeemed
        ? AppColors.line
        : isExpired
            ? AppColors.error.withValues(alpha: 0.19)
            : AppColors.ember2.withValues(alpha: 0.19);

    return PressableScale(
      onTap: onTap,
      child: Opacity(
        opacity: voucher.isRedeemed
            ? 0.6
            : isExpired
                ? 0.5
                : 1,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: Radii.lgAll,
            border: Border.all(color: borderColor),
            boxShadow: isSpent ? null : Shadows.card,
          ),
          child: ClipRRect(
            borderRadius: Radii.lgAll,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stub(),
                  const _DashedDivider(),
                  Expanded(
                    child: _body(isExpired, isExpiringSoon, expiryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stub() => SizedBox(
        width: 90,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${voucher.discountPercent}',
                style: AppText.heading(
                  size: 36,
                  weight: FontWeight.w700,
                  color: AppColors.ember2,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '%',
                    style: AppText.heading(
                      size: 18,
                      weight: FontWeight.w700,
                      color: AppColors.ember2,
                    ),
                  ),
                  Text(
                    'OFF',
                    style: AppText.body(size: 11, weight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _body(bool isExpired, bool isExpiringSoon, String expiryLabel) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  voucher.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading(size: 14, weight: FontWeight.w500),
                ),
              ),
              if (voucher.isRedeemed)
                _badge('Used', AppColors.muted)
              else if (isExpired)
                _badge('Expired', AppColors.error),
            ],
          ),
          const SizedBox(height: 4),
          Text(voucher.tierLabel, style: AppText.body(size: 12)),
          const SizedBox(height: 4),
          Text(
            voucher.code,
            style: AppText.heading(
              size: 16,
              color: AppColors.ember1,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  voucher.isRedeemed
                      ? 'Used ${formatDate(voucher.redeemedAt ?? '')}'
                      : isExpired
                          ? 'Expired'
                          : expiryLabel,
                  style: AppText.body(
                    size: 12,
                    weight: isExpiringSoon ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isExpiringSoon ? AppColors.warning : AppColors.muted2,
                  ),
                ),
              ),
              if (!voucher.isRedeemed && !isExpired && onRedeem != null)
                GestureDetector(
                  onTap: onRedeem,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: Radii.smAll,
                      gradient: const LinearGradient(
                        colors: [AppColors.ember1, AppColors.ember2],
                      ),
                    ),
                    child: Text(
                      'Use',
                      style: AppText.heading(
                        size: 13,
                        color: AppColors.primaryInk,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.19),
          borderRadius: Radii.pillAll,
        ),
        child: Text(
          text,
          style: AppText.body(size: 11, weight: FontWeight.w600, color: color),
        ),
      );
}

/// The perforation between stub and body.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 1, child: CustomPaint(painter: _DashPainter()));
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line2
      ..strokeWidth = 1;

    const dash = 4.0;
    const gap = 4.0;
    for (var y = 0.0; y < size.height; y += dash + gap) {
      final end = (y + dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(0.5, y), Offset(0.5, end), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}
