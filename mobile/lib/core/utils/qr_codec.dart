/// Check-in QR encoding, ported from the Expo app's src/utils/qr.ts.
///
/// Codes encode an https universal link so the stock camera app opens EatStreak
/// (or the hosted fallback page when it isn't installed). The decoder still
/// accepts the older `eatstreak://` and JSON payloads so QR codes printed
/// before the switch keep working.
library;

import 'dart:convert';

import '../config/env.dart';

const appScheme = 'eatstreak';

/// Firebase Hosting serves every site on both domains; accept either.
Set<String> get _checkInHosts => {
      Env.linkDomain,
      if (Env.firebaseProjectId.isNotEmpty) '${Env.firebaseProjectId}.web.app',
      if (Env.firebaseProjectId.isNotEmpty) '${Env.firebaseProjectId}.firebaseapp.com',
    };

/// A resolved EatStreak check-in code: the shop it points at, plus the day's
/// [token] from the owner's screen.
typedef CheckInTarget = ({String shopId, String? token});

/// The canonical link baked into a shop's QR code. The day's [token] rides
/// along as `?t=`, so the same link doubles as the code the owner shows at
/// checkout.
String buildCheckInLink(String shopId, {String? token}) {
  final base = 'https://${Env.linkDomain}/c/${Uri.encodeComponent(shopId)}';
  return token == null || token.isEmpty
      ? base
      : '$base?t=${Uri.encodeComponent(token)}';
}

String encodeQr(String shopId, {String? token}) =>
    buildCheckInLink(shopId, token: token);

/// Pull the shop (and the day's token) out of an EatStreak check-in payload.
/// Returns null for anything that isn't one — the caller then treats it as an
/// external QR.
CheckInTarget? parseCheckInTarget(String data) {
  final trimmed = data.trim();

  // Custom scheme: eatstreak://check-in/<id>[?t=<token>]
  final schemeMatch =
      RegExp(r'^eatstreak://check-in/([^/?#]+)', caseSensitive: false).firstMatch(trimmed);
  if (schemeMatch != null) {
    final uri = Uri.tryParse(trimmed);
    return (
      shopId: Uri.decodeComponent(schemeMatch.group(1)!),
      token: uri?.queryParameters['t'],
    );
  }

  // Universal link: https://<host>/c/<id>[?t=<token>]
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
      final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (_checkInHosts.contains(host) && parts.length >= 2 && parts[0] == 'c') {
        return (
          shopId: Uri.decodeComponent(parts[1]),
          token: uri.queryParameters['t'],
        );
      }
    }
  }

  // Legacy JSON payload: {"s":"<id>","v":1}
  try {
    final parsed = jsonDecode(trimmed);
    if (parsed is Map && parsed['s'] != null && parsed['v'] != null) {
      return (shopId: parsed['s'].toString(), token: null);
    }
  } on FormatException {
    // Not JSON — fall through.
  }

  return null;
}

enum ExternalQrType { googleMaps, url, text, upi }

class ParsedExternalQr {
  const ParsedExternalQr({
    required this.type,
    required this.rawData,
    this.extractedName,
  });

  final ExternalQrType type;
  final String rawData;

  /// Best-effort shop name, used to prefill the "suggest this shop" form.
  final String? extractedName;
}

/// Classify a QR that isn't an EatStreak check-in code, so the app can offer to
/// suggest the place rather than just failing.
ParsedExternalQr parseExternalQr(String data) {
  final trimmed = data.trim();

  if (trimmed.startsWith('upi://')) {
    final name = RegExp(r'pn=([^&]+)').firstMatch(trimmed)?.group(1);
    return ParsedExternalQr(
      type: ExternalQrType.upi,
      rawData: trimmed,
      extractedName: name == null ? null : Uri.decodeComponent(name.replaceAll('+', ' ')),
    );
  }

  if (_isGoogleMapsUrl(trimmed)) {
    return ParsedExternalQr(
      type: ExternalQrType.googleMaps,
      rawData: trimmed,
      extractedName: _nameFromGoogleMaps(trimmed),
    );
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return ParsedExternalQr(
      type: ExternalQrType.url,
      rawData: trimmed,
      extractedName: _nameFromUrl(trimmed),
    );
  }

  return ParsedExternalQr(
    type: ExternalQrType.text,
    rawData: trimmed,
    extractedName: _isMachinePayload(trimmed) || trimmed.isEmpty || trimmed.length >= 80
        ? null
        : trimmed,
  );
}

/// Structured payloads that are plainly not a name a human would type.
///
/// The plain-text branch used to offer any payload under 80 characters as the
/// detected restaurant name. The QR sitting next to a till is very often the
/// shop's guest wifi, and `WIFI:S:Cafe_Guest;T:WPA;P:hunter2;;` is 34 — so the
/// app presented a wifi password as a restaurant name and prefilled it into the
/// suggestion field, one tap away from writing someone's network credentials
/// into `shopSuggestions`. A machine payload has no name in it; the customer
/// can still type the real one.
bool _isMachinePayload(String data) {
  const prefixes = [
    'WIFI:', // wifi join code — carries a password in plaintext
    'BEGIN:', // vCard / vCalendar
    'MATMSG:', // email
    'SMSTO:', // sms
    'TEL:',
    'MAILTO:',
    'BITCOIN:',
    'OTPAUTH:', // 2FA seed — a secret, and never a shop
  ];
  final upper = data.toUpperCase();
  return prefixes.any(upper.startsWith);
}

bool _isGoogleMapsUrl(String url) =>
    url.contains('google.com/maps') ||
    url.contains('maps.google.com') ||
    url.contains('maps.app.goo.gl') ||
    url.contains('goo.gl/maps');

String? _nameFromGoogleMaps(String url) {
  final place = RegExp(r'/place/([^/@?]+)').firstMatch(url);
  if (place != null) {
    return Uri.decodeComponent(place.group(1)!.replaceAll('+', ' '));
  }
  final query = RegExp(r'[?&]q=([^&]+)').firstMatch(url);
  if (query != null) {
    return Uri.decodeComponent(query.group(1)!.replaceAll('+', ' '));
  }
  return null;
}

String? _nameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  final parts = host.split('.');
  if (parts.length < 2) return null;
  final name = parts.first;
  return name.isEmpty ? null : name[0].toUpperCase() + name.substring(1);
}
