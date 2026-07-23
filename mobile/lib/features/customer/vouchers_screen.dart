import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../data/models/voucher.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/store_scope.dart';
import '../shared/widgets/voucher_card.dart';

enum _Tab { active, used, expired }

class VouchersScreen extends ConsumerStatefulWidget {
  const VouchersScreen({super.key});

  @override
  ConsumerState<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends ConsumerState<VouchersScreen> {
  _Tab _tab = _Tab.active;

  @override
  Widget build(BuildContext context) =>
      StoreScope(builder: (context, state) => _body(context, state));

  Widget _body(BuildContext context, StoreState state) {

    final groups = {
      _Tab.active: state.vouchers
          .where((v) => !v.isRedeemed && daysFromNow(v.expiresAt) > 0)
          .toList(),
      _Tab.used: state.vouchers.where((v) => v.isRedeemed).toList(),
      _Tab.expired: state.vouchers
          .where((v) => !v.isRedeemed && daysFromNow(v.expiresAt) <= 0)
          .toList(),
    };
    final current = groups[_tab]!;

    return AppScreen(
      title: 'Vouchers',
      subtitle: 'Show a code to staff — they apply the discount for you.',
      onRefresh: ref.read(storeControllerProvider.notifier).refresh,
      children: [
        _tabs(groups),
        const SizedBox(height: Spacing.md),
        if (current.isEmpty)
          EmptyState(
            icon: switch (_tab) {
              _Tab.active => Icons.confirmation_number_outlined,
              _Tab.used => Icons.check_circle_outline,
              _Tab.expired => Icons.schedule,
            },
            title: 'No ${_tab.name} vouchers',
            subtitle: switch (_tab) {
              _Tab.active =>
                'Keep visiting partner shops to unlock your next reward.',
              _Tab.used => "Vouchers you've redeemed will appear here.",
              _Tab.expired => 'Expired vouchers will show up here.',
            },
          )
        else
          for (final v in current)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: VoucherCard(
                voucher: v,
              ),
            ),
      ],
    );
  }

  Widget _tabs(Map<_Tab, List<Voucher>> groups) => Container(
        padding: const EdgeInsets.all(Spacing.xs),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: Radii.mdAll,
          border: hairline,
        ),
        child: Row(
          children: [
            for (final tab in _Tab.values)
              Expanded(child: _tabButton(tab, groups[tab]!.length)),
          ],
        ),
      );

  Widget _tabButton(_Tab tab, int count) {
    final active = _tab == tab;

    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.card2 : Colors.transparent,
          borderRadius: Radii.smAll,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${tab.name[0].toUpperCase()}${tab.name.substring(1)}',
              style: AppText.heading(
                size: 13,
                weight: FontWeight.w500,
                color: active ? AppColors.ink : AppColors.muted2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active ? AppColors.ember2 : AppColors.line,
                borderRadius: Radii.pillAll,
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: AppText.body(
                  size: 11,
                  weight: FontWeight.w600,
                  color: active ? AppColors.primaryInk : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
