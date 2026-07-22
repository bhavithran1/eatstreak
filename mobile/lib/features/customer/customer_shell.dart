import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../shared/widgets/app_nav_bar.dart';

/// Customer bottom navigation. Scan sits in the middle as a raised gradient
/// button because it's the one action the whole app exists to make easy.
class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _scanIndex = 1;

  static const _items = <NavDestination>[
    (
      icon: Icons.local_fire_department_outlined,
      active: Icons.local_fire_department,
      label: 'Home'
    ),
    (icon: Icons.qr_code_scanner, active: Icons.qr_code_scanner, label: 'Scan'),
    (
      icon: Icons.confirmation_number_outlined,
      active: Icons.confirmation_number,
      label: 'Vouchers'
    ),
    (icon: Icons.person_outline, active: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // The scanner is a full-bleed camera surface; resizing it around the
      // keyboard would letterbox the preview.
      resizeToAvoidBottomInset: navigationShell.currentIndex != _scanIndex,
      body: navigationShell,
      bottomNavigationBar: AppNavBar(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        raisedIndex: _scanIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          // Tapping the active tab returns it to its root — the usual
          // bottom-nav convention.
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
