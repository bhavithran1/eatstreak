#!/usr/bin/env python3
"""Replay every QR fixture through a real build on the iOS Simulator.

What this actually proves, and what it does not:

  * The QR images are real and genuinely scannable — each is decoded by
    OpenCV's detector, a different code path from the encoder, and the payload
    that gets replayed is the *decoded* string, not the one we encoded.
  * Everything downstream of the camera runs for real: parseCheckInTarget,
    the external-QR classifier, the check-in call, the routing. The payload
    joins at ScannerScreen._route, exactly where the camera hands its string in.
  * The camera itself is not exercised. The simulator has no lens and there is
    no supported way to feed it a frame. That step is covered by the round-trip
    decode above, not by the app.

Crashes are detected automatically — the app is checked for liveness after each
fixture, which is what caught the FirebaseAuth openURL crash. Which *branch* the
app took is left to the screenshots this writes; asserting on pixels or on
scraped text would break on every copy edit, and the branch is obvious at a
glance.

Usage:
    python3 tool/e2e/run_scan_suite.py --udid <udid> [--out <dir>] [--only <name>]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import plistlib
import subprocess
import sys
import time

import cv2

BUNDLE_ID = "com.eatstreak.app"
PREF_KEY = "flutter.e2e_scan_payload"
HERE = pathlib.Path(__file__).resolve().parent


def sh(*args: str, check: bool = True) -> str:
    r = subprocess.run(args, capture_output=True, text=True)
    if check and r.returncode != 0:
        raise RuntimeError(f"{' '.join(args)}\n{r.stderr.strip()}")
    return r.stdout.strip()


def container(udid: str) -> pathlib.Path:
    return pathlib.Path(sh("xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, "data"))


def assert_single_bundle(udid: str) -> None:
    """Two installs claiming `eatstreak://` make link routing a coin flip.

    An older build under a different bundle id stays installed forever and
    silently steals deep links, which reads as the app behaving randomly.
    """
    out = sh("xcrun", "simctl", "listapps", udid, check=False)
    stale = [b for b in ("com.eatstreak.eatstreak",) if b in out]
    if stale:
        raise SystemExit(
            f"Stale EatStreak bundle(s) installed: {', '.join(stale)}.\n"
            f"They claim the same URL scheme as {BUNDLE_ID}. Remove with:\n"
            + "\n".join(f"  xcrun simctl uninstall {udid} {b}" for b in stale)
        )


def assert_signed_in(udid: str) -> None:
    """Refuse to run against a signed-out app.

    The scan payload is consumed by the router redirect that fires *after* the
    account is ready. Signed out, the app stops at the sign-in screen, no
    fixture reaches the scanner, and every one of them still passes the liveness
    check — a full green run that tested nothing. This happened: reinstalling
    the app clears its preferences, and the suite cheerfully reported 10/10.
    """
    plist = container(udid) / "Library/Preferences" / f"{BUNDLE_ID}.plist"
    prefs = plistlib.loads(plist.read_bytes()) if plist.exists() else {}
    if prefs.get("flutter.eatstreak.demo.session") is not True:
        raise SystemExit(
            "The app is signed out, so no fixture would reach the scanner and\n"
            "every one of them would still 'pass'. Open it once and tap\n"
            "'Explore the demo', then finish onboarding as a Customer:\n"
            f"  xcrun simctl launch {udid} {BUNDLE_ID}\n"
            "Reinstalling the app clears this, so do it after any install."
        )
    if '"role":"customer"' not in prefs.get("flutter.eatstreak.demo.v1", ""):
        raise SystemExit(
            "The demo account is not a customer. The scanner lives in the "
            "customer shell; as an owner the redirect lands on the dashboard "
            "instead. Switch role in the app's Profile tab and rerun."
        )


def inject(udid: str, payload: str) -> None:
    """Leave the payload where the app will find it on the way up.

    Written straight into the app container's own preferences plist.
    `simctl spawn … defaults write` looks like it works and does not: it writes
    to the simulator's global domain, never the app sandbox, so the app reads
    nothing. cfprefsd caches the file, so it is killed to force a re-read.
    """
    plist = container(udid) / "Library/Preferences" / f"{BUNDLE_ID}.plist"
    data = plistlib.loads(plist.read_bytes()) if plist.exists() else {}
    data[PREF_KEY] = payload
    plist.write_bytes(plistlib.dumps(data))
    sh("xcrun", "simctl", "spawn", udid, "killall", "-9", "cfprefsd", check=False)
    time.sleep(0.5)


def running(udid: str) -> bool:
    out = sh("xcrun", "simctl", "spawn", udid, "launchctl", "list", check=False)
    return BUNDLE_ID in out


def run_fixture(udid: str, fx: dict, out: pathlib.Path, settle: float) -> dict:
    sh("xcrun", "simctl", "terminate", udid, BUNDLE_ID, check=False)
    time.sleep(0.5)
    inject(udid, fx["payload"])
    sh("xcrun", "simctl", "launch", udid, BUNDLE_ID)
    time.sleep(settle)

    alive = running(udid)
    shot = out / f"{fx['name']}.png"
    sh("xcrun", "simctl", "io", udid, "screenshot", str(shot), check=False)

    return {
        "name": fx["name"],
        "expect": fx["expect"],
        "payload": fx["payload"],
        "survived": alive,
        "screenshot": str(shot),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--udid", required=True)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out")
    ap.add_argument("--only", help="run just this fixture name")
    # Long enough for a cold start plus routing. Note that a *toast* has usually
    # faded by the time the shot is taken, so an `already_visited_today` fixture
    # looks like a bare scanner screen — that is the expected picture, not a
    # missed branch. Lower it if you need to catch the toast itself.
    ap.add_argument("--settle", type=float, default=7.0,
                    help="seconds to wait after launch before screenshotting")
    args = ap.parse_args()

    assert_single_bundle(args.udid)
    assert_signed_in(args.udid)

    # Pre-grant the camera. ScannerScreen asks for it on open, and the system
    # dialog then covers whatever the fixture actually did — every screenshot
    # comes back as a permission prompt. Granting it changes nothing about the
    # test: the payload is injected, not seen through a lens. A reinstall resets
    # this, which is exactly when the dialogs come back.
    sh("xcrun", "simctl", "privacy", args.udid, "grant", "camera", BUNDLE_ID, check=False)

    args.out.mkdir(parents=True, exist_ok=True)

    # Regenerate and re-verify the QR images every run: a fixture that no longer
    # decodes is itself a failure worth seeing.
    qr_dir = args.out / "qr"
    gen = subprocess.run(
        [sys.executable, str(HERE / "qr_fixtures.py"), "--out", str(qr_dir)],
        capture_output=True, text=True,
    )
    print(gen.stdout, end="")
    if gen.returncode != 0:
        print(gen.stderr)
        return 1

    fixtures = json.loads((qr_dir / "manifest.json").read_text())
    if args.only:
        fixtures = [f for f in fixtures if f["name"] == args.only]
        if not fixtures:
            print(f"no fixture named {args.only}")
            return 1

    print(f"\nreplaying {len(fixtures)} fixtures on {args.udid}\n")
    results, crashed = [], 0
    for fx in fixtures:
        # Replay what the *detector* read back, so a QR that encodes wrongly
        # fails here rather than silently testing the string we started from.
        png = fx.get("png")
        if png:
            img = cv2.imread(png, cv2.IMREAD_GRAYSCALE)
            ok, decoded, _, _ = cv2.QRCodeDetector().detectAndDecodeMulti(img)
            if not ok or decoded[0] != fx["payload"]:
                print(f"FAIL  {fx['name']}: QR no longer decodes to its payload")
                crashed += 1
                continue
            fx = {**fx, "payload": decoded[0]}

        r = run_fixture(args.udid, fx, args.out, args.settle)
        results.append(r)
        if r["survived"]:
            print(f"  ok  {r['name']:34} survived -> expect {r['expect']}")
        else:
            crashed += 1
            print(f"CRASH {r['name']:34} app died replaying this payload")

    (args.out / "results.json").write_text(json.dumps(results, indent=2))
    print(f"\n{len(results) - crashed}/{len(results)} survived. "
          f"Screenshots + results.json in {args.out}")
    print("Check each screenshot against its `expect` — that is the branch assertion.")
    return 1 if crashed else 0


if __name__ == "__main__":
    sys.exit(main())
