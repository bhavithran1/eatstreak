import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../../domain/owner_analytics.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/store_scope.dart';

/// How this screen paints a [CustomerStanding].
///
/// The standing itself is decided in `domain/owner_analytics.dart`, so the
/// dashboard's "3 streaks end within a day" and this screen's "At risk" filter
/// are the same set of people. They used to be two definitions: this screen
/// called anyone who had not visited *today* at risk, which on a three-day
/// window is most of a healthy customer base — the filter selected nearly
/// everyone and so pointed at nobody, while the dashboard counted only those
/// already lost.
extension StandingStyle on CustomerStanding {
  String get label => switch (this) {
        CustomerStanding.active => 'Active',
        CustomerStanding.atRisk => 'At risk',
        CustomerStanding.lapsed => 'Lapsed',
      };

  Color get color => switch (this) {
        CustomerStanding.active => AppColors.success,
        CustomerStanding.atRisk => AppColors.warning,
        CustomerStanding.lapsed => AppColors.error,
      };
}

typedef _Row = ({
  String userId,
  String name,
  int currentStreak,
  int totalVisits,
  String lastVisit,
  int daysLeft,
  CustomerStanding status,
});

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key, this.initialStatus});

  /// Set when one of the dashboard's banners deep-links into this screen.
  final CustomerStanding? initialStatus;

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  CustomerStanding? _filter;

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
        final status = standingOf(streak, shop.streakWindowDays, today);

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
          daysLeft: daysUntilExpiry(streak.lastVisitDate, shop.streakWindowDays),
          status: status,
        ));
      }
    }

    final query = _search.trim().toLowerCase();
    final visible = rows
        .where((c) => _filter == null || c.status == _filter)
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(query))
        .toList()
      // At risk first, then active, then lapsed; longest streak within each.
      // Sorting by streak length alone buried the customers the owner can
      // still do something about underneath the ones who are already fine.
      ..sort((a, b) {
        final byStatus = _sortRank(a.status).compareTo(_sortRank(b.status));
        return byStatus != 0
            ? byStatus
            : b.currentStreak.compareTo(a.currentStreak);
      });

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
          for (final status in CustomerStanding.values) ...[
            const SizedBox(width: 7),
            Expanded(child: _chip(status, status.label)),
          ],
        ],
      );

  Widget _chip(CustomerStanding? status, String label) {
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: AppText.body(
              size: 11,
              weight: FontWeight.w600,
              color: selected ? AppColors.primaryInk : AppColors.muted,
            ),
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
                      Flexible(child: _statusBadge(c.status)),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  // Wrap, not Row: both halves are numbers a busy shop grows —
                  // a three-digit streak beside a four-digit visit count runs
                  // off the side of a Row well before the largest text size,
                  // and this pair overflowed by 68pt on a 402pt phone at the
                  // *default* setting. Wrapping puts the second stat on its own
                  // line instead of truncating either of them.
                  Wrap(
                    spacing: Spacing.md,
                    runSpacing: Spacing.xs,
                    children: [
                      _inlineStat(
                        Icons.monitor_heart_outlined,
                        '${c.currentStreak} day streak',
                      ),
                      _inlineStat(
                        Icons.place_outlined,
                        '${c.totalVisits} visits',
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    _lastVisitLine(c),
                    style: AppText.body(
                      size: 12,
                      color: c.status == CustomerStanding.atRisk
                          ? AppColors.warning
                          : AppColors.muted2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// The status pill. Sized to its label rather than a fixed width, and the
  /// label ellipsises: it shares a line with a customer name that owners do
  /// not choose and cannot shorten.
  Widget _statusBadge(CustomerStanding status) => Container(
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
            Flexible(
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 11,
                  weight: FontWeight.w600,
                  color: status.color,
                ),
              ),
            ),
          ],
        ),
      );

  /// When they were last in, and — for the ones still savable — how long the
  /// owner has left to get them back through the door.
  String _lastVisitLine(_Row c) => switch (c.status) {
        CustomerStanding.atRisk when c.daysLeft == 0 =>
          'Last day to keep the streak — last visit '
              '${formatDate(c.lastVisit)}',
        CustomerStanding.atRisk =>
          'One day left — last visit ${formatDate(c.lastVisit)}',
        _ => 'Last visit: ${formatDate(c.lastVisit)}',
      };

  /// An icon and its figure, as a single [Text] rather than a Row.
  ///
  /// A Row cannot wrap: inside the [Wrap] above it is handed the card's width
  /// and overflows the moment the label needs one pixel more, which is what a
  /// large text setting does. Carrying the icon as a [WidgetSpan] lets the
  /// whole stat reflow like the text it is.
  Widget _inlineStat(IconData icon, String text) => Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: Spacing.xs),
                child: Icon(icon, size: 14, color: AppColors.muted),
              ),
            ),
            TextSpan(text: text),
          ],
        ),
        style: AppText.body(size: 13, weight: FontWeight.w500),
      );
}

/// Order the list puts standings in: the savable before the safe, and the
/// already-gone last.
int _sortRank(CustomerStanding status) => switch (status) {
      CustomerStanding.atRisk => 0,
      CustomerStanding.active => 1,
      CustomerStanding.lapsed => 2,
    };
