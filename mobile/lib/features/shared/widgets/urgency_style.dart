import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';

/// How a streak's urgency reads on screen. Kept in one place so the customer
/// cards and the owner's customer list never disagree about what "critical"
/// looks like.
extension StreakUrgencyStyle on StreakUrgency {
  Color get color => switch (this) {
        StreakUrgency.safe => AppColors.success,
        StreakUrgency.warning => AppColors.warning,
        StreakUrgency.critical => AppColors.error,
        StreakUrgency.dead => AppColors.muted2,
      };

  String get label => switch (this) {
        StreakUrgency.safe => 'On track',
        StreakUrgency.warning => 'Visit soon',
        StreakUrgency.critical => 'Last day',
        StreakUrgency.dead => 'Ended',
      };
}

/// The small dot-plus-label pill that reports streak health.
class UrgencyBadge extends StatelessWidget {
  const UrgencyBadge({super.key, required this.urgency});

  final StreakUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final color = urgency.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: Radii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            urgency.label,
            style: AppText.body(size: 11, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
