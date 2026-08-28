---
name: scan-e2e
description: End-to-end QR scan test on the iOS Simulator. Renders real QR images (EatStreak codes plus the menu, payment and wifi codes customers actually point the app at), decodes them back, and replays each through a real build to prove the app survives and branches correctly.
disable-model-invocation: true
---

Run the whole suite, look at every screenshot, and report what each branch did.

```bash
cd /Users/zalkky/Coding/eatstreak/mobile && flutter build ios --simulator --debug --dart-define-from-file=../tool/e2e/env.e2e.json && xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

Boot a simulator first if none is running (`xcrun simctl boot "iPhone 17 Pro"`),
and open the panel with the simulator tool's `attach` so the user can watch.

Take the udid from `xcrun simctl list devices booted`, then:

```bash
cd /Users/zalkky/Coding/eatstreak && python3 tool/e2e/run_scan_suite.py --udid <udid>
```

`--only <fixture>` reruns a single case while iterating on a fix.

**Check-in fixtures only demonstrate a real check-in on a freshly seeded
device.** They share one device and run in order, so once the first EatStreak
code has checked in, every later run finds that shop already visited today and
shows `already_visited_today` instead — correct behaviour, and easy to misread
as the check-in having broken. `--reset` clears the demo world *and reseeds it
already onboarded*, then goes straight on to run the suite.

The reseed does not reimplement the demo world in Python. It reads
`mobile/build/demo_world.json`, written by

```bash
cd mobile && flutter test tool/dump_demo_world_test.dart
```

which calls `DemoRepository.seed()` — the same call onboarding makes — and dumps
what it persisted. Generate that file once; the runner tells you to if it is
missing. Reimplementing the seed on the Python side would be one more pair of
things that must agree and silently would not, which is the failure this repo
has already been bitten by twice.

`--reset --no-seed` is the old behaviour: clear it and onboard by hand. Keep it
in mind, because **the hand path is not always available.** Onboarding needs a
tap on the Flutter view, and synthetic taps do not always reach it — on this Mac
they drive SpringBoard (an app icon launches, a long press opens its menu) and
never arrive in the app, while *swipes* work fine. That is what the reseed is
for: without it a `--reset` can strand the device at the sign-in screen with no
way forward.

**`killall cfprefsd` does not work here.** cfprefsd caches the app's plist, so a
write from outside is invisible until it re-reads, and `xcrun simctl spawn
<udid> killall -9 cfprefsd` is the documented way to force that. On this Mac it
exits 2 (`killall` is not on the spawn PATH) and a full path gets launchd error
111. `force_prefs_reread()` tries it and falls back to cycling the device, which
always works — a stopped simulator has no daemon holding a cache. The per-fixture
`inject()` does not need any of this: the app is terminated and relaunched
between fixtures and that is enough, and rebooting 19 times would turn a
two-minute suite into an hour.

## What it proves, and what it does not

The QR images are real. Each is encoded with OpenCV and then read back with
OpenCV's *detector* — a different code path from the encoder — and the string
that gets replayed is the decoded one. A fixture that stops decoding fails the
run.

Everything downstream of the camera runs for real: `parseCheckInTarget`, the
external-QR classifier, the check-in call, the routing, the screens. The payload
joins at `ScannerScreen._route`, the exact seam the camera hands its string to.

**The camera itself is never exercised.** The simulator has no lens and there is
no supported way to feed it a frame. The round-trip decode is what stands in for
it. Say so when reporting; do not claim the scanner was tested.

Crashes are caught automatically (the app is checked for liveness after each
fixture — that is what caught the FirebaseAuth crash below). **Which branch the
app took is not asserted** — open each screenshot in `out/` and check it against
the fixture's `expect`. Asserting on pixels or scraped text would break on every
copy edit.

## Setup that is not optional

- **Build with `tool/e2e/env.e2e.json`, not `mobile/env.json`.** The suite runs
  on seeded on-device data: it writes no visit, mints no voucher and touches no
  real customer, so it is safe to run constantly. `env.json` points at
  `eatstreak-prod` and would put test check-ins in the live database.
- **`LINK_DOMAIN` must match the host the fixtures are generated for.**
  `parseCheckInTarget` only accepts a check-in link on a known host, and demo
  mode otherwise falls back to `eatstreak.app`. Get this wrong and every
  production-shaped code silently resolves as an external QR — the suite passes
  while testing the wrong branch. Both sides default to
  `eatstreak-prod.web.app`.
- **`FIREBASE_PROJECT_ID` is set in `env.e2e.json`, and does not turn demo mode
  off.** `Env.hasFirebaseConfig` needs an API key as well, and there is none, so
  nothing initialises Firebase. It is there so `_checkInHosts` resolves the full
  production set — the `.web.app` host **and** the `.firebaseapp.com` one
  Firebase Hosting also serves. Without it only one of the two hosts a real
  printed code can carry was ever exercised.
- **Only one EatStreak bundle may be installed.** An older build under a
  different bundle id (`com.eatstreak.eatstreak` has turned up before) claims the
  same `eatstreak://` scheme, and iOS then picks between them arbitrarily — which
  reads as the app behaving at random. The runner refuses to start if it finds
  one; uninstall it and rerun.

## How the payload gets in

Written straight into the app container's own preferences plist, then the app is
terminated and launched. `consumeE2eScanPayload()` reads and clears it, and the
router redirect sends the app to the scanner.

The relaunch is what makes the new value visible; the `killall cfprefsd` step
this used to rely on does not run on this Mac at all (see above) and the suite
has been passing without it. Do not add it back as a *requirement* — check the
value is actually read before believing any change to this path.

Three mechanisms were tried. The two obvious ones do not work on iOS:

- **A deep link** (`eatstreak://scan?data=…`) **does not arrive in demo mode.**
  It used to kill the app outright; `SceneDelegate` now holds URLs back until a
  default FirebaseApp exists and discards them after 5s rather than forwarding
  into the trap. A demo build never configures Firebase, so its URLs always hit
  that timeout. Survivable, but not a delivery mechanism — see below.
- **A `SIMCTL_CHILD_…` environment variable** never arrives: Dart's
  `Platform.environment` comes back empty in an iOS Flutter build. Measured, not
  assumed — a probe reported `envcount=0`.
- **`xcrun simctl spawn … defaults write`** looks like it works and does not. It
  writes to the simulator's global preference domain, never the app sandbox.
  Read it back from `$(xcrun simctl get_app_container … data)/Library/Preferences/`
  before believing it.

## The crash this surfaced, and what was done about it

Any URL opened into the app used to terminate it:
`FLTFirebaseAuthPlugin scene:openURLContexts: → Auth.auth() → _assertionFailure`.
The plugin calls `Auth.auth()` on the way in, and that traps when no default
FirebaseApp has been configured. Fatal in every demo build, and a live risk on
the app's primary flow — scan a code, app cold-starts from the link — because
nothing orders UIKit's URL delivery against Dart's `Firebase.initializeApp`.

Fixed in `ios/Runner/SceneDelegate.swift`: URLs are held until a default app
exists, then forwarded; discarded with a log line after 5s if one never appears.
Deferring rather than dropping is the point — a real cold-start check-in link
survives the wait instead of dying with the process.

**Demo builds never configure Firebase, so their URLs always time out.** Deep
links do not function in demo mode. That is why this harness injects through
preferences and not through a link, and it is a genuine gap: the deep-link path
is covered by `parseCheckInTarget` unit tests and by a live-mode build, never by
this suite.

Both halves are worth re-checking after any change to Firebase startup or the
iOS lifecycle:

```bash
xcrun simctl openurl booted "eatstreak://check-in/shop_ramen?t=abc123"
```

Demo build: the app stays alive and logs `[EatStreak] Dropped 1 URL delivery`.
Live build: no such log, and
`$(xcrun simctl get_app_container booted com.eatstreak.app data)/Library/Preferences/com.eatstreak.app.plist`
gains `flutter.eatstreak.pendingCheckIn` with the shop and token — which is the
proof the URL reached Dart rather than merely failing to crash.

## The hosted fallback page

The other place a scanned code lands is `public/c/`, when the app is not
installed. Only the hosting emulator runs on this machine — Firestore and Auth
need a JRE and there is none — so `--only hosting` is not a shortcut, it is the
whole available surface.

Start it with the `hosting` preview config. Two things to check, and they need
different tools.

**The rewrite** — curl is enough, because this is server behaviour:

```bash
curl -s -o /dev/null -w '%{http_code}\n' "http://localhost:5010/c/shop_ramen?t=demo_shop_ramen_TESTTOKEN"
```

200 means `/c/**` resolved to `/c/index.html`. A plain static server does not
apply the rewrite, so testing this without the emulator proves nothing.

**The deep link** — curl is *not* enough, and this instruction used to say it
was. The static HTML ships `href="eatstreak://"` as a placeholder; the real link
is built at runtime from `location.pathname` and `?t=` (`public/c/index.html`,
the inline script near the bottom). Grepping the served HTML therefore always
shows the bare scheme and never the shop — a check that cannot pass, which is
worse than no check, because it reads as the page being broken when it is fine.
Run the page and ask it:

```js
document.getElementById('open-app').getAttribute('href')
```

It must be `eatstreak://check-in/shop_ramen?t=demo_shop_ramen_TESTTOKEN` — the
exact form `parseCheckInTarget` accepts. Verified working.

## Adding a fixture

Add it to `fixtures()` in `tool/e2e/qr_fixtures.py` with an honest `why`, and
add the same payload to `mobile/test/core/qr_codec_test.dart`. The unit test is
what makes a regression fail in `flutter test` instead of only in a screenshot
somebody has to remember to look at.

`ShopNotFoundScreen` serves **two** branches — a code that isn't ours, and a
real EatStreak code for a shop that is gone — so `external_qr` and
`shop_not_found` fixtures produce the same screen. What separates them in a
screenshot is the "We detected …" block and whether the name field is prefilled,
which is exactly what several fixtures exist to check.

Fixtures earn their keep by finding things. `eatstreak_host_suffix_spoof`
(`https://<our-host>.evil.example/c/...`) confirmed the host test is equality
rather than a prefix match — and then showed the external branch offering
**"Eatstreak-prod"** as the name of a restaurant to add, handing a hostile code
our own brand to wear. `_borrowsOurName` in `qr_codec.dart` now suppresses it,
the same answer `_isMachinePayload` gives a wifi password: there is nothing
trustworthy to prefill, and the customer can still type the real name.
