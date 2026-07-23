import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/shop.dart';
import '../../data/models/streak.dart';
import '../../domain/streak_logic.dart';
import '../../domain/streak_service.dart';
import '../../state/store_controller.dart';
import '../shared/widgets/app_screen.dart';
import '../shared/widgets/brand_mark.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/shop_card.dart';
import '../shared/widgets/store_scope.dart';
import '../shared/widgets/streak_card.dart';
import 'how_it_works_sheet.dart';
import 'repair_streak_card.dart';

/// Streaks about to lapse come first — the whole point of the screen is to
/// answer "what needs a visit today".
const _urgencyOrder = {
  StreakUrgency.critical: 0,
  StreakUrgency.warning: 1,
  StreakUrgency.safe: 2,
  StreakUrgency.dead: 3,
};

typedef _ActiveStreak = ({Streak streak, Shop shop, StreakUrgency urgency});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StoreScope(builder: (context, state) => _buildBody(state));

  Widget _buildBody(StoreState state) {
    final active = <_ActiveStreak>[];
    for (final streak in state.streaks) {
      final shop = state.shopById(streak.shopId);
      if (shop == null || streak.totalVisits == 0) continue;
      final refreshed = refreshStreakAlive(streak, shop);
      active.add((
        streak: refreshed,
        shop: shop,
        urgency: streakUrgency(refreshed, shop),
      ));
    }
    active.sort(
      (a, b) => _urgencyOrder[a.urgency]!.compareTo(_urgencyOrder[b.urgency]!),
    );

    final alive = active.where((s) => s.urgency != StreakUrgency.dead).toList();
    final priority = alive.isEmpty ? null : alive.first;
    final urgentCount = active
        .where((s) =>
            s.urgency == StreakUrgency.critical ||
            s.urgency == StreakUrgency.warning)
        .length;
    final readyVouchers = state.vouchers
        .where((v) => !v.isRedeemed && daysFromNow(v.expiresAt) > 0)
        .length;

    final visitedIds = state.streaks.map((s) => s.shopId).toSet();
    final unvisited =
        state.shops.where((s) => !visitedIds.contains(s.id)).toList();

    final query = _search.trim().toLowerCase();
    final discovery = query.isEmpty
        ? unvisited
        : unvisited
            .where((s) =>
                s.name.toLowerCase().contains(query) ||
                s.category.wire.toLowerCase().contains(query))
            .toList();

    // Streaks that just lapsed but are still inside the repair grace period.
    final today = todayString();
    final repairable = [
      for (final s in active)
        if (repairInfo(
          s.streak.currentStreakDays,
          s.streak.lastVisitDate,
          s.streak.brokenStreakDays,
          s.streak.brokenOn,
          today,
          s.shop.streakWindowDays,
        ).isRepairable)
          s,
    ];
    final embers = state.currentUser?.embers ?? 0;

    final firstName = (state.currentUser?.name ?? '').split(' ').first;

    return AppScreen(
      onRefresh: ref.read(storeControllerProvider.notifier).refresh,
      bottomPadding: Spacing.xxl,
      children: [
        _brandRow(state.currentUser?.name ?? ''),
        const SizedBox(height: Spacing.xl),
        Text(
          '${getGreeting()}, ${firstName.isEmpty ? 'there' : firstName}',
          style: AppText.heading(
            size: 28,
            weight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          "Here's what needs your attention today.",
          style: AppText.body(size: 15),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                value: '${alive.length}',
                label: 'active streaks',
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _SummaryCard(
                value: '$readyVouchers',
                label: 'ready to use',
                onTap: () => context.go(Routes.vouchers),
              ),
            ),
          ],
        ),
        for (final r in repairable) ...[
          const SizedBox(height: Spacing.sm),
          RepairStreakCard(streak: r.streak, shop: r.shop, embers: embers),
        ],
        if (urgentCount > 0) ...[
          const SizedBox(height: Spacing.sm),
          _UrgentBanner(
            count: urgentCount,
            onTap: () => context.go(Routes.scanner),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        if (priority != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('Priority streak', style: AppText.sectionTitle),
              ),
              Text(
                'Closest deadline',
                style: AppText.body(size: 11, weight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          StreakCard(
            streak: priority.streak,
            shop: priority.shop,
            size: StreakCardSize.large,
            onTap: () => context.push(Routes.shopDetail(priority.shop.id)),
          ),
          const SizedBox(height: Spacing.lg),
        ],
        if (active.length > 1) ...[
          const SectionHeader(title: 'All streaks'),
          for (final s in active.where((s) => s.streak.id != priority?.streak.id))
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: StreakCard(
                streak: s.streak,
                shop: s.shop,
                onTap: () => context.push(Routes.shopDetail(s.shop.id)),
              ),
            ),
          const SizedBox(height: Spacing.md),
        ],
        if (active.isEmpty) ...[
          EmptyState(
            icon: Icons.monitor_heart_outlined,
            title: 'No streaks yet',
            subtitle: 'Scan a partner QR code to log your first visit and '
                'start tracking progress.',
            actionLabel: 'Open scanner',
            onAction: () => context.go(Routes.scanner),
          ),
          const SizedBox(height: Spacing.sm),
          Center(
            child: Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => showHowItWorks(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.sm),
                  child: Text(
                    'How do streaks work?',
                    style: AppText.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (unvisited.isNotEmpty) ...[
          const SectionHeader(title: 'Discover places'),
          _searchBox(),
          const SizedBox(height: Spacing.sm),
          if (discovery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text(
                'No places match “${_search.trim()}”.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, color: AppColors.muted2),
              ),
            )
          else
            for (final shop in discovery)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: ShopCard(
                  shop: shop,
                  subtitle: '${shop.streakWindowDays}-day window',
                  onTap: () => context.push(Routes.shopDetail(shop.id)),
                ),
              ),
        ],
      ],
    );
  }

  Widget _brandRow(String name) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const BrandMark(size: 30),
              const SizedBox(width: 9),
              Text('EatStreak', style: AppText.heading(size: 18)),
            ],
          ),
          Semantics(
            button: true,
            label: 'Open profile',
            child: GestureDetector(
              onTap: () => context.go(Routes.customerProfile),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.card2,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line2),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? 'E' : initialOf(name),
                  style: AppText.heading(size: 14),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _searchBox() => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
                textInputAction: TextInputAction.search,
                style: AppText.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search by name or category',
                  hintStyle: AppText.body(size: 14, color: AppColors.muted2),
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
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: onTap == null ? '$value $label' : '$value $label, open',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: Radii.lgAll,
            border: hairline,
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppText.heading(size: 28, weight: FontWeight.w700),
                  ),
                  Text(label, style: AppText.body(size: 12)),
                ],
              ),
              if (onTap != null)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    Icons.arrow_forward,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count ${count == 1 ? 'streak needs' : 'streaks need'} a visit. '
          'Open the scanner.',
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: Radii.lgAll,
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.schedule,
                size: 20,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count ${count == 1 ? 'streak needs' : 'streaks need'} a visit',
                    style: AppText.heading(size: 14),
                  ),
                  Text(
                    'Scan today to keep your progress.',
                    style: AppText.body(size: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted2),
          ],
        ),
      ),
      ),
    );
  }
}
