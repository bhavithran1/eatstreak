import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../seed/mock_data.dart';
import 'auth_service.dart';

/// A local identity for demo mode. Every sign-in button lands on the same
/// [demoUid]; there is no network, no OAuth, and no native sign-in SDK — which
/// is exactly what lets demo mode run anywhere, including a bare simulator.
class DemoAuthService implements AuthService {
  DemoAuthService() {
    _restore();
  }

  static const _sessionKey = 'eatstreak.demo.session';

  final _controller = StreamController<String?>.broadcast();
  String? _uid;
  bool _restored = false;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getBool(_sessionKey) == true ? demoUid : null;
    _restored = true;
    _controller.add(_uid);
  }

  @override
  Stream<String?> uidChanges() async* {
    // Replay current state to every new listener, so a late subscriber (the
    // router rebuilding) doesn't hang waiting for the next change.
    if (_restored) yield _uid;
    yield* _controller.stream;
  }

  @override
  String? get currentUid => _uid;

  @override
  String? get providerDisplayName => null;

  @override
  String? get providerEmail => null;

  @override
  Future<void> signInWithGoogle() => _signIn();

  @override
  Future<void> signInWithApple() => _signIn();

  Future<void> _signIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, true);
    _uid = demoUid;
    _controller.add(_uid);
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    _uid = null;
    _controller.add(null);
  }

  @override
  Future<bool> isAppleSignInAvailable() async => false;

  @override
  void dispose() => _controller.close();
}
