/// A check-in deep link opened while signed out (or not yet onboarded) is parked
/// here, survives the sign-in round trip and onboarding — including process
/// death — and is consumed by the routing hub once the user can actually act.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _key = 'eatstreak.pendingCheckIn';

/// The user is standing in the restaurant when they scan; a check-in resumed
/// hours later would log a visit they never made.
const _ttl = Duration(minutes: 30);

Future<void> setPendingCheckIn(String shopId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _key,
    jsonEncode({'shopId': shopId, 'at': DateTime.now().millisecondsSinceEpoch}),
  );
}

/// Read-and-clear. Null if absent, malformed, or older than the TTL.
Future<String?> consumePendingCheckIn() async {
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
    return age < _ttl.inMilliseconds ? shopId : null;
  } on FormatException {
    return null;
  }
}

Future<void> clearPendingCheckIn() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key);
}
