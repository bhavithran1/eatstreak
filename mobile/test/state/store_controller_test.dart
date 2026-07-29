import 'package:eatstreak/data/models/enums.dart';
import 'package:eatstreak/data/models/shop.dart';
import 'package:eatstreak/data/models/streak.dart';
import 'package:eatstreak/data/models/user.dart';
import 'package:eatstreak/data/models/visit.dart';
import 'package:eatstreak/data/models/voucher.dart';
import 'package:eatstreak/data/auth/auth_service.dart';
import 'package:eatstreak/data/repositories/demo_repository.dart';
import 'package:eatstreak/data/repositories/firestore_repository.dart';
import 'package:eatstreak/state/auth_controller.dart';
import 'package:eatstreak/state/providers.dart';
import 'package:eatstreak/state/store_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the store reports when one of its four reads fails.
///
/// Bare, they are indistinguishable: `shops`, `streaks`, `vouchers` and `visits`
/// have four different rule blocks and index requirements, and a failure in any
/// of them used to reach the screen as the same "check your connection". On a
/// device whose logs we cannot read, *which read and which code* is the entire
/// diagnosis, so it is asserted rather than trusted to a comment.
void main() {
  const uid = 'user_123';

  Future<Object?> loadError(_Repo repo) async {
    final c = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuth(uid)),
        repositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);

    c.read(authControllerProvider);
    for (var i = 0; i < 200; i++) {
      final auth = c.read(authControllerProvider);
      final store = c.read(storeControllerProvider);
      if (!auth.initializing && !store.isLoading) return store.error;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return c.read(storeControllerProvider).error;
  }

  test('a failed shops read names shops', () async {
    final error = await loadError(_Repo(shopsError: _Coded('permission-denied')));

    expect(error, isA<StoreLoadException>());
    final e = error as StoreLoadException;
    expect(e.step, 'shops');
    expect(e.code, 'permission-denied');
  });

  test('a failed visits read names visits, not the reads that succeeded',
      () async {
    final error =
        await loadError(_Repo(visitsError: _Coded('failed-precondition')));

    final e = error as StoreLoadException;
    expect(e.step, 'visits',
        reason: 'a missing composite index only ever hits the visits query');
    expect(e.code, 'failed-precondition');
  });

  test('a document the app cannot parse is named on screen', () async {
    // The failure mode that reads as a network problem but is not: every model
    // casts `json['id']` unconditionally, so one document missing the field
    // fails the read. Without the path there is nothing to go and look at.
    final error = await loadError(
      _Repo(
        vouchersError: DocumentParseException(
          'vouchers/user_123_tier_3',
          TypeError(),
        ),
      ),
    );

    final e = error as StoreLoadException;
    expect(e.step, 'vouchers');
    expect(e.code, contains('vouchers/user_123_tier_3'));
  });

  test('an uncoded failure reports its type rather than an empty code',
      () async {
    // What a document the app cannot parse leaves behind: no `code` getter at
    // all. Falling back to the empty string would have printed "streaks · " and
    // said nothing.
    final error = await loadError(
      _Repo(streaksError: TypeError()),
    );

    final e = error as StoreLoadException;
    expect(e.step, 'streaks');
    expect(e.code, isNotEmpty);
  });

  test('all four reads succeeding leaves no error', () async {
    expect(await loadError(_Repo()), isNull);
  });

  group('retry policy', () {
    // Riverpod's default retries every non-Error ten times with exponential
    // backoff — ~38 seconds of spinner before a permission-denied that was
    // never going to change is finally shown. The numbers are asserted, not
    // described, because that is the whole of the fix.
    StoreLoadException failure(String code) =>
        StoreLoadException('shops', _Coded(code));

    test('a dead network is worth trying again, briefly', () {
      expect(retryStoreLoad(0, failure('unavailable')), storeLoadRetryDelay);
      expect(retryStoreLoad(1, failure('deadline-exceeded')),
          storeLoadRetryDelay);
      expect(storeLoadRetryDelay, const Duration(milliseconds: 300));
    });

    test('it gives up after two attempts rather than ten', () {
      expect(maxStoreLoadRetries, 2);
      expect(retryStoreLoad(maxStoreLoadRetries, failure('unavailable')), isNull);
    });

    test('a decision the backend already made is not retried at all', () {
      // These fail identically on the eleventh attempt. Retrying them only
      // delays the one thing that helps: telling the user which one it is.
      expect(retryStoreLoad(0, failure('permission-denied')), isNull);
      expect(retryStoreLoad(0, failure('failed-precondition')), isNull);
      expect(retryStoreLoad(0, failure('unauthenticated')), isNull);
      expect(
        retryStoreLoad(
          0,
          StoreLoadException(
            'shops',
            DocumentParseException('shops/abc123', TypeError()),
          ),
        ),
        isNull,
      );
    });
  });
}

/// A Firebase-shaped failure: what matters is the `code` getter.
class _Coded implements Exception {
  _Coded(this.code);
  final String code;
}

/// DemoRepository with the store's four reads replaced. `getUser` returns a
/// profile so the controller gets past onboarding and actually loads.
class _Repo extends DemoRepository {
  _Repo({
    this.shopsError,
    this.streaksError,
    this.vouchersError,
    this.visitsError,
  });

  final Object? shopsError;
  final Object? streaksError;
  final Object? vouchersError;
  final Object? visitsError;

  @override
  Future<AppUser?> getUser(String id) async => AppUser(
        id: id,
        name: 'Zalk',
        email: 'z@example.com',
        role: UserRole.customer,
        joinedAt: '2026-01-01',
      );

  @override
  Future<List<Shop>> getShops() async {
    if (shopsError != null) throw shopsError!;
    return const [];
  }

  @override
  Future<List<Streak>> getStreaksForUser(String userId) async {
    if (streaksError != null) throw streaksError!;
    return const [];
  }

  @override
  Future<List<Voucher>> getVouchersForUser(String userId) async {
    if (vouchersError != null) throw vouchersError!;
    return const [];
  }

  @override
  Future<List<Visit>> getVisitsForUser(String userId, {String? since}) async {
    if (visitsError != null) throw visitsError!;
    return const [];
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
