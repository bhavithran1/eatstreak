import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/store_scope.dart';

/// How a customer is doing against the shop's return window.
enum CustomerStatus {
  active('Active', AppColors.success),
  atRisk('At risk', AppColors.warning),
  lapsed('Lapsed', AppColors.error);

  const CustomerStatus(this.label, this.color);
  final String label;
  final Color color;
}

typedef _Row = ({
  String userId,
  String name,
  int currentStreak,
  int totalVisits,
  String lastVisit,
  CustomerStatus status,
});

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key, this.initialStatus});

  /// Set when the dashboard's lapsed banner deep-links into this screen.
  final CustomerStatus? initialStatus;

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  CustomerStatus? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialStatus;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StoreScope(builder: (context, state) => _body(context, state));

  Widget _body(BuildContext context, StoreState state) {
    final shop = state.ownedShop;
    final today = todayString();

    final rows = <_Row>[];
    if (shop != null) {
      for (final streak in state.streaks.where((s) => s.shopId == shop.id)) {
        final daysSince = daysBetween(streak.lastVisitDate, today);
        final status = daysSince > shop.streakWindowDays
            ? CustomerStatus.lapsed
            : daysSince > 0
                ? CustomerStatus.atRisk
                : CustomerStatus.active;

        // userName is denormalized onto the streak by the Cloud Function, so
        // owners can show names without reading other users' documents.
        final name = streak.userName?.trim().isNotEmpty == true
            ? streak.userName!
            : 'Customer ${streak.userId.substring(streak.userId.length - 4)}';

        rows.add((
          userId: streak.userId,
          name: name,
          currentStreak: streak.currentStreakDays,
          totalVisits: streak.totalVisits,
          lastVisit: streak.lastVisitDate,
          status: status,
        ));
      }
    }

    final query = _search.trim().toLowerCase();
    final visible = rows
        .where((c) => _filter == null || c.status == _filter)
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

    return AppScreen(
      title: 'Customers',
      onRefresh: ref.read(storeControllerProvider.notifier).refresh,
      children: [
        _searchBox(),
        const SizedBox(height: Spacing.md),
        _filters(),
        const SizedBox(height: Spacing.md),
        if (visible.isEmpty)
          EmptyState(
            icon: Icons.people_outline,
            title: query.isNotEmpty || _filter != null
                ? 'No matching customers'
                : 'No customers yet',
            subtitle: query.isNotEmpty || _filter != null
                ? 'Try another search or status filter.'
                : 'Share your QR code to start collecting customer visits.',
          )
        else
          for (final c in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _card(c),
            ),
      ],
    );
  }

  Widget _searchBox() => Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: Radii.mdAll,
          border: hairline,
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: AppColors.muted2),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                style: AppText.body(size: 15, color: AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: 'Search customers',
                  hintStyle: AppText.body(size: 15, color: AppColors.muted2),
                ),
              ),
            ),
            if (_search.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
                child: const Padding(
                  padding: EdgeInsets.all(Spacing.xs),
                  child: Icon(Icons.cancel, size: 18, color: AppColors.muted2),
                ),
              ),
          ],
        ),
      );

  Widget _filters() => Row(
        children: [
          Expanded(child: _chip(null, 'All')),
          for (final status in CustomerStatus.values) ...[
            const SizedBox(width: 7),
            Expanded(child: _chip(status, status.label)),
          ],
        ],
      );

  Widget _chip(CustomerStatus? status, String label) {
    final selected = _filter == status;

    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: Radii.pillAll,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: AppText.body(
            size: 11,
            weight: FontWeight.w600,
            color: selected ? AppColors.primaryInk : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _card(_Row c) => SurfaceCard(
        shadow: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.card2,
                shape: BoxShape.circle,
                border: Border.all(color: c.status.color, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(initialOf(c.name), style: AppText.heading(size: 18)),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.heading(
                            size: 16,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      _statusBadge(c.status),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Row(
                    children: [
                      _inlineStat(
                        Icons.monitor_heart_outlined,
                        '${c.currentStreak} day streak',
                      ),
                      const SizedBox(width: Spacing.md),
                      _inlineStat(
                        Icons.place_outlined,
                        '${c.totalVisits} visits',
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Last visit: ${formatDate(c.lastVisit)}',
                    style: AppText.body(size: 12, color: AppColors.muted2),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _statusBadge(CustomerStatus status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.12),
          borderRadius: Radii.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              status.label,
              style: AppText.body(
                size: 11,
                weight: FontWeight.w600,
                color: status.color,
              ),
            ),
          ],
        ),
      );

  Widget _inlineStat(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: Spacing.xs),
          Text(text, style: AppText.body(size: 13, weight: FontWeight.w500)),
        ],
      );
}
