import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/config/env.dart';
import '../data/auth/auth_service.dart';
import '../data/auth/firebase_auth_service.dart';
import '../data/repositories/eatstreak_repository.dart';
import '../data/repositories/firestore_repository.dart';

/// The live backend, ready to override the demo providers with.
class FirebaseServices {
  const FirebaseServices({required this.auth, required this.repository});

  final AuthService auth;
  final EatStreakRepository repository;
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

  await Firebase.initializeApp(options: _optionsForPlatform());
  await _activateAppCheck();

  return FirebaseServices(
    auth: await FirebaseAuthService.create(),
    repository: FirestoreRepository(),
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
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      // App Attest needs a real Apple team; debug builds use a local token you
      // register once in the console.
      // DeviceCheck fallback covers devices where App Attest isn't available,
      // so attestation degrades instead of failing outright.
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    // Never fatal. A device that can't attest (jailbroken, no Play Services,
    // free provisioning) should still reach the sign-in screen; with
    // enforcement off it works normally, and with enforcement on it fails at
    // the call with a clear error rather than a blank launch.
    debugPrint('App Check activation failed: $e');
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
