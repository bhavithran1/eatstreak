import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/router/deep_links.dart';
import 'core/router/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/pending_check_in.dart';
import 'data/models/enums.dart';
import 'state/auth_controller.dart';

class EatStreakApp extends ConsumerWidget {
  const EatStreakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'EatStreak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // Dark-only, matching the Expo app's userInterfaceStyle.
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => CheckInLinkHost(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Owns both halves of check-in link handling, wrapped around the whole app so
/// it outlives any individual screen:
///
///  - incoming links, via [DeepLinkService];
///  - links that arrived too early to act on. The router parks the shop id when
///    `/check-in/<id>` is opened while signed out or mid-onboarding, and this
///    picks it up the moment the account is ready.
class CheckInLinkHost extends ConsumerStatefulWidget {
  const CheckInLinkHost({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<CheckInLinkHost> createState() => _CheckInLinkHostState();
}

class _CheckInLinkHostState extends ConsumerState<CheckInLinkHost> {
  late final DeepLinkService _links = DeepLinkService(widget.router);
  bool _resuming = false;

  @override
  void initState() {
    super.initState();
    unawaited(_links.start());
  }

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final wasReady = previous != null &&
          previous.isSignedIn &&
          previous.isOnboarded;
      if (next.isSignedIn && next.isOnboarded && !wasReady) {
        _resume(next.role);
      }
    });

    return widget.child;
  }

  Future<void> _resume(UserRole? role) async {
    if (_resuming) return;
    _resuming = true;

    // Read-and-clear regardless of role: a parked link an owner can't act on
    // shouldn't linger and fire during some unrelated later session.
    final pending = await consumePendingCheckIn();
    _resuming = false;

    if (pending == null || role == UserRole.owner || !mounted) return;
    widget.router.go(
      Routes.checkInFor(pending.shopId, token: pending.token),
    );
  }
}
