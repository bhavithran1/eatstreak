/// The backend seams. All are overridden in main.dart when demo mode is off —
/// keeping the Firebase implementations out of this file means nothing here
/// imports firebase_*, so a demo build never initializes the SDK.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics.dart';
import '../core/config/env.dart';
import '../data/auth/auth_service.dart';
import '../data/auth/demo_auth_service.dart';
import '../data/repositories/demo_repository.dart';
import '../data/repositories/eatstreak_repository.dart';

/// Overridden at startup. The demo defaults let tests and demo builds run with
/// no bootstrapping at all.
final authServiceProvider = Provider<AuthService>((ref) {
  final service = DemoAuthService();
  ref.onDispose(service.dispose);
  return service;
});

final repositoryProvider = Provider<EatStreakRepository>((ref) => DemoRepository());

/// Product analytics. Defaults to a no-op so demo builds, tests and widget
/// previews never try to reach Firebase; main.dart overrides it with the real
/// one once the SDK is up.
final analyticsProvider = Provider<Analytics>((ref) => const NoopAnalytics());

/// True when the app is running against seeded on-device data.
final isDemoModeProvider = Provider<bool>((ref) => Env.demoMode);
