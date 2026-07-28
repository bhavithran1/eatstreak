import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/analytics/analytics.dart';
import '../core/analytics/firebase_analytics_service.dart';
import '../core/config/env.dart';
import '../data/auth/auth_service.dart';
import '../data/auth/firebase_auth_service.dart';
import '../data/repositories/eatstreak_repository.dart';
import '../data/repositories/firestore_repository.dart';

/// The live backend, ready to override the demo providers with.
class FirebaseServices {
  const FirebaseServices({
    required this.auth,
    required this.repository,
    required this.analytics,
  });

  final AuthService auth;
  final EatStreakRepository repository;
  final Analytics analytics;
}

/// Firebase startup, isolated here so main.dart is the only other file that
/// knows the real backend exists. Config comes from --dart-define (see
/// core/config/env.dart) rather than checked-in google-services files, so one
/// checkout can target different projects.
Future<FirebaseServices> initializeFirebase() async {
  if (!Env.hasFirebaseConfig) {
    throw StateError(
      'Firebase config missing. Either build with --dart-define=DEMO_MODE=true, '
      'or supply FIREBASE_API_KEY, FIREBASE_PROJECT_ID and FIREBASE_APP_ID.',
    );
  }

  // Local and fast, but bounded anyway: everything below depends on it, and a
  // startup step with no ceiling is indistinguishable from a frozen app.
  await Firebase.initializeApp(options: _optionsForPlatform())
      .timeout(const Duration(seconds: 20));

  // Deliberately not awaited. Attestation is best-effort and the app works
  // without it while enforcement is off, so it must never sit between the user
  // and the first frame — see _activateAppCheck.
  unawaited(_activateAppCheck());

  return FirebaseServices(
    auth: await FirebaseAuthService.create(),
    repository: FirestoreRepository(),
    analytics: FirebaseAnalyticsService.instance(),
  );
}

/// Attest that requests come from this app.
///
/// Firebase config is public by design, so without App Check anyone holding the
/// values in env.json can call `checkIn` or read Firestore straight from a
/// script. Security rules still gate *what* an authenticated user may touch;
/// App Check gates *what client* may ask at all.
///
/// Enforcement is a console setting, deliberately left to the owner. Activating
/// here only makes the app start sending tokens — turn enforcement on in the
/// Firebase console once you can see those tokens arriving, or you lock out
/// every build that is already installed, including your own.
///
/// Never fatal, and never blocking. A device that can't attest (jailbroken, no
/// Play Services, free provisioning) must still reach the sign-in screen. The
/// `catch` below was meant to guarantee that and only half did: it covers
/// activation *failing*, not activation *never returning*.
///
/// That gap was the bug. A release build uses the App Attest provider, App
/// Attest needs a real Apple team, and a free-provisioning build does not have
/// one — so on the developer's own phone `activate()` sat there instead of
/// throwing. `initializeFirebase` awaited it, `main` awaited that, and `runApp`
/// was never reached: no first frame, no error, no spinner of ours, just the
/// launch screen forever. Exactly the "blank launch" this comment already
/// promised would not happen.
///
/// So: a ceiling on the wait, and the caller does not await it at all.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance
        .activate(
          // App Attest needs a real Apple team; debug builds use a local token
          // you register once in the console.
          // DeviceCheck fallback covers devices where App Attest isn't
          // available, so attestation degrades instead of failing outright.
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
        )
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    // With enforcement off — which is the documented state until tokens are
    // visibly arriving — an unattested client still works normally. With it on,
    // calls fail at the call site with a clear error, which is a far better
    // failure than a launch that never completes.
    debugPrint('App Check activation failed or timed out: $e');
  }
}

FirebaseOptions _optionsForPlatform() {
  // Each platform gets its own app id *and* its own API key — Firebase
  // restricts them per platform, so crossing the wires fails at runtime rather
  // than at build time. Both fall back to the web values.
  final appId = switch (defaultTargetPlatform) {
    TargetPlatform.iOS when Env.firebaseIosAppId.isNotEmpty => Env.firebaseIosAppId,
    TargetPlatform.android when Env.firebaseAndroidAppId.isNotEmpty =>
      Env.firebaseAndroidAppId,
    _ => Env.firebaseAppId,
  };

  final apiKey = switch (defaultTargetPlatform) {
    TargetPlatform.iOS when Env.firebaseIosApiKey.isNotEmpty => Env.firebaseIosApiKey,
    TargetPlatform.android when Env.firebaseAndroidApiKey.isNotEmpty =>
      Env.firebaseAndroidApiKey,
    _ => Env.firebaseApiKey,
  };

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    projectId: Env.firebaseProjectId,
    messagingSenderId: Env.firebaseMessagingSenderId,
    authDomain: Env.firebaseAuthDomain.isEmpty ? null : Env.firebaseAuthDomain,
    storageBucket:
        Env.firebaseStorageBucket.isEmpty ? null : Env.firebaseStorageBucket,
    // Must match PRODUCT_BUNDLE_IDENTIFIER in the Xcode project and the iOS app
    // registered in the Firebase console.
    iosBundleId: 'com.eatstreak.app',
  );
}
