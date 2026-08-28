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

    test('a structured payload never becomes a suggested name', () {
      // Each of these is a QR a customer really does point the app at, and each
      // would have passed the old "under 80 characters" rule. The vCard even
      // contains the shop's real name — as one field of a payload, which is not
      // the same thing as being one.
      for (final raw in [
        'BEGIN:VCARD\nVERSION:3.0\nFN:Warung Pak Cik\nTEL:+60123456789\nEND:VCARD',
        'otpauth://totp/Warung:staff?secret=JBSWY3DPEHPK3PXP&issuer=Warung',
        'tel:+60123456789',
        'EATSTREAK:V1:VOUCHER:EAT-ABC123',
      ]) {
        expect(parseExternalQr(raw).extractedName, isNull, reason: raw);
      }
    });

    test('a host borrowing ours is never offered as a restaurant', () {
      // parseCheckInTarget already refuses to check anyone in here. The
      // external branch then offered "Eatstreak" as the shop to add, lending a
      // hostile code our own brand — found by the eatstreak_host_suffix_spoof
      // fixture in tool/e2e/.
      for (final hostile in [
        'https://eatstreak.app.evil.example/c/shop_ramen?t=abc',
        'https://eatstreak.evil.example/menu',
        'https://EATSTREAK.co/menu',
      ]) {
        final parsed = parseExternalQr(hostile);
        expect(parsed.type, ExternalQrType.url, reason: hostile);
        expect(parsed.extractedName, isNull, reason: hostile);
      }
    });

    test('an ordinary restaurant host is still offered', () {
      // The suppression above must not swallow the normal case.
      expect(parseExternalQr('https://warungpakcik.com.my/menu').extractedName,
          'Warungpakcik');
    });

    test('a long tracking URL still gives up its host', () {
      final parsed = parseExternalQr(
        'https://order.foodpanda.my/restaurant/x9k2/warung-pak-cik'
        '?utm_source=qr&utm_medium=table&utm_campaign=lunch2026'
        '&utm_content=tent-card-a&session=7f3c9b1e2d4a',
      );

      expect(parsed.type, ExternalQrType.url);
      expect(parsed.extractedName, 'Order');
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

    test('an upper-cased host is still ours', () {
      // Some generators upper-case the whole payload to shrink the symbol.
      // Hosts are case-insensitive and Uri normalises them; this pins that we
      // rely on that rather than comparing the raw string.
      final t = parseCheckInTarget('HTTPS://EATSTREAK.APP/c/shop_nonna?t=abc');

      expect(t?.shopId, 'shop_nonna');
      expect(t?.token, 'abc');
    });

    test('a host that merely starts or ends with ours is not ours', () {
      // The check-in link is the only payload in this app that causes a write,
      // so the host test has to be equality and not a prefix or substring
      // match. Each of these passes a looser test and must fail this one.
      for (final hostile in [
        'https://eatstreak.app.evil.example/c/shop_ramen?t=abc',
        'https://noteatstreak.app/c/shop_ramen?t=abc',
        'https://eatstreak.app.co/c/shop_ramen?t=abc',
        'https://evil.example/eatstreak.app/c/shop_ramen?t=abc',
      ]) {
        expect(parseCheckInTarget(hostile), isNull, reason: hostile);
      }
    });

    test('the external fixtures are not check-in codes', () {
      for (final raw in [
        'https://menu.warungpakcik.com.my/table/12',
        'https://www.google.com/maps/place/Restoran+Nasi+Kandar+Pelita/@3.15,101.7,17z',
        'upi://pay?pa=warung@maybank&pn=Warung%20Pak%20Cik&cu=MYR',
        'WIFI:S:WarungPakCik_Guest;T:WPA;P:makanlah123;;',
        'BEGIN:VCARD\nVERSION:3.0\nFN:Warung Pak Cik\nEND:VCARD',
        'otpauth://totp/Warung:staff?secret=JBSWY3DPEHPK3PXP&issuer=Warung',
        'tel:+60123456789',
        'Warung Pak Cik',
        'https://order.foodpanda.my/restaurant/x9k2/warung-pak-cik?utm_source=qr',
        '   ',
      ]) {
        expect(parseCheckInTarget(raw), isNull, reason: raw);
      }
    });
  });

  group('voucher codes', () {
    test('a voucher QR round-trips', () {
      expect(parseVoucherCode(buildVoucherPayload('EAT-ABC123')), 'EAT-ABC123');
    });

    test('a code read aloud and typed in resolves the same voucher', () {
      // The counter fallback: a cracked screen, a dim one, a flat battery. What
      // staff type has to mean the same thing as what the camera reads.
      for (final typed in ['EAT-ABC123', 'eat-abc123', 'ABC123', 'EAT ABC123']) {
        expect(parseVoucherCode(typed), 'EAT-ABC123', reason: typed);
      }
    });

    test('a check-in code is not a voucher', () {
      expect(parseVoucherCode(buildCheckInLink('shop_ramen', token: 'abc')), isNull);
    });

    test('the codes customers actually point a camera at are not vouchers', () {
      for (final raw in [
        'https://menu.warungpakcik.com.my/table/12',
        'upi://pay?pa=warung@maybank&pn=Warung%20Pak%20Cik&cu=MYR',
        'WIFI:S:WarungPakCik_Guest;T:WPA;P:makanlah123;;',
        'Warung Pak Cik',
        '',
        '   ',
      ]) {
        expect(parseVoucherCode(raw), isNull, reason: raw);
      }
    });

    test("a customer's own voucher is never offered as a shop to add", () {
      // The wifi bug again, with our own payload: 'EATSTREAK:V1:VOUCHER:...' is
      // short enough to have passed as a restaurant name.
      final parsed = parseExternalQr(buildVoucherPayload('EAT-ABC123'));

      expect(parsed.extractedName, isNull);
    });
  });
}
