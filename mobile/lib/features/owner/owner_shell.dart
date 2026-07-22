import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../shared/widgets/app_nav_bar.dart';

/// Owner bottom navigation. Five flat destinations — unlike the customer shell
/// there's no single dominant action, so nothing is raised.
class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = <NavDestination>[
    (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Dashboard'),
    (icon: Icons.qr_code_2_outlined, active: Icons.qr_code_2, label: 'QR Code'),
    (icon: Icons.card_giftcard_outlined, active: Icons.card_giftcard, label: 'Rewards'),
    (icon: Icons.people_outline, active: Icons.people, label: 'Customers'),
    (icon: Icons.person_outline, active: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: navigationShell,
      bottomNavigationBar: AppNavBar(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
