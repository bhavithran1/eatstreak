import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/errors.dart';
import '../../data/models/enums.dart';
import '../../data/models/shop.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/gradient_button.dart';
import '../shared/widgets/store_scope.dart';
import 'widgets/shop_details_fields.dart';

/// Edit a shop after registration.
///
/// Until this existed the details captured during registration were permanent:
/// a typo in the shop name was on every customer's screen forever, and the
/// address was never captured at all, so shop pages showed a blank location.
class EditShopScreen extends ConsumerStatefulWidget {
  const EditShopScreen({super.key});

  @override
  ConsumerState<EditShopScreen> createState() => _EditShopScreenState();
}

class _EditShopScreenState extends ConsumerState<EditShopScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();

  ShopCategory _category = ShopCategory.other;
  bool _saving = false;

  /// Prefill happens once; later store refreshes must not stomp on edits in
  /// progress.
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  void _prefill(Shop shop) {
    if (_loaded) return;
    _loaded = true;
    _name.text = shop.name;
    _address.text = shop.address;
    _description.text = shop.description;
    _category = shop.category;
  }

  Future<void> _save(Shop shop) async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      await ref.read(storeControllerProvider.notifier).updateShop(
            shop.copyWith(
              name: name,
              address: _address.text.trim(),
              description: _description.text.trim(),
              category: _category,
            ),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(
        context,
        "Couldn't reach the server. Check your connection and try again.",
        type: ToastType.error,
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, friendlyErrorMessage(e), type: ToastType.error);
      return;
    }

    if (!mounted) return;
    AppToast.show(context, 'Shop details saved', type: ToastType.success);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.ownerDashboard);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StoreScope(builder: (context, state) => _body(context, state));

  Widget _body(BuildContext context, StoreState state) {
    final shop = state.ownedShop;

    if (shop == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No shop yet',
              subtitle: 'Register a shop before editing its details.',
              actionLabel: 'Register shop',
              onAction: () => context.push(Routes.registerShop),
            ),
          ),
        ),
      );
    }

    _prefill(shop);

    return AppScreen(
      onBack: () => context.canPop()
          ? context.pop()
          : context.go(Routes.ownerDashboard),
      title: 'Shop details',
      subtitle: 'Customers see this on your shop page.',
      children: [
        ShopDetailsFields(
          nameController: _name,
          addressController: _address,
          descriptionController: _description,
          category: _category,
          onCategoryChanged: (c) => setState(() => _category = c),
          onNameChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.xl),
        GradientButton(
          label: 'Save changes',
          size: GradientButtonSize.lg,
          expand: true,
          busy: _saving,
          onPressed: _name.text.trim().isEmpty ? null : () => _save(shop),
        ),
      ],
    );
  }
}
