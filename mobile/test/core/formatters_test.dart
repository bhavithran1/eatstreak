import 'dart:math';

import 'package:eatstreak/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the "voucher codes" block in functions/src/streakLogic.test.ts.
///
/// This file exists because the two generators silently disagreed: this one
/// made four characters while the Cloud Function made six, so a demo voucher
/// never looked like the real thing staff are asked to type. Neither side was
/// tested, so nothing caught it. Asserting the length on both sides means a
/// future change has to move the constant deliberately.
void main() {
  group('generateVoucherCode', () {
    test('carries the EAT- prefix', () {
      expect(generateVoucherCode().startsWith(voucherCodePrefix), isTrue);
    });

    test('body is voucherCodeLength characters', () {
      final code = generateVoucherCode();
      expect(code.length - voucherCodePrefix.length, voucherCodeLength);
    });

    test('length constant is 6 (must match VOUCHER_CODE_LENGTH in streakLogic.ts)', () {
      expect(voucherCodeLength, 6);
    });

    test('never generates I, O, 0 or 1', () {
      // L is deliberately kept — it is only confusable with 1, which is gone.
      final rng = Random(7);
      for (var i = 0; i < 200; i++) {
        final body = generateVoucherCode(rng).substring(voucherCodePrefix.length);
        expect(RegExp(r'[IO01]').hasMatch(body), isFalse, reason: body);
      }
    });

    test('is not constant across calls', () {
      final codes = {for (var i = 0; i < 50; i++) generateVoucherCode()};
      expect(codes.length, greaterThan(1));
    });
  });

  group('normalizeVoucherCode', () {
    // How a code actually arrives when staff read it off a customer's phone.
    test('leaves a correct code alone', () {
      expect(normalizeVoucherCode('EAT-AB3KP9'), 'EAT-AB3KP9');
    });

    test('uppercases', () {
      expect(normalizeVoucherCode('eat-ab3kp9'), 'EAT-AB3KP9');
    });

    test('adds a missing prefix', () {
      expect(normalizeVoucherCode('AB3KP9'), 'EAT-AB3KP9');
      expect(normalizeVoucherCode('ab3kp9'), 'EAT-AB3KP9');
    });

    test('drops spaces, inside and around', () {
      expect(normalizeVoucherCode('EAT- AB3 KP9'), 'EAT-AB3KP9');
      expect(normalizeVoucherCode('  EAT-AB3KP9 \n'), 'EAT-AB3KP9');
    });

    test('drops a stray extra hyphen', () {
      expect(normalizeVoucherCode('EAT-AB3-KP9'), 'EAT-AB3KP9');
    });

    test('empty input stays empty rather than becoming a bare prefix', () {
      expect(normalizeVoucherCode(''), '');
      expect(normalizeVoucherCode('EAT-'), '');
      expect(normalizeVoucherCode('---'), '');
    });

    test('a body that itself begins with EAT survives either way', () {
      expect(normalizeVoucherCode('EAT-EATK79'), 'EAT-EATK79');
      expect(normalizeVoucherCode('EATK79'), 'EAT-EATK79');
    });

    test('forgives formatting but not a wrong code', () {
      expect(normalizeVoucherCode('AB3KP8'), isNot('EAT-AB3KP9'));
    });

    test('round-trips its own output', () {
      expect(normalizeVoucherCode(normalizeVoucherCode('ab3 kp9')), 'EAT-AB3KP9');
    });

    test('accepts anything its own generator produces', () {
      final rng = Random(11);
      for (var i = 0; i < 50; i++) {
        final code = generateVoucherCode(rng);
        expect(normalizeVoucherCode(code.toLowerCase()), code);
        expect(normalizeVoucherCode(code.substring(voucherCodePrefix.length)), code);
      }
    });
  });
}
