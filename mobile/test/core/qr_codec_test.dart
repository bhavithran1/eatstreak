import 'package:eatstreak/core/utils/qr_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the scanner does with codes that are *not* EatStreak codes.
///
/// These payloads come from tool/e2e/qr_fixtures.py, where they are rendered as
/// real QR images and replayed through the app on the simulator. Same strings,
/// asserted here at the unit level so a regression fails in `flutter test`
/// rather than only in a screenshot someone has to look at.
void main() {
  group('parseExternalQr name extraction', () {
    test('a Google Maps place link gives up the restaurant name', () {
      final p = parseExternalQr(
        'https://www.google.com/maps/place/Restoran+Nasi+Kandar+Pelita/@3.1578,101.7118,17z',
      );

      expect(p.type, ExternalQrType.googleMaps);
      expect(p.extractedName, 'Restoran Nasi Kandar Pelita');
    });

    test('a payment code gives up the payee name', () {
      final p = parseExternalQr('upi://pay?pa=warung@maybank&pn=Warung%20Pak%20Cik&cu=MYR');

      expect(p.type, ExternalQrType.upi);
      expect(p.extractedName, 'Warung Pak Cik');
    });

    test('a menu URL falls back to the host', () {
      final p = parseExternalQr('https://menu.warungpakcik.com.my/table/12');

      expect(p.type, ExternalQrType.url);
      expect(p.extractedName, 'Menu');
    });

    // The QR next to the till is very often the guest wifi. Offering its
    // payload as the detected restaurant name put a plaintext password in the
    // suggestion field, one tap from being written to shopSuggestions.
    test('a wifi join code is never offered as a restaurant name', () {
      final p = parseExternalQr('WIFI:S:WarungPakCik_Guest;T:WPA;P:makanlah123;;');

      expect(p.type, ExternalQrType.text);
      expect(p.rawData, contains('makanlah123'),
          reason: 'the raw payload is still reported, for the suggestion record');
      expect(p.extractedName, isNull,
          reason: 'but it must never be prefilled as a name');
    });

    test('other machine payloads are not names either', () {
      for (final raw in [
        'BEGIN:VCARD\nFN:Ali\nEND:VCARD',
        'SMSTO:+60123456789:table 4',
        'TEL:+60123456789',
        'MAILTO:hi@warung.my',
        'otpauth://totp/Warung?secret=JBSWY3DPEHPK3PXP',
      ]) {
        expect(parseExternalQr(raw).extractedName, isNull, reason: raw);
      }
    });

    test('a short plain name still comes through', () {
      expect(parseExternalQr('Warung Pak Cik').extractedName, 'Warung Pak Cik');
    });

    test('whitespace and overlong text yield no name', () {
      expect(parseExternalQr('   ').extractedName, isNull);
      expect(parseExternalQr('x' * 200).extractedName, isNull);
    });
  });

  group('parseCheckInTarget', () {
    // Built with buildCheckInLink rather than pasted, because the accepted host
    // comes from Env.linkDomain: a unit test has no --dart-define, so hardcoding
    // the production host asserts against a domain this build does not accept.
    // The same coupling is why tool/e2e/env.e2e.json pins LINK_DOMAIN to the
    // host the QR fixtures are generated for.
    test('a universal link carries the shop and the day token', () {
      final t = parseCheckInTarget(
        buildCheckInLink('shop_ramen', token: 'demo_shop_ramen_TESTTOKEN'),
      );

      expect(t?.shopId, 'shop_ramen');
      expect(t?.token, 'demo_shop_ramen_TESTTOKEN');
    });

    test('a link with no token still resolves the shop', () {
      final t = parseCheckInTarget(buildCheckInLink('shop_ramen'));

      expect(t?.shopId, 'shop_ramen');
      expect(t?.token, isNull);
    });

    test('the legacy scheme still works', () {
      final t = parseCheckInTarget('eatstreak://check-in/shop_ramen?t=abc');

      expect(t?.shopId, 'shop_ramen');
      expect(t?.token, 'abc');
    });

    test('someone else on a check-in-shaped path is not ours', () {
      expect(parseCheckInTarget('https://evil.example.com/c/shop_ramen'), isNull);
    });

    test('the external fixtures are not check-in codes', () {
      for (final raw in [
        'https://menu.warungpakcik.com.my/table/12',
        'upi://pay?pa=warung@maybank&pn=Warung%20Pak%20Cik&cu=MYR',
        'WIFI:S:WarungPakCik_Guest;T:WPA;P:makanlah123;;',
        '   ',
      ]) {
        expect(parseCheckInTarget(raw), isNull, reason: raw);
      }
    });
  });
}
