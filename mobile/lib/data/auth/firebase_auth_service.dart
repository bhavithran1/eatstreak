import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/config/env.dart';
import 'auth_service.dart';

/// Real identity, via Firebase Auth. Only constructed when demo mode is off.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService._(this._auth);

  /// Initializes the Google Sign-In SDK before returning, which v7 requires
  /// before any authenticate() call.
  static Future<FirebaseAuthService> create() async {
    await GoogleSignIn.instance.initialize(
      clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
      serverClientId: Env.googleWebClientId.isEmpty ? null : Env.googleWebClientId,
    );
    return FirebaseAuthService._(FirebaseAuth.instance);
  }

  final FirebaseAuth _auth;

  @override
  Stream<String?> uidChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  String? get providerDisplayName => _auth.currentUser?.displayName;

  @override
  String? get providerEmail => _auth.currentUser?.email;

  @override
  Future<void> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Google sign-in did not return an ID token.',
      );
    }

    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  @override
  Future<void> signInWithApple() async {
    // Apple requires a nonce: it receives the SHA-256 hash, Firebase the raw
    // value. That pairing is what stops a stolen token being replayed.
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.fullName,
        AppleIDAuthorizationScopes.email,
      ],
      nonce: hashedNonce,
    );

    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Apple sign-in did not return an identity token.',
      );
    }

    await _auth.signInWithCredential(
      OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn.instance.signOut();
  }

  @override
  Future<bool> isAppleSignInAvailable() => SignInWithApple.isAvailable();

  @override
  void dispose() {}

  static String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
}
