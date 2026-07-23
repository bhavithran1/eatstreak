import 'dart:math';

/// The alphabet drops I, O, 0 and 1 — the pairs staff actually confuse when
/// reading a code off a stranger's phone. L stays: it is only mistakable for 1,
/// and 1 is already gone. Matches the Cloud Function's generator so demo codes
/// look like real ones.
const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

final _random = Random();

/// Number of random characters after the `EAT-` prefix. Must match
/// `VOUCHER_CODE_LENGTH` in functions/src/streakLogic.ts — this generator makes
/// demo codes, that one makes real ones, and a length mismatch means a demo
/// code no longer looks like what staff are asked to type in.
const voucherCodeLength = 6;

const voucherCodePrefix = 'EAT-';

/// EAT-XXXXXX
String generateVoucherCode([Random? random]) {
  final rng = random ?? _random;
  final code = List.generate(
    voucherCodeLength,
    (_) => _codeAlphabet[rng.nextInt(_codeAlphabet.length)],
  ).join();
  return '$voucherCodePrefix$code';
}

/// Tidy up a hand-typed voucher code before looking it up. Staff read the code
/// off a customer's phone, so it arrives lowercase, spaced, hyphenated by
/// habit, or without the prefix entirely. Matching those against the stored
/// code verbatim reports "no such voucher", which reads as the customer lying
/// rather than as a typo. Ported from `normalizeVoucherCode` in
/// functions/src/streakLogic.ts.
String normalizeVoucherCode(String raw) {
  // Strip separators first, so leading whitespace can't hide the prefix and
  // leave it to be treated as part of the code.
  final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  // Drop the prefix only when what's left is exactly a code body. A body may
  // itself begin with E-A-T, so removing a leading "EAT" unconditionally would
  // eat three real characters from someone who typed the body alone.
  const stripped = 'EAT';
  if (compact == stripped) return ''; // the prefix and nothing else

  final body =
      compact.startsWith(stripped) && compact.length == stripped.length + voucherCodeLength
          ? compact.substring(stripped.length)
          : compact;

  return body.isEmpty ? '' : '$voucherCodePrefix$body';
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
