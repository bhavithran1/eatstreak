/// Incoming-link handling for check-in QR codes.
///
/// A printed code encodes `https://<host>/c/<shopId>`; older printed codes use
/// `eatstreak://check-in/<shopId>`. Both must land on the same screen, and both
/// forms are already understood by [parseCheckInTarget] — the same decoder the
/// in-app scanner uses — so there is exactly one definition of "an EatStreak
/// check-in link" in the codebase.
///
/// Links are consumed here rather than by go_router's own deep-link support
/// because a custom scheme parses as host=`check-in`, path=`/<shopId>`, which
/// no route pattern matches. Taking the raw URI sidesteps that entirely.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../utils/qr_codec.dart';
import 'routes.dart';

class DeepLinkService {
  DeepLinkService(this._router);

  final GoRouter _router;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Start listening. Covers both a cold start from a link and links that
  /// arrive while the app is already running.
  Future<void> start() async {
    _sub ??= _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) => debugPrint('Deep link error: $e'),
    );
  }

  void _handle(Uri uri) {
    final shopId = parseCheckInTarget(uri.toString());
    // Anything that isn't a check-in link is not ours to route.
    if (shopId == null) return;
    _router.go(Routes.checkInFor(shopId));
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
