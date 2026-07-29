/// Map a backend failure to a sentence fit for a toast. Ported from
/// src/utils/errors.ts; matches Firebase's callable/Firestore error codes.
String friendlyErrorMessage(Object? error) {
  final code = errorCode(error).toLowerCase();

  if (code.contains('unauthenticated')) {
    return 'Please sign in again to continue.';
  }
  if (code.contains('not-found')) {
    return 'That shop could not be found.';
  }
  if (code.contains('permission-denied')) {
    return "You don't have access to do that.";
  }
  if (code.contains('unavailable') ||
      code.contains('deadline') ||
      code.contains('network-request-failed')) {
    return 'Network problem — check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}

/// The raw code behind a failure — `permission-denied`, `unavailable` — as
/// opposed to the sentence [friendlyErrorMessage] turns it into. Shown in small
/// type under that sentence on the failure screens: the sentence is for the
/// user, this is the only place the actual cause is ever visible on a device
/// whose logs we cannot read.
String errorCode(Object? error) {
  if (error == null) return '';
  try {
    // FirebaseException and friends expose `.code`; anything else falls back to
    // its string form, which still catches most useful substrings.
    final dynamic dyn = error;
    final code = dyn.code;
    if (code is String) return code;
  } on NoSuchMethodError {
    // Not a coded exception.
  }
  return error.toString();
}
