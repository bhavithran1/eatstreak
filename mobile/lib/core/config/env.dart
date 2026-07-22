/// Build-time configuration, supplied with `--dart-define` (or a
/// `--dart-define-from-file=env.json`). These are compile-time constants so the
/// tree-shaker can drop whichever backend isn't selected.
///
/// Demo mode defaults to ON so a fresh clone runs with zero setup. Pass
/// `--dart-define=DEMO_MODE=false` together with the Firebase values below to
/// run against the real backend.
library;

abstract final class Env {
  /// Run entirely on-device against seeded sample data.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

  // ---- Firebase (ignored while demoMode is true) ---------------------------
  /// Web/fallback key. Firebase issues a *separate* API key per platform and
  /// restricts each one — the browser key by HTTP referrer, the mobile keys by
  /// bundle id — so sending the web key from a phone is rejected. Supply the
  /// per-platform keys below; firebase_bootstrap.dart picks the right one.
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseIosApiKey =
      String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const String firebaseAndroidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const String firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String firebaseAndroidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

  /// Must match the region in functions/src/index.ts.
  static const String functionsRegion = 'asia-southeast1';

  // ---- Google Sign-In ------------------------------------------------------
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Domain baked into check-in QR codes. Defaults to the Firebase Hosting
  /// domain derived from the project id. The iOS Associated Domains
  /// entitlement and the Android App Links intent-filter must claim the same
  /// host — see RELEASE_CHECKLIST.md.
  static const String _linkDomainOverride = String.fromEnvironment('LINK_DOMAIN');
  static String get linkDomain => _linkDomainOverride.isNotEmpty
      ? _linkDomainOverride
      : firebaseProjectId.isNotEmpty
          ? '$firebaseProjectId.web.app'
          : 'eatstreak.app';

  /// True when enough Firebase config is present to initialize the SDK.
  static bool get hasFirebaseConfig =>
      firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;
}
