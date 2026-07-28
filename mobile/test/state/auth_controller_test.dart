import 'dart:async';

import 'package:eatstreak/data/auth/auth_service.dart';
import 'package:eatstreak/data/models/enums.dart';
import 'package:eatstreak/data/models/user.dart';
import 'package:eatstreak/data/repositories/demo_repository.dart';
import 'package:eatstreak/state/auth_controller.dart';
import 'package:eatstreak/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// What happens when the signed-in user's profile cannot be read.
///
/// This used to be the app's worst failure: the state update sat after an
/// unguarded `await`, so any throw or stall left `initializing` true forever
/// and the router held the user on the splash spinner — no error, no retry,
/// nothing to do but reinstall. Every backend failure looked identical from the
/// outside, and identical to a hang.
void main() {
  const uid = 'user_123';

  /// Signed in as [uid] from the first event, like a restored session.
  final signedIn = _FakeAuth(uid);

  ProviderContainer containerWith(DemoRepository repo) {
    final c = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(signedIn),
        repositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Pump until [test] holds, so we wait on the state rather than a fixed delay.
  Future<AuthState> settle(
    ProviderContainer c,
    bool Function(AuthState) test,
  ) async {
    for (var i = 0; i < 200; i++) {
      final s = c.read(authControllerProvider);
      if (test(s)) return s;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return c.read(authControllerProvider);
  }

  test('a readable profile signs the user in', () async {
    final c = containerWith(_Repo(profile: _user(uid)));
    c.read(authControllerProvider); // start the controller

    final s = await settle(c, (s) => !s.initializing);

    expect(s.initializing, isFalse);
    expect(s.uid, uid);
    expect(s.isOnboarded, isTrue);
    expect(s.profileError, isNull);
  });

  test('a missing profile is not an error — it means onboarding', () async {
    final c = containerWith(_Repo(profile: null));
    c.read(authControllerProvider);

    final s = await settle(c, (s) => !s.initializing);

    expect(s.uid, uid);
    expect(s.isOnboarded, isFalse);
    expect(s.profileError, isNull,
        reason: 'a brand new account must still reach onboarding');
  });

  test('a failed read stops initializing instead of spinning forever', () async {
    final c = containerWith(_Repo(error: StateError('permission-denied')));
    c.read(authControllerProvider);

    final s = await settle(c, (s) => !s.initializing);

    expect(s.initializing, isFalse,
        reason: 'the splash spinner is gated on this and never cleared before');
    expect(s.profileError, isNotNull);
  });

  test('a failed read keeps the uid, so onboarding is not repeated', () async {
    final c = containerWith(_Repo(error: StateError('unavailable')));
    c.read(authControllerProvider);

    final s = await settle(c, (s) => !s.initializing);

    expect(s.uid, uid, reason: 'they are signed in; only the profile is missing');
    expect(s.isOnboarded, isFalse);
    expect(s.profileError, isNotNull,
        reason:
            'without this, "could not load" is indistinguishable from "no account "'
            'and the router walks an existing user back through onboarding');
  });

  test('retry clears the error and picks up the profile', () async {
    final repo = _Repo(error: StateError('unavailable'));
    final c = containerWith(repo);
    c.read(authControllerProvider);
    await settle(c, (s) => s.profileError != null);

    // Whatever was wrong is now fixed.
    repo.error = null;
    repo.profile = _user(uid);
    await c.read(authControllerProvider.notifier).retryProfileLoad();

    final s = c.read(authControllerProvider);
    expect(s.profileError, isNull);
    expect(s.isOnboarded, isTrue);
    expect(s.role, UserRole.customer);
  });
}

AppUser _user(String id) => AppUser(
      id: id,
      name: 'Zalk',
      email: 'z@example.com',
      role: UserRole.customer,
      joinedAt: '2026-01-01',
    );

/// DemoRepository with `getUser` replaced; every other method is inherited and
/// unused here.
class _Repo extends DemoRepository {
  _Repo({this.profile, this.error});

  AppUser? profile;
  Object? error;

  @override
  Future<AppUser?> getUser(String id) async {
    if (error != null) throw error!;
    return profile;
  }
}

class _FakeAuth implements AuthService {
  _FakeAuth(this._uid);

  final String? _uid;

  @override
  Stream<String?> uidChanges() => Stream<String?>.value(_uid);

  @override
  String? get currentUid => _uid;

  @override
  String? get providerDisplayName => null;

  @override
  String? get providerEmail => null;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> isAppleSignInAvailable() async => false;

  @override
  void dispose() {}
}
