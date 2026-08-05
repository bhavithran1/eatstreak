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

5. `cd mobile && flutter build ios --release --dart-define-from-file=env.json --dart-define=APP_CHECK=false`
6. `xcrun devicectl device install app --device 00008140-00167C9E2422201C build/ios/iphoneos/Runner.app`

`APP_CHECK=false` is not optional on this phone, and must not ship. App Attest needs a
real Apple team; free provisioning has none, so an activated App Check leaves every
Firebase call waiting for a token that never comes — Firestore reads fail `unavailable`
and the app shows "Network problem". Build **without** the flag for anything properly
signed (TestFlight, App Store), where attestation actually works. The default is on so
that forgetting it fails safe rather than silently shipping an unattested client.

The build (step 5) is the part that proves the change compiles for a real device, and it
works whether or not the phone is there. **Treat the install as a separate, optional
step** — it is the one part of this loop that depends on hardware you don't control.

**As of 2026-08-02 step 5 as written fails on this Mac**, before it compiles anything:

```
Error (Xcode): No Accounts: Add a new account in Accounts settings.
Error (Xcode): No profiles for 'com.eatstreak.app' were found
```

There is no Apple account in Xcode, so nothing can be signed and step 6 has no app to
install. This is a broken toolchain, **not a regression in the change under test** — do
not go hunting through the diff for it, and do not try to add an account yourself, which
needs the user's Apple ID. Run step 5 with `--no-codesign` added to prove the change
still compiles for a device, and say plainly that signing was skipped.

`unavailable` in `xcrun devicectl list devices`, or error 1011, means **unreachable** — it
says nothing about why. Do not guess, and do not tell the user to wake the phone before
you have looked. Read the device record:

```bash
xcrun devicectl list devices --json-output /tmp/dev.json && python3 -c "
import json
for x in json.load(open('/tmp/dev.json'))['result']['devices']:
    c, d = x.get('connectionProperties', {}), x.get('deviceProperties', {})
    print(c.get('transportType'), c.get('tunnelState'), c.get('pairingState'),
          d.get('developerModeStatus'))"
```

- `transportType: None` → no cable and no network tunnel. The phone is not connected to
  this Mac at all. Unlocking it changes nothing; it needs a USB-C cable. This is the
  usual cause.
- `pairingState` not `paired` → trust was revoked (an iOS update does this). Re-trust in
  Xcode → Window → Devices and Simulators.
- `developerModeStatus` not `enabled` → Settings → Privacy & Security → Developer Mode.

Report which of these it actually was. Then **stop retrying and hand it over**:

```bash
cd mobile && xcrun devicectl device install app --device 00008140-00167C9E2422201C build/ios/iphoneos/Runner.app
```

Say plainly that the build succeeded and the install did not, so the user knows the
artifact is ready and what is left. Never describe a change as "on the phone" when only
the build completed. Mention that free provisioning gives the build about 7 days from
install, not from build.

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
