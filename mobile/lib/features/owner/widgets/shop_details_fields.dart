import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';

const shopCategoryOptions =
    <({ShopCategory value, String label, IconData icon})>[
  (value: ShopCategory.coffee, label: 'Coffee', icon: Icons.local_cafe_outlined),
  (value: ShopCategory.ramen, label: 'Ramen', icon: Icons.ramen_dining_outlined),
  (value: ShopCategory.pizza, label: 'Pizza', icon: Icons.local_pizza_outlined),
  (value: ShopCategory.bistro, label: 'Bistro', icon: Icons.wine_bar_outlined),
  (value: ShopCategory.bakery, label: 'Bakery', icon: Icons.bakery_dining_outlined),
  (value: ShopCategory.smoothie, label: 'Smoothie', icon: Icons.local_drink_outlined),
  (value: ShopCategory.brunch, label: 'Brunch', icon: Icons.wb_sunny_outlined),
  (value: ShopCategory.mexican, label: 'Mexican', icon: Icons.restaurant_outlined),
  (value: ShopCategory.other, label: 'Other', icon: Icons.storefront_outlined),
];

/// The shop's editable details. Shared by registration and the edit screen so
/// the two can't drift — a field added here shows up in both.
class ShopDetailsFields extends StatelessWidget {
  const ShopDetailsFields({
    super.key,
    required this.nameController,
    required this.addressController,
    required this.descriptionController,
    required this.category,
    required this.onCategoryChanged,
    this.onNameChanged,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController descriptionController;
  final ShopCategory category;
  final ValueChanged<ShopCategory> onCategoryChanged;
  final ValueChanged<String>? onNameChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Shop name'),
        TextField(
          controller: nameController,
          onChanged: onNameChanged,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: AppText.body(size: 16, color: AppColors.ink),
          decoration: inputDecoration("e.g. Nonna's Kitchen"),
        ),
        const SizedBox(height: Spacing.lg),
        _label('Category'),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final opt in shopCategoryOptions) _chip(opt),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        // Without this a customer can browse to a shop and have no way to find
        // it — the detail screen has nowhere else to get a location from.
        _label('Address'),
        TextField(
          controller: addressController,
          textCapitalization: TextCapitalization.words,
          maxLines: 2,
          minLines: 1,
          style: AppText.body(size: 16, color: AppColors.ink),
          decoration: inputDecoration('Street, area, city'),
        ),
        const SizedBox(height: Spacing.lg),
        _label('Description (optional)'),
        TextField(
          controller: descriptionController,
          maxLines: 3,
          style: AppText.body(size: 16, color: AppColors.ink),
          decoration: inputDecoration(
            'Tell customers what makes your food special…',
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Text(text, style: AppText.heading(size: 15)),
      );

  Widget _chip(({ShopCategory value, String label, IconData icon}) opt) {
    final selected = category == opt.value;

    return Semantics(
      button: true,
      selected: selected,
      label: opt.label,
      child: GestureDetector(
        onTap: () => onCategoryChanged(opt.value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: Radii.pillAll,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                opt.icon,
                size: 16,
                color: selected ? AppColors.primaryInk : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                opt.label,
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w500,
                  color: selected ? AppColors.primaryInk : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration inputDecoration(String hint) => InputDecoration(
      filled: true,
      fillColor: AppColors.card,
      hintText: hint,
      hintStyle: AppText.body(size: 16, color: AppColors.muted2),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Radii.mdAll,
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Radii.mdAll,
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
