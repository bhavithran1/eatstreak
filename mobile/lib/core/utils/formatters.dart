import 'dart:math';

/// Ambiguity-free alphabet — no O/0, no I/1/L. Matches the Cloud Function's
/// generator so demo codes look like real ones.
const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

final _random = Random();

/// EAT-XXXX
String generateVoucherCode([Random? random]) {
  final rng = random ?? _random;
  final code = List.generate(4, (_) => _codeAlphabet[rng.nextInt(_codeAlphabet.length)]).join();
  return 'EAT-$code';
}

/// Short, sortable-ish unique id for demo-mode documents.
String generateId() {
  final now = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final suffix = _random.nextInt(1 << 30).toRadixString(36);
  return '$now$suffix';
}

String formatPercent(num n) => '$n%';

/// First character, uppercased — used for avatar monograms.
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
