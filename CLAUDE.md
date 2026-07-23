# EatStreak

Flutter app (`mobile/`) + Cloud Functions (`functions/`) + landing page (`public/`).
Firebase project `eatstreak-prod`. Firestore and functions are both in `asia-southeast1`.

## Commands

```bash
# Flutter — run from mobile/
flutter analyze
flutter test
flutter run -d <device-id> --dart-define-from-file=env.json

# Cloud Functions — run from functions/
npm run build
npm test
```

## Non-obvious rules

- **Always pass `--dart-define-from-file=env.json`** to any run or build. `DEMO_MODE`
  defaults to true; the gitignored `mobile/env.json` is what selects the live backend.
  A build without it silently runs on-device demo data.
- **Install to the iPhone with `xcrun devicectl`, not `flutter run`** — Flutter's own
  installer fails on this device with a generic Xcode error:
  ```bash
  cd mobile && flutter build ios --release --dart-define-from-file=env.json
  xcrun devicectl device install app --device 00008140-00167C9E2422201C build/ios/iphoneos/Runner.app
  ```
  Free provisioning: the build stops launching after 7 days, and Apple sign-in never
  works on it. Google sign-in does.
- **Never run `firebase deploy`.** The user runs it — tell them the exact command.
- **Firestore's location is permanent.** It is `asia-southeast1`. Never create or
  recreate a database without confirming the region first.
- **Do not modify `public/`.** The user wants the landing site left as-is.
- `functions/src/streakLogic.ts` and `mobile/lib/domain/streak_logic.dart` are ports of
  each other and must stay in agreement. Both have test suites; update them together.
- Streaks, visits and vouchers are written **only** by Cloud Functions — Firestore rules
  deny client writes. Never add a client write path for them.
- Screens talk only to `EatStreakRepository`. Adding a data method means implementing it
  in **both** `DemoRepository` and `FirestoreRepository`.

## Workflow

- Anything touching multiple files: settle the approach before editing (`/plan-feature`).
- Verify with `/ship` before claiming something works. Show the output, don't assert.
