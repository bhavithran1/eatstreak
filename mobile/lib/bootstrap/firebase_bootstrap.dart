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

  return FirebaseServices(
    auth: await FirebaseAuthService.create(),
    repository: FirestoreRepository(),
  );
}

FirebaseOptions _optionsForPlatform() {
  // Each platform gets its own app id; the rest of the config is shared.
  final appId = switch (defaultTargetPlatform) {
    TargetPlatform.iOS when Env.firebaseIosAppId.isNotEmpty => Env.firebaseIosAppId,
    TargetPlatform.android when Env.firebaseAndroidAppId.isNotEmpty =>
      Env.firebaseAndroidAppId,
    _ => Env.firebaseAppId,
  };

  return FirebaseOptions(
    apiKey: Env.firebaseApiKey,
    appId: appId,
    projectId: Env.firebaseProjectId,
    messagingSenderId: Env.firebaseMessagingSenderId,
    authDomain: Env.firebaseAuthDomain.isEmpty ? null : Env.firebaseAuthDomain,
    storageBucket:
        Env.firebaseStorageBucket.isEmpty ? null : Env.firebaseStorageBucket,
    iosBundleId: 'com.eatstreak.app',
  );
}
