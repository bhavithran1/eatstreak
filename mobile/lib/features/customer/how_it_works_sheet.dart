import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Explains streaks, the return window and how rewards unlock.
///
/// The return window is the single most important rule in the product and the
/// app never stated it anywhere: customers could only infer it from watching a
/// streak die.
Future<void> showHowItWorks(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => const _HowItWorksSheet(),
    );

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How streaks work',
              style: AppText.heading(size: 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.lg),
            _step(
              Icons.qr_code_scanner,
              'Scan when you pay',
              'Staff show a check-in code at the counter. Scanning it logs '
                  'your visit — one per shop per day.',
            ),
            _step(
              Icons.local_fire_department_outlined,
              'Come back within the window',
              'Each shop sets a return window. Visit again inside it and your '
                  'streak grows. Leave it too long and the streak resets to '
                  'day one — your total visits are never lost.',
            ),
            _step(
              Icons.card_giftcard_outlined,
              'Unlock discounts',
              'Streak days and total visits both unlock rewards. Each shop '
                  'sets its own thresholds, shown on its page.',
            ),
            _step(
              Icons.confirmation_number_outlined,
              'Use a voucher',
              'Earned vouchers live in the Vouchers tab. Show one to staff '
                  'and mark it used — that can only be done once, so wait '
                  'until they are ready.',
              last: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(
    IconData icon,
    String title,
    String body, {
    bool last = false,
  }) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : Spacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: Radii.mdAll,
              ),
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.heading(size: 15)),
                  const SizedBox(height: 3),
                  Text(body, style: AppText.body(size: 13, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );
}
