import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth/auth_service.dart';
import '../data/models/enums.dart';
import '../data/models/user.dart';
import '../data/repositories/demo_repository.dart';
import '../data/repositories/eatstreak_repository.dart';
import 'providers.dart';

/// Who is signed in, and whether they've finished onboarding.
class AuthState {
  const AuthState({this.uid, this.userDoc, this.initializing = true});

  final String? uid;
  final AppUser? userDoc;

  /// True until the first auth event arrives — the router waits on this rather
  /// than flashing the sign-in screen at a signed-in user.
  final bool initializing;

  bool get isSignedIn => uid != null;

  /// A users/{uid} document existing is what marks onboarding complete.
  bool get isOnboarded => userDoc != null;

  UserRole? get role => userDoc?.role;

  AuthState copyWith({
    String? uid,
    AppUser? userDoc,
    bool? initializing,
    bool clearUid = false,
    bool clearUserDoc = false,
  }) =>
      AuthState(
        uid: clearUid ? null : (uid ?? this.uid),
        userDoc: clearUserDoc ? null : (userDoc ?? this.userDoc),
        initializing: initializing ?? this.initializing,
      );
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription<String?>? _sub;

  AuthService get _auth => ref.read(authServiceProvider);
  EatStreakRepository get _repo => ref.read(repositoryProvider);

  @override
  AuthState build() {
    _sub = _auth.uidChanges().listen(_onUidChanged);
    ref.onDispose(() => _sub?.cancel());
    return const AuthState();
  }

  Future<void> _onUidChanged(String? uid) async {
    if (uid == null) {
      unawaited(ref.read(analyticsProvider).setUser(null));
      state = const AuthState(initializing: false);
      return;
    }
    // Null until onboarding writes the profile — that's what routes a brand new
    // account to /onboarding rather than straight into the app.
    final doc = await _repo.getUser(uid);
    // Identifying here rather than at the sign-in button covers every way an
    // account arrives, including a session restored at launch — which is most
    // of them, and the reason the console showed no users.
    unawaited(ref.read(analyticsProvider).setUser(uid, role: doc?.role));
    state = AuthState(uid: uid, userDoc: doc, initializing: false);
  }

  Future<void> signInWithGoogle() async {
    await _auth.signInWithGoogle();
    unawaited(ref.read(analyticsProvider).signedIn('google'));
  }

  Future<void> signInWithApple() async {
    await _auth.signInWithApple();
    unawaited(ref.read(analyticsProvider).signedIn('apple'));
  }

  Future<bool> isAppleSignInAvailable() => _auth.isAppleSignInAvailable();

  /// Create the profile document that completes onboarding.
  Future<AppUser> completeOnboarding(String name, UserRole role) async {
    final uid = state.uid;
    if (uid == null) {
      throw StateError('Not signed in.');
    }

    final resolvedName = name.trim().isNotEmpty
        ? name.trim()
        : (_auth.providerDisplayName ?? 'Guest');

    final repo = _repo;
    AppUser user;

    if (repo is DemoRepository) {
      // Re-seed so the sample streaks, visits and vouchers carry the name just
      // chosen rather than the placeholder the lazy seed used.
      final seeded = await repo.seed(resolvedName);
      user = seeded.copyWith(role: role);
    } else {
      user = AppUser(
        id: uid,
        name: resolvedName,
        email: _auth.providerEmail ?? '',
        role: role,
        joinedAt: DateTime.now().toIso8601String(),
      );
    }

    await repo.updateUser(user);
    final analytics = ref.read(analyticsProvider);
    unawaited(analytics.setUser(uid, role: role));
    unawaited(analytics.onboarded(role));
    state = state.copyWith(userDoc: user);
    return user;
  }

  /// Re-read the profile after something changed it (e.g. a role switch).
  Future<void> refreshUserDoc() async {
    final uid = state.uid;
    if (uid == null) return;
    state = state.copyWith(userDoc: await _repo.getUser(uid));
  }

  Future<void> signOut() async {
    final repo = _repo;
    // In demo mode sign-out is only reachable from "reset all data", so wipe
    // the playground rather than leaving a half-used world behind.
    if (repo is DemoRepository) {
      await repo.clear();
    }
    await _auth.signOut();
    state = const AuthState(initializing: false);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience selectors so widgets rebuild on only what they use.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider.select((s) => s.uid)),
);

final currentRoleProvider = Provider<UserRole?>(
  (ref) => ref.watch(authControllerProvider.select((s) => s.role)),
);

