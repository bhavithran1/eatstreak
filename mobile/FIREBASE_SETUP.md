# EatStreak — Firebase backend setup

The app runs on Firebase (Auth + Firestore + Cloud Functions). The code is wired;
these are the console steps only you can do — they need your Google/Apple
accounts and billing. Do them once.

Until you do, the app runs fine in **demo mode** (the default), entirely
on-device against seeded sample data. See `README.md`.

Repo layout:

- `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `.firebaserc` — repo root
- `functions/` — Cloud Functions (`checkIn`, `redeemVoucher`)
- `mobile/lib/bootstrap/firebase_bootstrap.dart` — client init (reads `env.json`)
- `mobile/lib/data/repositories/firestore_repository.dart` — Firestore data layer
- `mobile/lib/data/auth/firebase_auth_service.dart` — Google/Apple sign-in

> **Bundle ID: `com.eatstreak.app`** on both platforms, matching the hosted
> association files in `public/.well-known/`. Use this exact string everywhere
> below — Firebase app registration, the iOS OAuth client, and Play. It is
> permanent once the app ships.

---

## 1. Create the Firebase project (Blaze plan)

1. https://console.firebase.google.com → **Add project** (e.g. `eatstreak-prod`).
2. **Upgrade to Blaze** (pay-as-you-go). Cloud Functions require it; you stay
   within the free monthly quota at pilot scale. Set a **budget alert** (~RM 50).
3. Put the project ID in `.firebaserc` (replace
   `eatstreak-REPLACE_WITH_YOUR_PROJECT_ID`).

⚠️ Choose the project ID carefully — it becomes your QR-code domain
(`<project-id>.web.app`), and every printed QR carries it.

## 2. Register the apps + get config

1. Project settings → **General** → *Your apps*. Add a **Web app** (`</>`), an
   **iOS app**, and an **Android app** using your chosen bundle ID.
2. `cp env.example.json env.json` and fill in the values:

   | Console value | Key in `env.json` |
   |---|---|
   | apiKey | `FIREBASE_API_KEY` |
   | authDomain | `FIREBASE_AUTH_DOMAIN` |
   | projectId | `FIREBASE_PROJECT_ID` |
   | storageBucket | `FIREBASE_STORAGE_BUCKET` |
   | messagingSenderId | `FIREBASE_MESSAGING_SENDER_ID` |
   | appId (web / iOS / Android) | `FIREBASE_APP_ID` / `FIREBASE_IOS_APP_ID` / `FIREBASE_ANDROID_APP_ID` |

3. Set `"DEMO_MODE": false` in the same file.

`env.json` is gitignored. These are client config values, not secrets — security
comes from Firestore rules and Cloud Functions, not from hiding them.

## 3. Enable Google sign-in

1. **Authentication → Sign-in method → Google → Enable.** Save.
2. Note **Web SDK configuration → Web client ID** → `GOOGLE_WEB_CLIENT_ID` in
   `env.json`.
3. In **Google Cloud console → APIs & Services → Credentials** (same project),
   create an **OAuth client ID → iOS** with your bundle ID.
   - Its client ID → `GOOGLE_IOS_CLIENT_ID` in `env.json`.
   - Its **reversed** client ID (`com.googleusercontent.apps.XXXX`) must be
     added as a URL scheme in `ios/Runner/Info.plist`. There is already a
     `CFBundleURLTypes` array there for the `eatstreak` scheme — add a second
     `<dict>` entry alongside it:

     ```xml
     <dict>
       <key>CFBundleURLName</key>
       <string>google-signin</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.XXXX</string>
       </array>
     </dict>
     ```

4. For Android, add your app's SHA-1 and SHA-256 signing fingerprints under the
   Android app in Firebase, or Google sign-in fails on Android builds:

   ```sh
   # debug keystore
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore \
     -storepass android -keypass android
   ```

   Add the release keystore's fingerprints too once you have one, plus Play's
   app-signing key after the first upload (see `RELEASE_CHECKLIST.md`).

## 4. Enable Apple sign-in (iOS)

1. **Authentication → Sign-in method → Apple → Enable.**
2. In your **Apple Developer** account, enable **Sign in with Apple** for the
   App ID, and create the Service ID + key Firebase asks for.
3. In Xcode (`open ios/Runner.xcworkspace`) → Runner target → **Signing &
   Capabilities** → **+ Capability** → **Sign in with Apple**.

## 5. Deploy rules, indexes, functions

```sh
npm i -g firebase-tools           # if not installed
firebase login
cd functions && npm install && npm run build && cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Functions deploy to region **asia-southeast1** (Singapore) — this must match
`Env.functionsRegion` in `lib/core/config/env.dart`. Change one, change both.

## 6. Seed demo shops (optional)

Sign in once as your owner account, note its UID (Authentication → Users), then:

```sh
cd functions
OWNER_UID=<your-owner-uid> node lib/seed.js   # uses GOOGLE_APPLICATION_CREDENTIALS
```

## 7. Run against the real backend

```sh
flutter run --dart-define-from-file=env.json
```

---

## Local development without a real project (emulators)

You can exercise everything except real Google/Apple sign-in against the
**Firebase Emulator Suite** (needs Java 11+):

```sh
cd functions && npm run build && cd ..
firebase emulators:start --only auth,firestore,functions
```

Add test users in the Emulator UI (http://localhost:4000). Seed shops with:

```sh
cd functions
FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=<project-id> OWNER_UID=<uid> node lib/seed.js
```

> Emulator wiring is not yet plumbed into the Flutter client. Add the
> `useEmulator` calls in `lib/bootstrap/firebase_bootstrap.dart` (guarded by a
> `--dart-define`) when you need it — the Expo app had this and the port
> deliberately left it out rather than shipping untested config.

## Verify the server logic (no emulator or Java needed)

```sh
cd functions && npm test     # pure streak/voucher unit tests
cd mobile && flutter test    # the Dart port of the same suite
```

Both suites cover the same scenarios: new streak, same-day block, window
increment/reset, tier awarding + idempotency, timezone boundary.
`mobile/lib/domain/streak_logic.dart` is a port of
`functions/src/streakLogic.ts` — **if you change one, change both**, or demo
mode and production will quietly disagree about what a streak is.

---

## Security model (why it's cheat-proof)

- **Streaks, visits and vouchers are never written by the client.** Security
  rules deny all client writes; only the Cloud Functions (Admin SDK) mutate
  them. This is why `EatStreakRepository` exposes those collections as
  read-only and routes mutations through `checkIn` / `redeemVoucher`.
- `checkIn` runs the whole update in a **transaction** (no double-count races)
  and enforces one check-in per day in the shop's timezone.
- Voucher docs use a deterministic id `{uid}_{tierId}` → each tier mints once.
- Owners read only their own shops' data via the denormalized `shopOwnerId`.
