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
npm test          # streakLogic + checkInToken + billing suites
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
  works on it. Google sign-in does. If `devicectl` reports the device `unavailable`, the
  phone is asleep or locked — ask the user to wake it, then retry the same command.
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
  neither be faked nor accidentally burned.
- **A broken streak is repaired with embers, not money.** Cost scales with the streak
  that broke (`repairCost`), inside `REPAIR_GRACE_DAYS`, minimum `MIN_REPAIRABLE_STREAK`.
  The server decides eligibility and price; the client only offers the button.
- **Pricing must not appear in the app.** `subscription.dart` has
  `const showsPricingInApp = false` — Apple 3.1.1 requires IAP for digital subscriptions
  sold in-app. Owners subscribe on `public/billing/`. Do not "helpfully" add prices,
  a paywall, or a checkout button to any Flutter screen.

## Rules that break things when ignored

- `functions/src/streakLogic.ts` and `mobile/lib/domain/streak_logic.dart` are ports of
  each other and must stay in agreement — including embers and repair. Both have test
  suites; update them together.
- Screens talk only to `EatStreakRepository`. Adding a data method means implementing it
  in **both** `DemoRepository` and `FirestoreRepository`.
- **Screens read the store through `StoreScope`**, never `store.value ?? StoreState()` —
  that pattern renders "loading" and "failed" as "you have no shop", which is how owners
  ended up being told to register a shop they already had.
- Comments describing a *mechanism* must be updated with the mechanism. A stale comment
  claiming codes expired in 90 seconds is what justified dropping the token through
  sign-in, breaking every first-ever check-in.

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
