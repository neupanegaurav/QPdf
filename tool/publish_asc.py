#!/usr/bin/env python3
"""Push QPdf metadata and screenshots to App Store Connect.

Like the Play side, this needs the app record to already exist. The App Store
Connect API exposes /v1/apps as read-and-update only - there is no POST, so no
script can create the record. Create it once in the browser (the bundle ID
studio.gaurav.qpdf is already registered, so the picker will offer it), then
everything below runs from the terminal.

Usage:
  publish_asc.py check                  # auth, app record, version state
  publish_asc.py metadata               # dry run: show what would change
  publish_asc.py metadata --commit      # write name/subtitle/description/...
  publish_asc.py screenshots --commit   # upload store/screenshots/ios-*

Nothing is written without --commit.

Credentials come from store-upload-kit/, which is untracked. This file is not:
never inline the .p8 or its key ID beyond what the kit already records.
"""
import argparse
import hashlib
import json
import mimetypes
import pathlib
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from store_listing import listing  # noqa: E402

try:
    import jwt
except ImportError:
    sys.exit("Run with the kit venv: store-upload-kit/.venv/bin/python "
             "tool/publish_asc.py ...")

ROOT = pathlib.Path(__file__).resolve().parent.parent
KIT = ROOT / "store-upload-kit/ios"
KEY_ID = "Y9YT3773M9"
ISSUER_ID = "282d24aa-dc21-4e1d-907c-f7fdcbb72193"
BUNDLE_ID = "studio.gaurav.qpdf"
BASE = "https://api.appstoreconnect.apple.com/v1"
LOCALE = "en-US"

# Apple's displayType enum -> repo folder. The 6.9" iPhone and 13" iPad sets
# still upload under the 67/129 slots.
SCREENSHOT_SETS = {
    "APP_IPHONE_67": ROOT / "store/screenshots/ios-iphone",
    "APP_IPAD_PRO_3GEN_129": ROOT / "store/screenshots/ios-ipad",
}


def token():
    key_path = KIT / f"AuthKey_{KEY_ID}.p8"
    if not key_path.exists():
        sys.exit(f"App Store Connect key not found: {key_path}")
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key_path.read_text(), algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"})


def call(method, path, body=None, raw=None, url=None, headers=None):
    target = url or (BASE + path)
    data = raw if raw is not None else (json.dumps(body).encode() if body else None)
    req = urllib.request.Request(target, data=data, method=method)
    if not url:
        req.add_header("Authorization", f"Bearer {token()}")
    if body is not None and raw is None:
        req.add_header("Content-Type", "application/json")
    for key, value in (headers or {}).items():
        req.add_header(key, value)
    try:
        with urllib.request.urlopen(req) as resp:
            payload = resp.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as exc:
        sys.exit(f"HTTP {exc.code} on {method} {path or target}\n{exc.read().decode()}")


def find_app():
    apps = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}&limit=1").get("data", [])
    return apps[0] if apps else None


def editable_version(app_id):
    """The version still open for editing, if there is one."""
    versions = call(
        "GET",
        f"/apps/{app_id}/appStoreVersions?limit=5"
        "&fields[appStoreVersions]=versionString,appStoreState,platform",
    ).get("data", [])
    open_states = {
        "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
        "METADATA_REJECTED", "WAITING_FOR_REVIEW", "INVALID_BINARY",
    }
    for version in versions:
        if version["attributes"].get("appStoreState") in open_states:
            return version
    return None


def check(_args):
    copy = listing()
    print("Listing copy parsed from docs/STORE_SUBMISSION.md section 8:")
    print(f"  name       {copy['name']}")
    print(f"  subtitle   {copy['subtitle']}")
    print(f"  keywords   {len(copy['keywords'])}/100 chars\n")

    print("iOS screenshots:")
    for display_type, folder in SCREENSHOT_SETS.items():
        shots = sorted(folder.glob("*.png")) if folder.exists() else []
        state = f"{len(shots)} file(s)" if shots else "NONE - needs an iOS build"
        print(f"  {display_type:<24} {state}")

    print("\nApp Store Connect:")
    app = find_app()
    if not app:
        print(f"  NOT READY - no app record for {BUNDLE_ID}.")
        print("  The ASC API cannot create one; do it once in the browser.")
        return
    app_id = app["id"]
    print(f"  app record {app_id} - {app['attributes'].get('name')}")
    version = editable_version(app_id)
    if version:
        attrs = version["attributes"]
        print(f"  editable version {attrs['versionString']} "
              f"({attrs['appStoreState']})")
    else:
        print("  no version open for editing - create one in the browser.")


def _localization(version_id):
    locs = call("GET", f"/appStoreVersions/{version_id}"
                       "/appStoreVersionLocalizations?limit=50").get("data", [])
    for loc in locs:
        if loc["attributes"].get("locale") == LOCALE:
            return loc
    sys.exit(f"No {LOCALE} localization on the version; add it in the browser.")


def metadata(args):
    copy = listing()
    app = find_app()
    if not app:
        sys.exit(f"No app record for {BUNDLE_ID} - create it in the browser first.")
    version = editable_version(app["id"])
    if not version:
        sys.exit("No version open for editing.")

    loc = _localization(version["id"])
    version_fields = {
        "description": copy["full"],
        "keywords": copy["keywords"],
        "promotionalText": copy["promo"],
        "whatsNew": copy["release_notes"],
        "supportUrl": copy["support_url"],
        "marketingUrl": copy["marketing_url"],
    }

    info = call("GET", f"/apps/{app['id']}/appInfos?limit=1").get("data", [])
    info_locs = call("GET", f"/appInfos/{info[0]['id']}/appInfoLocalizations"
                            "?limit=50").get("data", []) if info else []
    info_loc = next((l for l in info_locs
                     if l["attributes"].get("locale") == LOCALE), None)
    info_fields = {"name": copy["name"], "subtitle": copy["subtitle"]}

    print(f"version localization {loc['id']}:")
    for key, value in version_fields.items():
        print(f"  {key:<16} {len(value)} chars")
    if info_loc:
        print(f"app info localization {info_loc['id']}:")
        for key, value in info_fields.items():
            print(f"  {key:<16} {value}")

    if not args.commit:
        print("\ndry run - nothing written. Re-run with --commit.")
        return

    call("PATCH", f"/appStoreVersionLocalizations/{loc['id']}",
         {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"],
                   "attributes": version_fields}})
    if info_loc:
        call("PATCH", f"/appInfoLocalizations/{info_loc['id']}",
             {"data": {"type": "appInfoLocalizations", "id": info_loc["id"],
                       "attributes": info_fields}})
    print("\ncommitted - metadata updated.")


def screenshots(args):
    app = find_app()
    if not app:
        sys.exit(f"No app record for {BUNDLE_ID} - create it in the browser first.")
    version = editable_version(app["id"])
    if not version:
        sys.exit("No version open for editing.")
    loc_id = _localization(version["id"])["id"]

    existing = call("GET", f"/appStoreVersionLocalizations/{loc_id}"
                           "/appScreenshotSets?limit=50").get("data", [])
    by_type = {s["attributes"]["screenshotDisplayType"]: s["id"] for s in existing}

    for display_type, folder in SCREENSHOT_SETS.items():
        shots = sorted(folder.glob("*.png")) if folder.exists() else []
        if not shots:
            print(f"{display_type}: no files in {folder.relative_to(ROOT)}, skipped")
            continue
        print(f"{display_type}: {len(shots)} file(s)")
        if not args.commit:
            for path in shots:
                print(f"  would upload {path.name}")
            continue

        set_id = by_type.get(display_type)
        if not set_id:
            created = call("POST", "/appScreenshotSets", {
                "data": {"type": "appScreenshotSets",
                         "attributes": {"screenshotDisplayType": display_type},
                         "relationships": {"appStoreVersionLocalization": {
                             "data": {"type": "appStoreVersionLocalizations",
                                      "id": loc_id}}}}})
            set_id = created["data"]["id"]

        for path in shots:
            _upload_screenshot(set_id, path)
            print(f"  uploaded {path.name}")

    if not args.commit:
        print("\ndry run - nothing written. Re-run with --commit.")


def _upload_screenshot(set_id, path):
    """Apple's three-step asset upload: reserve, PUT the parts, then commit."""
    blob = path.read_bytes()
    reserved = call("POST", "/appScreenshots", {
        "data": {"type": "appScreenshots",
                 "attributes": {"fileSize": len(blob), "fileName": path.name},
                 "relationships": {"appScreenshotSet": {
                     "data": {"type": "appScreenshotSets", "id": set_id}}}}})
    shot_id = reserved["data"]["id"]
    mime = mimetypes.guess_type(path.name)[0] or "image/png"

    for op in reserved["data"]["attributes"]["uploadOperations"]:
        chunk = blob[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        headers.setdefault("Content-Type", mime)
        call(op["method"], "", raw=chunk, url=op["url"], headers=headers)

    call("PATCH", f"/appScreenshots/{shot_id}", {
        "data": {"type": "appScreenshots", "id": shot_id,
                 "attributes": {"uploaded": True,
                                "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})


parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
sub = parser.add_subparsers(dest="cmd", required=True)
sub.add_parser("check").set_defaults(fn=check)
p_meta = sub.add_parser("metadata")
p_meta.add_argument("--commit", action="store_true")
p_meta.set_defaults(fn=metadata)
p_shots = sub.add_parser("screenshots")
p_shots.add_argument("--commit", action="store_true")
p_shots.set_defaults(fn=screenshots)

args = parser.parse_args()
args.fn(args)
