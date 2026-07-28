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
  FirebaseServices? services;
  if (!Env.demoMode) {
    try {
      services = await initializeFirebase();
    } catch (e) {
      // Reaching runApp matters more than reaching it fully configured. Every
      // await above this line runs before the first frame, so anything that
      // throws — or times out — leaves the launch screen up with nothing on it
      // and no way to tell what went wrong. Falling through with a message is
      // strictly better than a blank phone.
      runApp(_StartupFailedApp(error: e));
      return;
    }
  }

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

/// Shown when the backend could not be brought up at all. Deliberately depends
/// on nothing but Flutter — whatever failed above, this still has to render.
class _StartupFailedApp extends StatelessWidget {
  const _StartupFailedApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0807),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      size: 44, color: Color(0xFFB6ACA2)),
                  const SizedBox(height: 16),
                  const Text(
                    "EatStreak couldn't start",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFBF6F0),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your connection and reopen the app.\n\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB6ACA2),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
