import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/enums.dart';

/// Category glyphs, ported from the Expo app's Ionicons mapping to their
/// nearest Material equivalents.
const _categoryIcons = <ShopCategory, IconData>{
  ShopCategory.coffee: Icons.local_cafe_outlined,
  ShopCategory.ramen: Icons.ramen_dining_outlined,
  ShopCategory.pizza: Icons.local_pizza_outlined,
  ShopCategory.bistro: Icons.wine_bar_outlined,
  ShopCategory.bakery: Icons.bakery_dining_outlined,
  ShopCategory.smoothie: Icons.local_drink_outlined,
  ShopCategory.brunch: Icons.wb_sunny_outlined,
  ShopCategory.mexican: Icons.restaurant_outlined,
  ShopCategory.other: Icons.storefront_outlined,
};

enum ShopIconVariant { normal, accent, subtle }

class ShopIcon extends StatelessWidget {
  const ShopIcon({
    super.key,
    required this.category,
    this.size = 44,
    this.variant = ShopIconVariant.normal,
  });

  final ShopCategory category;
  final double size;
  final ShopIconVariant variant;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (variant) {
      ShopIconVariant.accent => (AppColors.primaryInk, AppColors.primary),
      ShopIconVariant.subtle => (AppColors.muted, AppColors.card2),
      ShopIconVariant.normal => (AppColors.primary, AppColors.primarySoft),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size / 2 < Radii.md ? size / 2 : Radii.md),
      ),
      alignment: Alignment.center,
      child: Icon(
        _categoryIcons[category] ?? Icons.storefront_outlined,
        size: (size * 0.46).roundToDouble(),
        color: foreground,
      ),
    );
  }
}
