#!/usr/bin/env python3
"""Check every condition that has to hold before EatStreak reaches real users.

Why a script and not a checklist: the placeholders in this repo are the kind
nobody notices. `REPLACE_WITH_APPLE_TEAM_ID` sat in a file that Firebase Hosting
serves to every iPhone, and nothing anywhere failed because of it — the app just
quietly never opened from a scanned code. A list in a document does not fail a
build. This does.

    python3 tool/preflight.py            # report everything, fail on blockers
    python3 tool/preflight.py --store    # also fail on store-release gaps

Three severities, because they are not the same kind of problem:

  BLOCKER  would ship something actively wrong — demo data in a live build, an
           App Check flag that must never leave this machine. Fails the run.
  STORE    real, and blocks an App Store or Play release, but not a
           `firebase deploy`. Most of these need an Apple Developer account.
  MANUAL   a console step no deploy performs. Cannot be seen from here; printed
           so it is not forgotten, never silently "passed".

Reads mobile/env.json, which is gitignored and holds live API keys. It reports
whether a key is set and never what it contains.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

REPO = pathlib.Path(__file__).resolve().parent.parent

BUNDLE_ID = "com.eatstreak.app"
PROJECT_ID = "eatstreak-prod"
URL_SCHEME = "eatstreak"

# Keys a live build cannot start without. firebase_bootstrap.dart picks the
# per-platform key; the web one is the fallback and is not enough on its own.
REQUIRED_ENV = [
    "FIREBASE_API_KEY",
    "FIREBASE_IOS_API_KEY",
    "FIREBASE_ANDROID_API_KEY",
    "FIREBASE_PROJECT_ID",
    "FIREBASE_APP_ID",
    "FIREBASE_IOS_APP_ID",
    "FIREBASE_MESSAGING_SENDER_ID",
    "FIREBASE_AUTH_DOMAIN",
    "FIREBASE_STORAGE_BUCKET",
]

results: list[tuple[str, str, str, str]] = []  # severity, state, title, detail


def record(severity: str, ok: bool, title: str, detail: str = "") -> bool:
    results.append((severity, "ok" if ok else "fail", title, detail.strip()))
    return ok


def read_json(path: pathlib.Path):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return None
    except json.JSONDecodeError as e:
        return e


# ---- the host every printed code points at ---------------------------------

def link_domain(env: dict | None) -> str:
    """Mirror Env.linkDomain in mobile/lib/core/config/env.dart.

    An explicit LINK_DOMAIN wins; otherwise it is derived from the project id.
    Worth mirroring rather than hardcoding: the fallback is what is actually in
    force here, and a check that hardcoded the answer would not notice if
    someone set LINK_DOMAIN to something the AASA is not served on.
    """
    if env:
        explicit = (env.get("LINK_DOMAIN") or "").strip()
        if explicit:
            return explicit
        project = (env.get("FIREBASE_PROJECT_ID") or "").strip()
        if project:
            return f"{project}.web.app"
    return "eatstreak.app"


# ---- blockers ---------------------------------------------------------------

def check_env(env) -> dict | None:
    if env is None:
        record("BLOCKER", False, "mobile/env.json is missing",
               "A build without it runs on-device demo data and never reaches "
               "the backend. It is gitignored on purpose; copy it from your "
               "password manager or recreate it from the Firebase console.")
        return None
    if isinstance(env, Exception):
        record("BLOCKER", False, "mobile/env.json is not valid JSON", str(env))
        return None

    demo = str(env.get("DEMO_MODE", "")).lower()
    record("BLOCKER", demo == "false",
           f"DEMO_MODE is {demo or '<unset>'}",
           "" if demo == "false" else
           "DEMO_MODE defaults to TRUE. A release built with this file would "
           "ship seeded on-device data — real customers, real QR codes, and "
           "nothing ever written to Firestore. Set it to the string \"false\".")

    missing = [k for k in REQUIRED_ENV if not str(env.get(k, "")).strip()]
    record("BLOCKER", not missing,
           "Firebase keys present" if not missing
           else f"{len(missing)} Firebase key(s) empty",
           "" if not missing else
           "Empty: " + ", ".join(missing) + "\n"
           "Env.hasFirebaseConfig needs an API key AND a project id, and the "
           "iOS/Android keys are separate because Firebase restricts each one "
           "by bundle id. Values live in the Firebase console under Project "
           "settings > Your apps.")
    return env


def check_app_check() -> None:
    """APP_CHECK=false must never ship, so it must never be committed."""
    offenders = []
    for path in REPO.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(REPO).as_posix()
        if rel.startswith((".git/", "node_modules/", "mobile/build/",
                           "functions/lib", "tool/e2e/out/")):
            continue
        if path.suffix not in {".json", ".sh", ".yml", ".yaml", ".plist"}:
            continue
        if rel == "mobile/env.json":
            continue
        try:
            if re.search(r'APP_CHECK"?\s*[:=]\s*"?false', path.read_text()):
                offenders.append(rel)
        except (UnicodeDecodeError, OSError):
            continue

    record("BLOCKER", not offenders, "APP_CHECK=false is not committed anywhere",
           "" if not offenders else
           "Found in: " + ", ".join(offenders) + "\n"
           "That flag exists for one unsigned phone. A properly signed build "
           "can attest, and shipping it disabled leaves every client "
           "unattested for good. Pass it on the command line or not at all.")


def check_url_scheme(domain: str) -> None:
    plist = REPO / "mobile/ios/Runner/Info.plist"
    try:
        data = plistlib.loads(plist.read_bytes())
    except (OSError, plistlib.InvalidFileException) as e:
        record("BLOCKER", False, "Cannot read ios/Runner/Info.plist", str(e))
        return

    schemes = {s for t in data.get("CFBundleURLTypes", [])
               for s in t.get("CFBundleURLSchemes", [])}
    record("BLOCKER", URL_SCHEME in schemes,
           f"'{URL_SCHEME}://' URL scheme is registered",
           "" if URL_SCHEME in schemes else
           f"Info.plist registers {sorted(schemes) or 'nothing'}.\n"
           "Until Associated Domains works, this scheme is the ONLY way a "
           f"stock-camera scan reaches the app: https://{domain}/c/... opens "
           "Safari, and the fallback page's button hands off via "
           f"{URL_SCHEME}://check-in/<shop>. Lose the scheme and that path "
           "dead-ends on a web page.")


# ---- store readiness --------------------------------------------------------

TEAM_ID = re.compile(r"^[A-Z0-9]{10}$")
SHA256 = re.compile(r"^([A-F0-9]{2}:){31}[A-F0-9]{2}$", re.IGNORECASE)


def check_aasa(domain: str) -> None:
    path = REPO / "public/.well-known/apple-app-site-association"
    aasa = read_json(path)
    if aasa is None or isinstance(aasa, Exception):
        record("STORE", False, "apple-app-site-association missing or invalid",
               str(aasa) if aasa else f"Expected at {path.relative_to(REPO)}")
        return

    details = aasa.get("applinks", {}).get("details", [])
    app_ids = {i for d in details for i in (d.get("appIDs") or [])}
    app_ids |= {d["appID"] for d in details if d.get("appID")}

    bad = [a for a in app_ids if not (
        "." in a and TEAM_ID.match(a.split(".", 1)[0])
        and a.split(".", 1)[1] == BUNDLE_ID)]

    record("STORE", bool(app_ids) and not bad,
           "AASA carries a real Team ID",
           "" if not bad else
           "Unusable appID(s): " + ", ".join(sorted(bad)) + "\n"
           "Format is <10-char Team ID>." + BUNDLE_ID + ". Find the Team ID at "
           "developer.apple.com > Membership (it is also the prefix of any "
           "provisioning profile). Requires a paid Developer Program "
           "membership — free provisioning has no team.\n"
           "Until this is real, iOS silently refuses to associate the domain: "
           f"scanning a printed code opens Safari on {domain}/c/... instead of "
           "the app. One extra tap, not a dead end, but not the flow you "
           "designed.\n"
           "Apple caches this file. After deploying, re-check with:\n"
           f"  curl -s https://{domain}/.well-known/apple-app-site-association")

    paths = {p for d in details for p in (d.get("paths") or [])}
    paths |= {c.get("/") for d in details for c in (d.get("components") or [])}
    record("STORE", "/c/*" in paths, "AASA claims /c/*",
           "" if "/c/*" in paths else
           f"Claims {sorted(p for p in paths if p)}. Check-in links are "
           "https://<host>/c/<shopId>, so /c/* is the path that matters.")


def check_entitlement(domain: str) -> None:
    ents = list((REPO / "mobile/ios").rglob("*.entitlements"))
    ents = [e for e in ents if "Pods" not in e.parts]
    wanted = f"applinks:{domain}"

    if not ents:
        record("STORE", False, "No iOS entitlements file",
               "The AASA half is served by Hosting; this is the app half, and "
               "without it iOS never even asks for the file.\n"
               "Both are needed, and both need the paid Developer Program: "
               "Associated Domains is not available under free provisioning, "
               "so adding it now would break signing rather than fix "
               "anything. Do it in this order:\n"
               "  1. Enrol at developer.apple.com/programs ($99/yr)\n"
               "  2. Xcode > Runner > Signing & Capabilities > + Capability >\n"
               "     Associated Domains, then add: " + wanted + "\n"
               "  3. Put the Team ID in the AASA file and deploy hosting\n"
               "  4. Reinstall the app — iOS only fetches the AASA at install")
        return

    found = [e for e in ents if wanted in e.read_text()]
    record("STORE", bool(found), f"Entitlement claims {wanted}",
           "" if found else
           "Entitlements exist (" + ", ".join(e.name for e in ents) + ") but "
           f"none lists {wanted}. It must match the host the app builds codes "
           "for, or iOS associates a domain nothing points at.")


ANDROID_NS = "{http://schemas.android.com/apk/res/android}"


def check_android_intent_filter(domain: str) -> None:
    """The app half of Android App Links, and the counterpart to assetlinks.json.

    Attributes spread across several <data> elements inside one intent-filter are
    merged by Android, so they are gathered per filter rather than per element —
    checking a single <data> tag would miss the common split form and report a
    working manifest as broken.
    """
    manifest = REPO / "mobile/android/app/src/main/AndroidManifest.xml"
    try:
        root = ET.parse(manifest).getroot()
    except (OSError, ET.ParseError) as e:
        record("STORE", False, "Cannot read AndroidManifest.xml", str(e))
        return

    for flt in root.iter("intent-filter"):
        data = list(flt.iter("data"))
        schemes = {d.get(ANDROID_NS + "scheme") for d in data}
        hosts = {d.get(ANDROID_NS + "host") for d in data}
        if "https" in schemes and domain in hosts:
            verified = flt.get(ANDROID_NS + "autoVerify") == "true"
            record("STORE", verified, f"Android claims https://{domain}",
                   "" if verified else
                   "The intent-filter exists but has no "
                   'android:autoVerify="true", so Android never fetches '
                   "assetlinks.json and the link opens a chooser (or the "
                   "browser) instead of the app.")
            return

    record("STORE", False, f"Android does not claim https://{domain}",
           "AndroidManifest.xml registers the eatstreak:// scheme and nothing "
           "else, so assetlinks.json is served with nothing on the app side "
           "asking for it — the same gap as the missing iOS entitlement, and "
           "it fails the same silent way: a scanned code opens a browser.\n"
           "Add inside the .MainActivity <activity>, alongside the existing "
           "scheme filter:\n"
           '  <intent-filter android:autoVerify="true">\n'
           "    <action android:name=\"android.intent.action.VIEW\"/>\n"
           "    <category android:name=\"android.intent.category.DEFAULT\"/>\n"
           "    <category android:name=\"android.intent.category.BROWSABLE\"/>\n"
           f'    <data android:scheme="https" android:host="{domain}"\n'
           '          android:pathPrefix="/c"/>\n'
           "  </intent-filter>\n"
           "Unlike iOS this needs no paid account — but it is only worth "
           "adding with the real signing fingerprint in assetlinks.json, or "
           "verification fails and Android quietly stops honouring the claim.")


def check_assetlinks() -> None:
    path = REPO / "public/.well-known/assetlinks.json"
    links = read_json(path)
    if links is None or isinstance(links, Exception):
        record("STORE", False, "assetlinks.json missing or invalid",
               str(links) if links else f"Expected at {path.relative_to(REPO)}")
        return

    prints = [f for e in links
              for f in e.get("target", {}).get("sha256_cert_fingerprints", [])]
    bad = [f for f in prints if not SHA256.match(f)]
    record("STORE", bool(prints) and not bad,
           "assetlinks carries a real signing fingerprint",
           "" if not bad else
           "Unusable: " + ", ".join(bad) + "\n"
           "Must be 32 colon-separated hex bytes.\n"
           "If you use Play App Signing (the default), Google re-signs your "
           "upload, so the fingerprint that matters is THEIRS, not your "
           "keystore's: Play Console > your app > Test and release > Setup > "
           "App signing > 'SHA-256 certificate fingerprint'. Taking it from "
           "your local keystore instead is the usual mistake and App Links "
           "then silently never verify.\n"
           "Self-signing instead? "
           "keytool -list -v -keystore <file> -alias <alias>")

    packages = {e.get("target", {}).get("package_name") for e in links}
    record("STORE", packages == {BUNDLE_ID}, "assetlinks package matches",
           "" if packages == {BUNDLE_ID} else
           f"Declares {sorted(p for p in packages if p)}, expected {BUNDLE_ID}.")


def check_store_id() -> None:
    page = REPO / "public/c/index.html"
    try:
        text = page.read_text()
    except OSError as e:
        record("STORE", False, "Cannot read public/c/index.html", str(e))
        return

    ids = re.findall(r"app-id=([^\"'\s]+)", text)
    ids += re.findall(r"apps\.apple\.com/app/id([^\"'\s]+)", text)
    bad = [i for i in ids if not i.isdigit()]
    record("STORE", bool(ids) and not bad, "App Store ID is numeric",
           "" if not bad else
           "Found: " + ", ".join(bad) + "\n"
           "The numeric id only exists once the app record is created in App "
           "Store Connect (visible in the URL, and under App Information > "
           "General > Apple ID). Until then the iOS smart banner on the "
           "fallback page does not render and the App Store button 404s.")


def check_leftover_placeholders() -> None:
    """Anything else Hosting would serve with REPLACE_WITH_ still in it.

    The billing link is exempt: public/billing/ disables its own button while
    the link is a placeholder, which is deliberate — there is no Curlec account
    yet and a button that goes nowhere is worse than one that says so.
    """
    known = {
        "public/.well-known/apple-app-site-association",
        "public/.well-known/assetlinks.json",
        "public/c/index.html",
        "public/billing/index.html",
    }
    stray = []
    for path in (REPO / "public").rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(REPO).as_posix()
        if rel in known:
            continue
        try:
            if "REPLACE_WITH" in path.read_text():
                stray.append(rel)
        except (UnicodeDecodeError, OSError):
            continue

    record("STORE", not stray, "No unaccounted placeholders in public/",
           "" if not stray else
           "Found in: " + ", ".join(stray) + "\nHosting serves these verbatim.")


# ---- manual gates -----------------------------------------------------------

MANUAL = [
    ("Firestore TTL policy on checkInTokens.ttlAt",
     "No deploy creates this and nothing fails without it — day codes simply "
     "accumulate forever, one document per shop per day.\n"
     "Firebase console > Firestore > Time-to-live > Create policy\n"
     f"  Collection group: checkInTokens    Field: ttlAt    ({PROJECT_ID})"),
    ("App Check enforcement stays OFF",
     "Turn it on only once tokens are visibly arriving in the console, and "
     "never before. Enforcing early locks out every already-installed build, "
     "including yours. Note App Attest cannot issue a token at all without a "
     "paid Developer Program membership."),
    ("CURLEC_WEBHOOK_SECRET is unset — billing is inert by design",
     "There is no Curlec account yet, so the subscription page disables its own "
     "button and curlecWebhook has nothing to verify against. When that "
     "changes, YOU run it — it takes a credential:\n"
     "  firebase functions:secrets:set CURLEC_WEBHOOK_SECRET"),
    ("Deploy the backend after any change under functions/, firestore.*, public/",
     "This preflight reads the working tree, not what is live. You run:\n"
     "  firebase deploy --only functions,firestore:rules,firestore:indexes,hosting"),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--store", action="store_true",
                    help="also fail on store-release gaps, not just blockers")
    args = ap.parse_args()

    env = check_env(read_json(REPO / "mobile/env.json"))
    domain = link_domain(env if isinstance(env, dict) else None)

    check_app_check()
    check_url_scheme(domain)

    check_aasa(domain)
    check_entitlement(domain)
    check_android_intent_filter(domain)
    check_assetlinks()
    check_store_id()
    check_leftover_placeholders()

    width = 72
    for severity in ("BLOCKER", "STORE"):
        rows = [r for r in results if r[0] == severity]
        if not rows:
            continue
        heading = ("Ship-breaking" if severity == "BLOCKER"
                   else "Store release (App Store / Play)")
        print(f"\n{heading}\n" + "-" * width)
        for _, state, title, detail in rows:
            print(f"  {'ok  ' if state == 'ok' else 'FAIL'}  {title}")
            if detail and state != "ok":
                for line in detail.splitlines():
                    print(f"        {line}")

    print(f"\nManual — no deploy performs these, and this script cannot see them"
          f"\n" + "-" * width)
    for title, detail in MANUAL:
        print(f"  ??    {title}")
        for line in detail.splitlines():
            print(f"        {line}")

    blockers = [r for r in results if r[0] == "BLOCKER" and r[1] == "fail"]
    store = [r for r in results if r[0] == "STORE" and r[1] == "fail"]

    print("\n" + "=" * width)
    print(f"  {len(blockers)} blocker(s), {len(store)} store gap(s), "
          f"{len(MANUAL)} manual step(s) to confirm by hand.")
    if not blockers:
        print("  Nothing here would ship something wrong. Deploying the "
              "backend is safe.")
    if store:
        print("  Not ready for an App Store or Play release.")
    print("=" * width)

    if blockers:
        return 1
    return 2 if (store and args.store) else 0


if __name__ == "__main__":
    sys.exit(main())
