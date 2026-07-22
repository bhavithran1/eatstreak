/// Identity, independent of where profile data lives.
///
/// The repository owns users/{uid} documents; this owns *who is signed in*.
/// Two implementations: [DemoAuthService] (a local identity, no network) and
/// [FirebaseAuthService] (Google / Apple via Firebase Auth).
abstract interface class AuthService {
  /// Emits the signed-in uid, or null when signed out. Emits at least once on
  /// subscribe so the router knows whether to wait or redirect.
  Stream<String?> uidChanges();

  String? get currentUid;

  /// Best-effort display name from the identity provider, used to prefill
  /// onboarding. Null in demo mode.
  String? get providerDisplayName;

  String? get providerEmail;

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();

  /// Whether Sign in with Apple can be offered on this device.
  Future<bool> isAppleSignInAvailable();

  void dispose();
}
