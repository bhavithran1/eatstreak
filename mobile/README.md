# EatStreak — Flutter app

Restaurant loyalty streaks, check-in QR codes, and redeemable reward vouchers.
Two roles share one account: customers keep streaks, owners run a shop.

This replaced an earlier Expo/React Native implementation, which was deleted
once this port reached parity. Comments saying a file was "ported from" its
Expo counterpart are provenance notes — the originals live in git history.

## Running it

Demo mode is the default, so this needs no configuration:

```sh
flutter run
```

That runs entirely on-device against seeded sample data (`lib/data/seed/`).
Sign-in is a local identity, there is no network, and nothing leaves the device.
It's how you preview the app without a Firebase project.

Against the real backend:

```sh
cp env.example.json env.json    # fill in your Firebase values
flutter run --dart-define-from-file=env.json
```

`DEMO_MODE: false` in that file is what switches `lib/main.dart` from the
on-device providers to Firebase.

```sh
flutter test       # unit tests
flutter analyze    # lints
```

### On an iPhone

Needs Xcode plus an iOS Simulator runtime (Xcode ships without one):

```sh
sudo xcodebuild -license accept && sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
```

Then `flutter devices` to find the target, and `flutter run -d <device>`.
A physical iPhone works with a free Apple ID: open `ios/Runner.xcworkspace`,
pick your Personal Team under Signing & Capabilities, and run.

### There is no camera in the Simulator

The scanner therefore can't scan anything there. In debug builds it offers a
**Simulate a scan** picker that runs a real check-in against a chosen shop, so
the whole scan → streak → voucher flow stays exercisable. It is compiled out of
release builds (`kDebugMode`).

## Layout

```
lib/
├── main.dart                 entry point; picks the backend
├── app.dart                  MaterialApp.router + check-in link handling
├── bootstrap/                Firebase startup, skipped in demo mode
├── core/
│   ├── config/               build-time env (--dart-define)
│   ├── router/               go_router config, the auth gate, deep links
│   ├── theme/                colors, spacing, typography, ThemeData
│   └── utils/                dates, formatters, QR codec, errors
├── data/
│   ├── models/               plain Dart models with JSON codecs
│   ├── auth/                 AuthService: demo + Firebase
│   ├── repositories/         EatStreakRepository: demo + Firestore
│   └── seed/                 the demo-mode sample world
├── domain/                   streak math, check-in routing, reward presets
├── state/                    Riverpod controllers
└── features/
    ├── auth/                 sign-in, onboarding
    ├── customer/             home, scanner, vouchers, shop detail, profile
    ├── owner/                dashboard, QR code, rewards, customers, setup
    └── shared/widgets/       the design system every screen is built from
```

Three seams are worth knowing:

- `data/repositories/eatstreak_repository.dart` is the only data surface
  screens touch, and it has two implementations.
- Everything Firebase-specific is reachable from exactly two places
  (`main.dart` and `bootstrap/`). That's what lets a demo build run with the
  SDK never initialized.
- `features/shared/widgets/` holds the whole visual vocabulary — `AppScreen`,
  `SurfaceCard`, `GradientButton`, the cards. Screens compose these rather than
  restyling containers, which is what keeps gutters and radii identical.

## Where check-in logic lives

Streaks, visits and vouchers are **server-authoritative**. The real backend
computes them inside the `checkIn` Cloud Function (`../functions/src/`), and
Firestore rules deny direct client writes — otherwise a customer could mint
their own discounts.

`lib/domain/streak_logic.dart` is a port of `../functions/src/streakLogic.ts`,
used only by the demo repository. The two must stay in agreement;
`test/domain/streak_logic_test.dart` is the port of the TypeScript test suite
that proves they do. If you change one, change both.

`lib/domain/check_in_flow.dart` decides where a check-in lands. Both the in-app
scanner and the deep-link route call it, so a scan and a tapped link can never
disagree about the outcome.

## Check-in links

A shop's QR code encodes `https://<link-domain>/c/<shopId>`; codes printed
before that switch used `eatstreak://check-in/<shopId>`. `parseCheckInTarget`
in `core/utils/qr_codec.dart` reads every form and is the single definition of
"an EatStreak check-in link" — the scanner, the deep-link listener, and the
owner's QR generator all go through it.

`core/router/deep_links.dart` receives incoming links. It takes raw URIs from
`app_links` rather than using go_router's own deep-link support, because a
custom scheme parses as host=`check-in`, path=`/<shopId>`, which matches no
route pattern.

A link opened while signed out is parked (`core/utils/pending_check_in.dart`,
30-minute TTL) and resumed by `CheckInLinkHost` once onboarding finishes.

**The custom scheme works with no setup** — it's registered in `Info.plist` and
`AndroidManifest.xml`. The `https://` form additionally needs platform
association files, which depend on your Firebase project:

- **iOS** — an Associated Domains entitlement of `applinks:<host>`, plus
  `.well-known/apple-app-site-association` served from that host.
- **Android** — an `https` intent filter for the host with `pathPrefix="/c"`
  and `android:autoVerify="true"`, plus `.well-known/assetlinks.json`.

Set `LINK_DOMAIN` in `env.json` to match, or leave it to default to
`<FIREBASE_PROJECT_ID>.web.app`. Whatever the value, the QR encoder and the two
platform claims must agree — a mismatch means codes that scan but don't open.

Full steps in `RELEASE_CHECKLIST.md`, which also flags a bundle-ID mismatch you
need to settle before any of this is registered with Apple or Google.

## Shared with the rest of the repo

`../functions`, `../firestore.rules` and `../firestore.indexes.json` are the
backend. `../public` is the marketing site and the host for the check-in
fallback page and link-association files. None of them are app-specific.

## Other docs here

- `FIREBASE_SETUP.md` — console steps to stand up the real backend
- `RELEASE_CHECKLIST.md` — everything between "it runs" and "it's on a store"
