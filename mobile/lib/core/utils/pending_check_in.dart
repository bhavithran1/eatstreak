/// A check-in deep link opened while signed out (or not yet onboarded) is parked
/// here, survives the sign-in round trip and onboarding — including process
/// death — and is consumed by the routing hub once the user can actually act.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _key = 'eatstreak.pendingCheckIn';

/// A parked check-in: the shop, plus the day's code that came with the link.
typedef PendingCheckIn = ({String shopId, String? token});

/// The user is standing in the restaurant when they scan; a check-in resumed
/// hours later would log a visit they never made.
const _ttl = Duration(minutes: 30);

Future<void> setPendingCheckIn(String shopId, {String? token}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _key,
    jsonEncode({
      'shopId': shopId,
      // The check-in is rejected without the shop's code for the day, so
      // parking the link without it guarantees the resumed check-in fails —
      // which is exactly the moment a brand-new customer first uses the app.
      if (token != null && token.isNotEmpty) 'token': token,
      'at': DateTime.now().millisecondsSinceEpoch,
    }),
  );
}

/// Read-and-clear. Null if absent, malformed, or older than the TTL.
Future<PendingCheckIn?> consumePendingCheckIn() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return null;
  await prefs.remove(_key);

  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final shopId = decoded['shopId'];
    final at = decoded['at'];
    if (shopId is! String || at is! int) return null;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    if (age >= _ttl.inMilliseconds) return null;
    final token = decoded['token'];
    return (shopId: shopId, token: token is String ? token : null);
  } on FormatException {
    return null;
  }
}

Future<void> clearPendingCheckIn() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key);
}
