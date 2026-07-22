import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/errors.dart';
import '../../data/models/voucher.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/voucher_card.dart';

enum _Tab { active, used, expired }

class VouchersScreen extends ConsumerStatefulWidget {
  const VouchersScreen({super.key});

  @override
  ConsumerState<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends ConsumerState<VouchersScreen> {
  _Tab _tab = _Tab.active;

  Future<void> _redeem(String voucherId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card2,
        shape: RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Use voucher', style: AppText.heading(size: 18)),
        content: Text(
          'Show this to staff to apply your discount. Mark as used?',
          style: AppText.body(size: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppText.body(size: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Mark as used',
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

    try {
      await ref.read(storeControllerProvider.notifier).redeemVoucher(voucherId);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
      }
      return;
    }
    if (mounted) {
      AppToast.show(context, 'Voucher redeemed!', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeControllerProvider).value ?? const StoreState();

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
      subtitle: 'Use available vouchers before they expire.',
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
                onRedeem: _tab == _Tab.active ? () => _redeem(v.id) : null,
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
