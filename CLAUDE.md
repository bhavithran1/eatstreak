# EatStreak

Flutter app (`mobile/`) + Cloud Functions (`functions/`) + web (`public/`).
Firebase project `eatstreak-prod`. Firestore and functions are both in `asia-southeast1`.

## Commands

```bash
# Flutter — run from mobile/
flutter analyze
flutter test
flutter run -d <device-id> --dart-define-from-file=env.json

# Cloud Functions — run from functions/
npm run build
npm test          # streakLogic + checkInToken + billing + dates suites
```

## Non-obvious rules

- **Always pass `--dart-define-from-file=env.json`** to any run or build. `DEMO_MODE`
  defaults to true; the gitignored `mobile/env.json` is what selects the live backend.
  A build without it silently runs on-device demo data.
- **Install to the iPhone with `xcrun devicectl`, not `flutter run`** — Flutter's own
  installer fails on this device with a generic Xcode error:
  ```bash
  cd mobile && flutter build ios --release --dart-define-from-file=env.json --dart-define=APP_CHECK=false
  xcrun devicectl device install app --device 00008140-00167C9E2422201C build/ios/iphoneos/Runner.app
  ```
  **`APP_CHECK=false` is required on this phone and must never ship.** App Attest needs
  a real Apple team and free provisioning has none, so activating App Check there starves
  every Firebase call of a token: Firestore reads hang and then fail `unavailable`, which
  the app reports as "Network problem". It also used to block the first frame outright.
  Costs nothing today because enforcement is off — but a TestFlight or App Store build is
  properly signed, can attest, and must be built **without** this flag. The default is on
  precisely so that forgetting it fails safe.
  Free provisioning: the build stops launching after 7 days from *install*, and Apple
  sign-in never works on it. Google sign-in does. `devicectl` reporting the device
  `unavailable` means unreachable, not asleep — check `transportType` in
  `devicectl list devices --json-output` before advising anything (`/ship` has the
  command). It is almost always `None`, meaning no cable is plugged in.
  **As of 2026-08-02 there is no signing account in Xcode at all**, so the build above
  stops before compiling with `No Accounts: Add a new account in Accounts settings` and
  there is nothing to install. That is environmental — read it as a broken toolchain,
  never as a regression in the change you are testing. To prove a change still compiles
  for a device, add `--no-codesign`; the simulator path (`--simulator --debug`, which is
  what `/scan-e2e` uses) is unaffected.
- **Never run `firebase deploy`.** The user runs it — tell them the exact command. Same
  for `firebase functions:secrets:set` and anything else that wants a credential.
- **Firestore's location is permanent.** It is `asia-southeast1`. Never create or
  recreate a database without confirming the region first.
- **`public/index.html`, `script.js`, `styles.css` are the landing site — leave them
  alone.** `public/c/` (check-in fallback) and `public/billing/` (subscription page) are
  app surfaces and may be edited, but say so when you do.
- **Never run `dart format` across the repo.** The project is not written in Dart tall
  style; a repo-wide format produces hundreds of lines of churn that bury the real diff.
- Exclude the investor deck from commits: `git add -A . ':!EatStreak-Investor-Deck.pptx'`.

## How the app actually works

Read this before changing any of it — each line is a decision that was expensive to
reach, and re-deriving it from the code tends to reproduce a bug we already fixed.

- **Check-in codes are per-shop, per-day.** `createCheckInToken` is idempotent: the same
  code all day, turning over at the shop's own midnight. `rotate: true` burns today's
  code if it leaks (30s cooldown). They are *not* single-use and *not* minted per scan —
  both were built and thrown away. Codes live in `checkInTokens/{shopId}_{date}`, deny-all
  to clients, expired by a TTL policy on `ttlAt`.
- **Everything authoritative is server-side.** Streaks, visits, vouchers and embers are
  written **only** by Cloud Functions; Firestore rules deny client writes. Never add a
  client write path for them.
- **Redemption belongs to the owner.** `redeemVoucherByCode` is called by the shop, not
  the customer — the customer's voucher view is deliberately read-only so a discount can
  neither be faked nor accidentally burned. The customer *presents*: "Show" opens the
  voucher full-screen with a QR, and the owner scans it on `/verify-voucher`, which leads
  with the camera and keeps the text field beneath it. Scanning changes who types, not
  who decides — the server still verifies owner, spend and expiry.
  The voucher QR is `EATSTREAK:V1:VOUCHER:<code>` (`qr_codec.dart`), deliberately **not**
  a link: an `https://` payload makes the stock camera offer to open a page, and an
  `eatstreak://` one deep-links the customer's own phone into the app they are already
  holding. It is also listed in `_isMachinePayload`, or a customer scanning their own
  voucher gets it offered as the name of a restaurant to add — the wifi bug again.
- **The counter code may leave the phone, because it is per-day.** "Show on the counter"
  (`counter_code_screen.dart`) is one white sheet doing two jobs: propped by the till it
  is a display that holds the screen awake, and shared it is the same sheet as a PNG,
  which iOS will print. That is only sound because the code is stable until midnight — a
  printed sheet is worth exactly what holding the phone up is worth, and expires at the
  same moment. **Anything per-scan or per-minute could never leave the screen**, so
  changing the token's lifetime silently breaks printing. The sheet is dated for the one
  failure it can have: a sheet still taped up the next morning.
- **Both code screens refetch when the day changes** (`day_rollover.dart`). A phone left
  on the counter overnight came back showing yesterday's code and scanned as
  `code_invalid` for every customer until someone reopened the screen. Two triggers, and
  both are needed: **resume** for the phone picked up in the morning, and a **poll** for
  the phone that was never backgrounded — these screens hold a wakelock precisely so they
  stay up all night, so the app can be foregrounded straight through midnight and see no
  lifecycle event at all. Polling beats one timer set for midnight: a long timer does not
  survive sleep and gets the wrong answer across a clock or timezone change. The counter
  sheet needs its own watcher — the screen behind it refetching does not rebuild it — and
  when the refetch fails it says the sheet is stale rather than leaving a dead QR up,
  because a dead QR looks completely fine.
- **Home-screen shortcuts follow the role, not the session.** `counter_shortcuts.dart`:
  customers get "Scan", owners get "Show code" and "Redeem voucher", signed-out gets
  nothing — those routes all bounce off the auth gate, so a shortcut there is a button
  that looks broken. Best-effort by design and never awaited on the way to a first frame.
- **A broken streak is repaired with embers, not money.** Cost scales with the streak
  that broke (`repairCost`), inside `REPAIR_GRACE_DAYS`, minimum `MIN_REPAIRABLE_STREAK`.
  The server decides eligibility and price; the client only offers the button.
- **Incoming URLs wait for Firebase.** `ios/Runner/SceneDelegate.swift` holds URL
  deliveries until a default `FirebaseApp` exists. `FLTFirebaseAuthPlugin` handles
  `scene:openURLContexts:` and calls `Auth.auth()`, which *traps* rather than fails
  when nothing is configured — so forwarding early killed the process, on the app's
  primary flow (scan a code, cold-start from the link). Two consequences: don't
  "simplify" that delegate back to an empty subclass, and **deep links do not work in
  demo mode**, because a demo build never configures Firebase and those URLs always
  hit the 5s timeout. That is a known gap, not a routing bug.
- **Analytics goes through `Analytics`, never `FirebaseAnalytics.instance`.** The
  interface in `core/analytics/analytics.dart` imports no `firebase_*` package on purpose,
  because `state/providers.dart` depends on it and a demo build must not link the SDK —
  the Firebase implementation sits in its own file, imported only by the bootstrap. Add
  a named method per event rather than a generic `log()`.
- **Pricing must not appear in the app.** `subscription.dart` has
  `const showsPricingInApp = false` — Apple 3.1.1 requires IAP for digital subscriptions
  sold in-app. Owners subscribe on `public/billing/`. Do not "helpfully" add prices,
  a paywall, or a checkout button to any Flutter screen.

## Rules that break things when ignored

- **A fixed pixel size on a counter screen is a bug waiting for a narrow phone.**
  `test/features/layout_stress_test.dart` renders the counter sheet, the held-up voucher,
  the voucher card and the store failure screen across four widths and three text scales,
  and fails on overflow. It found the voucher card overflowing at *default* text size on
  every device, and a failure screen whose Retry button fell off the bottom at
  accessibility sizes. Sizes there are derived from `MediaQuery` and clamped; where a
  fixed size is genuinely wanted, `FittedBox(scaleDown)` keeps it whole. Run it after
  touching any of those layouts — one simulator cannot see this.
- **Ported logic must stay in agreement, and the agreement must be tested.** The pairs:
  - `functions/src/streakLogic.ts` ↔ `mobile/lib/domain/streak_logic.dart` (check-in,
    embers, repair) — tested by `streakLogic.test.ts` and `test/domain/streak_logic_test.dart`
  - `functions/src/streakLogic.ts` ↔ `mobile/lib/core/utils/formatters.dart` (voucher
    codes) — tested by the "voucher codes" block and `test/core/formatters_test.dart`
  - `functions/src/dates.ts` ↔ `mobile/lib/core/utils/dates.dart` (`daysBetween`,
    `addDays`) — tested by `dates.test.ts` and `test/core/dates_test.dart`

  A shared value belongs in a named constant on both sides, with a test asserting the
  number literally. The voucher code generators drifted to 4 and 6 characters and nobody
  noticed for months, because "keep these in sync" was a comment rather than an assertion.
  The date pair drifted the same way on unreadable input, and worse: TypeScript returned
  a silent `NaN` — which compares false against every threshold, so it quietly *preserved*
  a streak — while Dart threw a `FormatException` out of `build()` and red-screened the
  owner dashboard. Both now answer `UNKNOWN_DATE_DISTANCE_DAYS` / `unknownDateDistanceDays`
  (99999), asserted literally on both sides. It is deliberately large: an unreadable
  last-visit date has to read as "long ago" and lapse a streak, never as "today".

  **Only two bare `yyyy-MM-dd` days are promised to agree exactly.** An ISO instant is
  accepted so neither side throws, but the two parse a bare day in different zones —
  Dart in device-local time, TypeScript in UTC — so instant-vs-day answers can differ by
  a day. Don't build on that; both test suites assert only the range.
- **`daysFromNow`'s sign is a contract: `> 0` means "not expired yet".** It is what
  splits the Vouchers screen into Active and Expired, what the home and dashboard counts
  filter on, and what `voucher_card` turns into "Expires today" (1) and "Expires
  tomorrow" (2). Round fractional days up — do not reassemble it from `inHours ~/ 24`
  plus `inHours % 24`. Dart's `%` is **non-negative for a positive divisor** (`-5 % 24`
  is 19, not -5), so that version added a day to everything that had just expired and
  answered 1: a voucher that lapsed overnight sat in Active reading "Expires today", the
  customer held it up, and the counter rejected it, because `redeemVoucherByCode` checks
  the real timestamp. The same slip pushed a voucher with an hour left into Expired,
  where it could not be shown at all. Vouchers expire at 23:59:59Z — 07:59 local — so
  the wrong answer landed every morning.
- Screens talk only to `EatStreakRepository`. Adding a data method means implementing it
  in **both** `DemoRepository` and `FirestoreRepository`.
- **Nothing best-effort may be awaited before `runApp`.** `main()` awaits
  `initializeFirebase()`, so every await inside it runs before the first frame — and
  anything that stalls there produces a launch screen that never goes away, with no
  error and not even our own spinner. App Check activation did exactly that: a release
  build uses the App Attest provider, App Attest needs a real Apple team, and a
  free-provisioning build has none, so `activate()` sat there rather than throwing. Its
  `catch` only ever covered failing, not hanging. It is now unawaited *and* capped, as
  are `Firebase.initializeApp` and the Google Sign-In SDK init, and `main` renders an
  error screen instead of returning without calling `runApp`.
- **Every path out of `_onUidChanged` must clear `initializing`.** The state update
  used to sit after an unguarded `await _repo.getUser(uid)`, so any throw or stall —
  App Check enforcement, a denied rule, a dead network — left the flag true and the
  router pinned the app to the splash spinner forever, with no error and no retry.
  A failed read is now its own state (`profileError`), deliberately *not* folded into
  "no profile": that reads as "not onboarded" and walks an existing account back
  through onboarding. Tested in `test/state/auth_controller_test.dart`.
- **Screens read the store through `StoreScope`**, never `store.value ?? StoreState()` —
  that pattern renders "loading" and "failed" as "you have no shop", which is how owners
  ended up being told to register a shop they already had.
- Comments describing a *mechanism* must be updated with the mechanism. A stale comment
  claiming codes expired in 90 seconds is what justified dropping the token through
  sign-in, breaking every first-ever check-in.
- **Convert a stored streak with `toStreakCore`, never by listing its fields.** Both
  `checkIn` in `functions/src/index.ts` and `DemoRepository.checkIn` used to rebuild
  `StreakCore` field by field, and both lists omitted `brokenStreakDays` / `brokenOn` /
  `brokenStartDate`. `computeCheckIn` carries a break record forward, so the omission fed
  it a zero and wrote the zero back: a customer who broke a streak, returned, and checked
  in once more while still inside the grace period lost the repair they were being offered
  — by doing nothing but visiting the shop. Any new field on a streak is dropped the same
  way by any field list that outlives it.

## Deploying (the user runs this, not you)

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,hosting
```

Console steps that no deploy performs, and that silently no-op until done:

- **TTL policy** on collection group `checkInTokens`, field `ttlAt`.
- **App Check enforcement stays OFF** until tokens are visibly arriving in the console.
  Turning it on early locks out every already-installed build, including the user's.
- **`CURLEC_WEBHOOK_SECRET`** is unset and there is no Curlec account yet, so billing is
  inert by design. The billing page's button disables itself while the checkout link is
  still a placeholder.

## Workflow

- Anything touching multiple files: settle the approach before editing (`/plan-feature`).
- Verify with `/ship` before claiming something works. Show the output, don't assert.
- Anything touching scanning, routing, deep links or `public/c/`: run `/scan-e2e`. It
  renders real QR codes — EatStreak codes plus the menu, Maps, payment and wifi codes
  customers actually point the app at — decodes them back, and replays each through a
  real build on the simulator. Build it with `tool/e2e/env.e2e.json`, never `env.json`:
  the suite runs on demo data so it never writes a test check-in to `eatstreak-prod`.
- **Only the hosting emulator runs on this machine.** Firestore and Auth emulators are
  Java processes and there is no JRE installed, which is why the backend is covered by
  pure unit tests over `streakLogic.ts` rather than against an emulator.
