/// Debug-only entry point for the end-to-end scan harness (tool/e2e/).
///
/// Two more obvious mechanisms were tried first and neither works on iOS:
///
///  - **A deep link** (`eatstreak://scan?data=…`). The bundled FirebaseAuth
///    plugin implements `scene:openURLContexts:` and calls `Auth.auth()`, which
///    hard-asserts when no default FirebaseApp has been configured. A demo-mode
///    build never configures one, so *any* URL opened into the app terminates
///    it before Dart is involved.
///  - **A process environment variable** via `SIMCTL_CHILD_…`. Dart's
///    `Platform.environment` comes back completely empty in an iOS Flutter
///    build — measured, not assumed: the probe reported `envcount=0`.
///
/// What is left is storage the harness can write from outside the app and the
/// app can read on the way up. SharedPreferences is already a dependency and is
/// backed by NSUserDefaults, so the harness writes
/// `flutter.e2e_scan_payload` into `com.eatstreak.app.plist` with `defaults`
/// before launching.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The NSUserDefaults key, without the `flutter.` prefix SharedPreferences adds.
const e2eScanPayloadKey = 'e2e_scan_payload';

/// Take the scanned payload the harness left for this launch, if any.
///
/// Read-and-clear: one replay per launch. Clearing also stops the router
/// redirect that calls this from bouncing back to the scanner forever.
/// Release builds always return null — [kDebugMode] is a compile-time constant,
/// so the whole path is tree-shaken out rather than merely skipped.
Future<String?> consumeE2eScanPayload() async {
  if (!kDebugMode) return null;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(e2eScanPayloadKey);
  if (raw == null) return null;
  await prefs.remove(e2eScanPayloadKey);
  return raw;
}
