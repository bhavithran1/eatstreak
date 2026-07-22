import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/shop.dart';
import 'pressable_scale.dart';
import 'shop_icon.dart';

/// A shop in a browse list: icon, name, category, optional status line.
class ShopCard extends StatelessWidget {
  const ShopCard({
    super.key,
    required this.shop,
    required this.onTap,
    this.subtitle,
  });

  final Shop shop;
  final VoidCallback onTap;

  /// Streak status or similar, shown in the accent color under the category.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: Radii.lgAll,
          border: hairline,
          boxShadow: Shadows.card,
        ),
        child: Row(
          children: [
            ShopIcon(category: shop.category, size: 48),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.heading(size: 16, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _capitalize(shop.category.wire),
                    style: AppText.body(size: 13),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: AppText.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.ember2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted2),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
