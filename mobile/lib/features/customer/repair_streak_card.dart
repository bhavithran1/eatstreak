import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/dates.dart';
import '../../data/models/shop.dart';
import '../../data/models/streak.dart';
import '../../domain/streak_logic.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/gradient_button.dart';

/// Offers to bring a just-broken streak back for embers.
///
/// The price rises with the streak so the loss stays real, but it is paid in
/// currency earned by visiting rather than in money — a customer who is billed
/// for *not* visiting uninstalls the app.
class RepairStreakCard extends ConsumerStatefulWidget {
  const RepairStreakCard({
    super.key,
    required this.streak,
    required this.shop,
    required this.embers,
  });

  final Streak streak;
  final Shop shop;
  final int embers;

  @override
  ConsumerState<RepairStreakCard> createState() => _RepairStreakCardState();
}

class _RepairStreakCardState extends ConsumerState<RepairStreakCard> {
  bool _busy = false;

  RepairInfo get _info => repairInfo(
        widget.streak.currentStreakDays,
        widget.streak.lastVisitDate,
        widget.streak.brokenStreakDays,
        widget.streak.brokenOn,
        todayString(),
        widget.shop.streakWindowDays,
      );

  Future<void> _repair() async {
    if (_busy) return;
    final cost = _info.cost;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card2,
        shape: RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Repair your streak?', style: AppText.heading(size: 18)),
        content: Text(
          'This spends $cost of your ${widget.embers} embers and restores '
          'your ${_info.lostStreakDays}-day streak at ${widget.shop.name}. It '
          'does not count as a visit — check in today to keep it growing.',
          style: AppText.body(size: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Not now', style: AppText.body(size: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Spend $cost',
              style: AppText.body(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(storeControllerProvider.notifier)
          .repairStreak(widget.shop.id)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      AppToast.show(
        context,
        'Streak restored — check in today to keep it going.',
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
      AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final cost = info.cost;
    final affordable = widget.embers >= cost;

    return SurfaceCard(
      borderColor: AppColors.warning.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: Radii.mdAll,
                ),
                child: const Icon(
                  Icons.local_fire_department_outlined,
                  size: 21,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${info.lostStreakDays}-day streak broke',
                      style: AppText.heading(size: 15),
                    ),
                    Text(
                      widget.shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            affordable
                ? 'Repair it for $cost embers. You have ${widget.embers}.'
                : 'A repair costs $cost embers and you have ${widget.embers}. '
                    'Check in to earn more — one ember per visit.',
            style: AppText.body(size: 13, height: 1.4),
          ),
          const SizedBox(height: Spacing.md),
          GradientButton(
            label: affordable ? 'Repair for $cost' : 'Not enough embers',
            icon: Icons.local_fire_department_outlined,
            expand: true,
            busy: _busy,
            onPressed: affordable ? () => unawaited(_repair()) : null,
          ),
        ],
      ),
    );
  }
}
