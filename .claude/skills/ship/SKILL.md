---
name: ship
description: Full verification loop for EatStreak — flutter analyze, Dart tests, functions build and tests, then optionally build and install to the iPhone. Pass "device" to include the install.
disable-model-invocation: true
---

Run the verification loop. **Stop at the first failure**, report the actual output, and
fix the cause before continuing. Never skip a step because the change "looked" unrelated —
a Dart change can break the functions parity tests and vice versa.

1. `cd mobile && flutter analyze`
2. `cd mobile && flutter test`
3. `cd functions && npm run build`
4. `cd functions && npm test`

Report what each returned, with counts. Do not say the work is verified unless all four
passed.

> Test files must end with their summary print and exit. Assertions appended *after* the
> summary block still run but can no longer fail the suite — that already happened once
> and hid 18 assertions. If you add tests, check they are above the summary.

If all four pass **and** `$ARGUMENTS` contains `device`, put it on the phone:

5. `cd mobile && flutter build ios --release --dart-define-from-file=env.json`
6. `xcrun devicectl device install app --device 00008140-00167C9E2422201C build/ios/iphoneos/Runner.app`

`unavailable` from step 6 means the phone is asleep or locked — ask the user to wake it
and retry. Mention that free provisioning gives the build about 7 days.

## Then say what isn't live yet

Verification proves the code is correct, not that it is running. Check what the change
touched and tell the user plainly:

- `functions/`, `firestore.rules`, `firestore.indexes.json`, or `public/` → not live
  until they deploy:
  ```bash
  firebase deploy --only functions,firestore:rules,firestore:indexes,hosting
  ```
  If a callable was renamed or removed, warn them the CLI will ask to confirm deleting
  the old one.
- A new secret → they run `firebase functions:secrets:set <NAME>` themselves.
- A new TTL field or App Check change → console step, no deploy performs it.

Name the features that stay broken until they run it, rather than just handing over a
command.
