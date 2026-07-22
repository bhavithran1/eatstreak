# EatStreak release checklist

Shop QR codes encode `https://<link-domain>/c/<shopId>`, which the native camera
on both platforms opens directly into the app (installed → check-in screen; not
installed → hosted fallback page with store links).

**The link domain is derived, not hardcoded.** It defaults to
`<FIREBASE_PROJECT_ID>.web.app` (Firebase Hosting's free domain) and can be
overridden with `LINK_DOMAIN` in `env.json`. Two places consume that derivation
and must always agree:

- `lib/core/utils/qr_codec.dart` (`buildCheckInLink`) — what gets baked into generated QR codes
- the OS-level link claims: `ios/Runner/Runner.entitlements` + the App Links
  intent-filter in `android/app/src/main/AndroidManifest.xml`

The custom scheme `eatstreak://check-in/<shopId>` works everywhere with no
server setup (old printed codes, the fallback page's "Open in EatStreak" button,
dev tooling), and the legacy `{"s","v"}` JSON payload still resolves in the
in-app scanner.

---

## Part 0 — Settle the bundle ID first ⚠️

The Flutter project builds as **`com.eatstreak.eatstreak`** (`flutter create`
derived it from the folder name). The hosted association files in
`public/.well-known/` claim **`com.eatstreak.app`**. These disagree, and
universal links fail *silently* when they do.

A bundle ID is permanent once the app is on a store. Decide now:

- **Recommended — rename the app to `com.eatstreak.app`.** It's the cleaner
  name, it matches what's already hosted, and nothing has shipped yet. Change
  `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` (3
  occurrences; the two `RunnerTests` ones keep their `.RunnerTests` suffix) and
  `namespace` + `applicationId` in `android/app/build.gradle.kts`.
- **Or keep `com.eatstreak.eatstreak`** and update `package_name` /`appIDs` in
  both files under `public/.well-known/`.

Whichever you pick, use it consistently in Firebase, Apple Developer, and Play.

## Part 1 — Accounts and one-time setup (manual)

1. **Apple Developer Program** ($99/yr): enroll at developer.apple.com. Note your
   **Team ID** (Membership page).
2. **Google Play Console** ($25 one-time): play.google.com/console.
3. **Firebase project** on the Blaze plan — follow `FIREBASE_SETUP.md`: register
   the apps, enable Google + Apple sign-in, fill `env.json`, put the real
   project ID into the repo-root `.firebaserc`.

## Part 2 — Fill the placeholders (manual)

| Placeholder | Where | Source |
|---|---|---|
| `REPLACE_WITH_APPLE_TEAM_ID` | `public/.well-known/apple-app-site-association` (both `appIDs` and `appID`) | Apple Developer → Membership |
| `REPLACE_WITH_SHA256_FROM_eas_credentials` | `public/.well-known/assetlinks.json` | Your release keystore's SHA-256 (`keytool -list -v -keystore <release.jks>`). Add this to the Firebase Android app too, for Google sign-in. |
| Reversed iOS client ID | `ios/Runner/Info.plist` → `CFBundleURLTypes` | Google Cloud console → Credentials → iOS OAuth client |
| `REPLACE_WITH_APP_STORE_ID` | `public/c/index.html` (smart banner + App Store link) | Numeric App Store ID — only known after the app exists in App Store Connect; redeploy hosting after filling |
| `GOOGLE_WEB_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID` | `env.json` | Google Cloud console → Credentials |

## Part 3 — Claim the universal-link domain

Neither platform claims `https://` links yet — only the custom scheme is wired,
which is why QR codes work today with zero setup. To enable universal links:

**iOS.** Xcode → Runner target → Signing & Capabilities → **+ Capability** →
**Associated Domains** → add `applinks:<project-id>.web.app`. That creates
`ios/Runner/Runner.entitlements`.

**Android.** In `android/app/src/main/AndroidManifest.xml`, alongside the
existing `eatstreak` scheme filter, add:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="<project-id>.web.app" android:pathPrefix="/c"/>
</intent-filter>
```

## Part 4 — Deploy the backend + hosting (order matters)

```sh
# from the repo root
firebase deploy --only hosting,firestore,functions
```

Verify the association files are served correctly (repeat after every hosting deploy):

```sh
curl -sI https://<project-id>.web.app/.well-known/apple-app-site-association
# want: HTTP 200, content-type: application/json, and NO location/redirect header
curl -sI https://<project-id>.web.app/.well-known/assetlinks.json
# what Apple's CDN (the thing iPhones actually query) sees:
curl https://app-site-association.cdn-apple.com/a/v1/<project-id>.web.app
# what Google sees:
# https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://<project-id>.web.app&relation=delegate_permission/common.handle_all_urls
```

Also open `https://<project-id>.web.app/c/test123` in a desktop browser — the
"Scan complete" fallback page should render.

⚠️ **Deploy hosting BEFORE building/installing the app.** iOS fetches the AASA at
app install/update via Apple's CDN and caches it for hours — an app installed
before the AASA is live has dead universal links until reinstall.

## Part 5 — Build and submit

```sh
cd mobile
flutter analyze && flutter test        # must both be clean
flutter build ipa --dart-define-from-file=env.json
flutter build appbundle --dart-define-from-file=env.json
```

Upload the IPA with Xcode's Organizer or `xcrun altool`; upload the AAB in Play
Console. Android release signing needs a keystore and a `key.properties` —
neither exists yet; see
https://docs.flutter.dev/deployment/android#signing-the-app.

**After the first Play upload:** Play Console → Test and release → Setup → App
integrity → copy the **App signing key** SHA-256 and add it as a SECOND entry in
`public/.well-known/assetlinks.json` (keep the upload-key entry), then redeploy
hosting. Play re-signs store builds — without this, App Links verification fails
for store installs. This is the single most common App Links failure.

## Part 6 — Store listings and review

- Privacy Policy + Support URLs (host on the landing site), screenshots, age
  rating, data-safety forms, store descriptions.
- **Review notes for both stores:** explain the camera permission ("scans
  restaurant loyalty QR codes for check-in"), provide a test Google account, and
  attach a demo shop QR image — reviewers can't visit a restaurant.
- After iOS approval: put the numeric App Store ID into `public/c/index.html`
  and redeploy hosting so the smart banner and store links go live.

## Part 7 — Device verification

```sh
# iOS simulator
xcrun simctl openurl booted "https://<project-id>.web.app/c/<shopId>"
xcrun simctl openurl booted "eatstreak://check-in/<shopId>"
# Android
adb shell am start -a android.intent.action.VIEW -d "https://<project-id>.web.app/c/<shopId>"
adb shell pm get-app-links <bundle-id>        # want: verified
adb shell pm verify-app-links --re-verify <bundle-id>
```

Flow matrix to walk on physical devices (native camera, not the in-app scanner):

- Signed-in customer scans → app opens → check-in success (app cold AND warm).
- Signed-out user scans → app opens → sign-in → check-in completes automatically.
- Brand-new user scans → sign-in → onboarding → check-in completes automatically.
- Owner scans → lands on owner dashboard with "switch to customer mode" toast.
- Second scan same day → "already checked in" toast.
- Airplane mode scan → friendly error toast, no crash.
- Phone without the app scans → fallback web page with store links.
- In-app scanner still accepts all three payload forms (https link,
  `eatstreak://`, legacy JSON).

The deferred-link cases are handled by `CheckInLinkHost` in `lib/app.dart` plus
`lib/core/utils/pending_check_in.dart` (30-minute TTL — a check-in resumed hours
later would log a visit that never happened). Worth testing deliberately.

## Part 8 — Final launch checks

- iOS: TestFlight install on the oldest supported iOS version (**15.0** — raised
  from Flutter's default 13.0 because the Firebase SDKs won't link below it) and
  a current device.
- Android: internal-track install on a low-memory device and an Android 15/16 device.
- Production build requests ONLY camera access (no microphone).
- QR remains readable printed at 4 cm square in low indoor light.
- App survives force close, device restart, offline launch.
- Review every reward percentage with participating shops; confirm voucher terms.
- **Print shop QR codes only after Part 7 passes** — the domain inside them is
  permanent ink.

## Later: custom domain (optional)

When you connect e.g. `eatstreak.app` to Firebase Hosting (console → Hosting →
Add custom domain → DNS records → wait for the certificate):

1. Set `"LINK_DOMAIN": "eatstreak.app"` in `env.json`.
2. Add `applinks:eatstreak.app` to the iOS entitlement and a second Android
   intent-filter for the new host — **keep the `.web.app` entries**, so codes
   printed before the switch keep working.
3. Rebuild and resubmit (associated-domain entitlements are baked at build time).

`parseCheckInTarget` already accepts `.web.app`, `.firebaseapp.com` and the
override domain, so the in-app scanner needs no change.
