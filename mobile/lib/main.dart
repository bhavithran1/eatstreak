import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap/firebase_bootstrap.dart';
import 'core/config/env.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In demo mode the default on-device providers in state/providers.dart stand,
  // so nothing here touches Firebase and the app runs with zero configuration.
  final services = Env.demoMode ? null : await initializeFirebase();

  runApp(
    ProviderScope(
      overrides: [
        if (services != null) ...[
          authServiceProvider.overrideWithValue(services.auth),
          repositoryProvider.overrideWithValue(services.repository),
          analyticsProvider.overrideWithValue(services.analytics),
        ],
      ],
      child: const EatStreakApp(),
    ),
  );
}
