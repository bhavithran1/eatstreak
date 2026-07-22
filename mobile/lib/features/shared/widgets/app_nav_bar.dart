import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// One bottom-nav destination.
typedef NavDestination = ({IconData icon, IconData active, String label});

/// Bottom navigation shared by the customer and owner shells. One item may be
/// [raisedIndex] — drawn as a gradient circle above the bar for the primary
/// action of that role (Scan for customers, QR code for owners).
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.raisedIndex,
  });

  final List<NavDestination> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? raisedIndex;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(top: 9, bottom: bottomPad > 0 ? bottomPad : 10),
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavItem(
                item: items[i],
                selected: currentIndex == i,
                raised: raisedIndex == i,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.raised,
    required this.onTap,
  });

  final NavDestination item;
  final bool selected;
  final bool raised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: raised ? _raised() : _flat(),
      ),
    );
  }

  Widget _raised() => Transform.translate(
        offset: const Offset(0, -18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg2, width: 3),
                boxShadow: Shadows.primaryGlow,
              ),
              child: Icon(item.active, size: 26, color: AppColors.primaryInk),
            ),
            const SizedBox(height: 2),
            _label(),
          ],
        ),
      );

  Widget _flat() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? item.active : item.icon,
            size: 24,
            color: selected ? AppColors.ember2 : AppColors.muted2,
          ),
          const SizedBox(height: 2),
          _label(),
        ],
      );

  Widget _label() => Text(
        item.label,
        style: AppText.body(
          size: 11,
          weight: FontWeight.w500,
          color: selected ? AppColors.ember2 : AppColors.muted2,
        ),
      );
}
