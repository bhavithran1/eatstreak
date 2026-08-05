import 'package:eatstreak/core/utils/errors.dart';
import 'package:flutter_test/flutter_test.dart';

/// `errorCode` is the only place the real cause of a failure is ever visible on
/// the dev phone, whose logs this machine cannot read — so it has to survive
/// whatever it is handed, including an object with no `code` at all.
void main() {
  /// Stands in for FirebaseException, which exposes `.code`.
  group('friendlyErrorMessage', () {
    test('unauthenticated asks the user to sign in again', () {
      expect(friendlyErrorMessage(_Coded('unauthenticated')), contains('sign in'));
    });

    test('not-found names the shop', () {
      expect(friendlyErrorMessage(_Coded('not-found')), contains('shop'));
    });

    test('permission-denied says access, not a network problem', () {
      final msg = friendlyErrorMessage(_Coded('permission-denied'));
      expect(msg, contains('access'));
      expect(msg, isNot(contains('connection')));
    });

    // These three are the ones the phone actually produces when App Check
    // starves a Firebase call of a token.
    test('unavailable reads as a network problem', () {
      expect(friendlyErrorMessage(_Coded('unavailable')), contains('connection'));
    });

    test('deadline-exceeded reads as a network problem', () {
      expect(friendlyErrorMessage(_Coded('deadline-exceeded')), contains('connection'));
    });

    test('network-request-failed reads as a network problem', () {
      expect(
        friendlyErrorMessage(_Coded('network-request-failed')),
        contains('connection'),
      );
    });

    test('an unknown code falls back to something generic', () {
      final msg = friendlyErrorMessage(_Coded('some-new-code'));
      expect(msg, isNotEmpty);
      expect(msg, contains('went wrong'));
    });

    test('matching is case-insensitive', () {
      expect(friendlyErrorMessage(_Coded('UNAVAILABLE')), contains('connection'));
    });

    test('null does not throw', () {
      expect(friendlyErrorMessage(null), isNotEmpty);
    });

    test('a plain string error is handled', () {
      expect(friendlyErrorMessage('permission-denied'), contains('access'));
    });

    test('an exception with no code falls back on its string form', () {
      expect(friendlyErrorMessage(Exception('unavailable')), contains('connection'));
    });
  });

  group('errorCode', () {
    test('reads .code when there is one', () {
      expect(errorCode(_Coded('permission-denied')), 'permission-denied');
    });

    test('an object without .code falls back to its string form', () {
      final code = errorCode(_Uncoded());
      expect(code, isNotEmpty);
      expect(code, contains('_Uncoded'));
    });

    test('null is empty, not the word "null"', () {
      expect(errorCode(null), '');
    });

    test('a plain string is itself', () {
      expect(errorCode('boom'), 'boom');
    });

    test('a non-string .code falls back rather than crashing', () {
      expect(() => errorCode(_NumericCode()), returnsNormally);
    });
  });
}

class _Coded implements Exception {
  _Coded(this.code);
  final String code;
}

class _Uncoded implements Exception {}

class _NumericCode implements Exception {
  final int code = 42;
}
