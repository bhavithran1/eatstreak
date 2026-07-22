import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/reward_tier.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_button.dart';

/// Bounds that keep a ladder sane: no 0-day windows, no 100%-off tiers.
const _minWindowDays = 1;
const _maxWindowDays = 30;
const _maxThreshold = 365;
const _maxDiscount = 90;

/// The owner's reward-program editor. Edits are local until Save, so a
/// half-typed threshold never reaches the shop document.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  List<RewardTier>? _tiers;
  int _windowDays = 3;
  String? _loadedShopId;
  bool _saving = false;

  /// Seed local state the first time the shop arrives, and re-seed if the owner
  /// switches to a different shop — but never on an ordinary rebuild, which
  /// would discard whatever they were typing.
  void _syncFrom(String shopId, List<RewardTier> tiers, int windowDays) {
    if (_loadedShopId == shopId) return;
    _loadedShopId = shopId;
    _tiers = List.of(tiers);
    _windowDays = windowDays;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeControllerProvider).value ?? const StoreState();
    final shop = state.ownedShop;

    if (shop == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.card_giftcard_outlined,
              title: 'No rewards yet',
              subtitle: 'Register a shop first, then tune the rewards '
                  'customers can earn.',
              actionLabel: 'Register shop',
              onAction: () => context.push(Routes.registerShop),
            ),
          ),
        ),
      );
    }

    _syncFrom(shop.id, shop.rewardTiers, shop.streakWindowDays);
    final tiers = _tiers!;

    final streakTiers = _sorted(tiers, RewardType.streakDays);
    final visitTiers = _sorted(tiers, RewardType.visitCount);

    final dirty = _windowDays != shop.streakWindowDays ||
        !_listEquals(tiers, shop.rewardTiers);

    return AppScreen(
      title: 'Rewards',
      subtitle: 'Set what customers earn for visits and streaks.',
      children: [
        _windowCard(),
        const SizedBox(height: Spacing.lg),
        Text('Streak rewards', style: AppText.sectionTitle),
        const SizedBox(height: Spacing.sm),
        for (final t in streakTiers) _tierCard(t),
        _addButton('Add streak tier', RewardType.streakDays, shop.id),
        const SizedBox(height: Spacing.md),
        Text('Visit rewards', style: AppText.sectionTitle),
        const SizedBox(height: Spacing.sm),
        for (final t in visitTiers) _tierCard(t),
        _addButton('Add visit tier', RewardType.visitCount, shop.id),
        const SizedBox(height: Spacing.md),
        GradientButton(
          label: dirty ? 'Save reward program' : 'Changes saved',
          icon: dirty ? Icons.check : Icons.check_circle_outline,
          expand: true,
          busy: _saving,
          onPressed: dirty ? _save : null,
        ),
      ],
    );
  }

  List<RewardTier> _sorted(List<RewardTier> tiers, RewardType type) =>
      tiers.where((t) => t.type == type).toList()
        ..sort((a, b) => a.threshold.compareTo(b.threshold));

  static bool _listEquals(List<RewardTier> a, List<RewardTier> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _windowCard() => SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Streak window (days)', style: AppText.heading(size: 15)),
            const SizedBox(height: Spacing.xs),
            Text(
              'Customers must revisit within this many days to keep their '
              'streak.',
              style: AppText.body(size: 13, height: 1.4),
            ),
            const SizedBox(height: Spacing.sm),
            SizedBox(
              width: 80,
              child: _numberField(
                fieldKey: 'window',
                value: _windowDays,
                onChanged: (v) => setState(() => _windowDays = v),
                center: true,
              ),
            ),
          ],
        ),
      );

  Widget _tierCard(RewardTier tier) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: Radii.mdAll,
            border: hairline,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('${tier.id}-label'),
                      initialValue: tier.label,
                      onChanged: (v) => _update(tier.id, label: v),
                      style: AppText.heading(size: 15, weight: FontWeight.w500),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Tier name',
                        hintStyle:
                            AppText.body(size: 15, color: AppColors.muted2),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Delete ${tier.label}',
                    child: GestureDetector(
                      onTap: () => _confirmDelete(tier),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(Spacing.xs),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _labelledField(
                      tier.type == RewardType.visitCount ? 'Visits' : 'Days',
                      _numberField(
                        fieldKey: '${tier.id}-threshold',
                        value: tier.threshold,
                        onChanged: (v) => _update(tier.id, threshold: v),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: _labelledField(
                      'Discount %',
                      _numberField(
                        fieldKey: '${tier.id}-discount',
                        value: tier.discountPercent,
                        onChanged: (v) => _update(tier.id, discountPercent: v),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _labelledField(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 12)),
          const SizedBox(height: Spacing.xs),
          field,
        ],
      );

  /// A digits-only field bound to one number.
  ///
  /// [fieldKey] must be stable for the life of the field: keying it off the
  /// value would rebuild the widget on every keystroke and drop focus after a
  /// single digit. Values are stored as typed and only clamped on save, so
  /// nothing rewrites the text under the user's cursor mid-edit either.
  Widget _numberField({
    required String fieldKey,
    required int value,
    required ValueChanged<int> onChanged,
    bool center = false,
  }) =>
      TextFormField(
        key: ValueKey(fieldKey),
        initialValue: '$value',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: AppText.heading(size: 16, weight: FontWeight.w500),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.bg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: Radii.smAll,
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: Radii.smAll,
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        // Empty means mid-edit, not zero — leave the model alone until there's
        // a number to apply.
        onChanged: (raw) {
          final parsed = int.tryParse(raw);
          if (parsed != null) onChanged(parsed);
        },
      );

  Widget _addButton(String label, RewardType type, String shopId) =>
      GestureDetector(
        onTap: () => setState(
          () => _tiers = [
            ...?_tiers,
            RewardTier(
              id: generateId(),
              shopId: shopId,
              type: type,
              threshold: type == RewardType.visitCount ? 5 : 3,
              discountPercent: 10,
              label: 'New tier',
              description: 'Discount on your meal',
              emoji: '',
            ),
          ],
        ),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                size: 20,
                color: AppColors.ember2,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                label,
                style: AppText.heading(
                  size: 14,
                  weight: FontWeight.w500,
                  color: AppColors.ember2,
                ),
              ),
            ],
          ),
        ),
      );

  void _update(
    String id, {
    int? threshold,
    int? discountPercent,
    String? label,
  }) =>
      setState(
        () => _tiers = [
          for (final t in _tiers!)
            if (t.id == id)
              t.copyWith(
                threshold: threshold,
                discountPercent: discountPercent,
                label: label,
              )
            else
              t,
        ],
      );

  Future<void> _confirmDelete(RewardTier tier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card2,
        shape: RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Delete tier', style: AppText.heading(size: 18)),
        content: Text(
          'Remove “${tier.label}” from your reward ladder? Vouchers customers '
          'already earned from it stay valid.',
          style: AppText.body(size: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppText.body(size: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppText.body(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _tiers = _tiers!.where((t) => t.id != tier.id).toList());
  }

  Future<void> _save() async {
    final shop = ref.read(storeControllerProvider).value?.ownedShop;
    if (shop == null || _saving) return;

    final normalized = [
      for (final t in _tiers!)
        t.copyWith(
          threshold: t.threshold.clamp(1, _maxThreshold),
          discountPercent: t.discountPercent.clamp(1, _maxDiscount),
          label: t.label.trim().isEmpty ? 'Reward tier' : t.label.trim(),
          description: t.description.trim().isEmpty
              ? 'Discount on your meal'
              : t.description.trim(),
        ),
    ];
    final windowDays = _windowDays.clamp(_minWindowDays, _maxWindowDays);

    setState(() => _saving = true);
    try {
      await ref.read(storeControllerProvider.notifier).updateShop(
            shop.copyWith(
              rewardTiers: normalized,
              streakWindowDays: windowDays,
            ),
          );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _tiers = normalized;
      _windowDays = windowDays;
      _saving = false;
    });
    AppToast.show(context, 'Rewards saved!', type: ToastType.success);
  }
}
