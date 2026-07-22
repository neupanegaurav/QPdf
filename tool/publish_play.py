#!/usr/bin/env python3
"""Push the QPdf store listing, graphics and bundle to Google Play.

Everything here needs the Play Console app record to already exist. No Google
API can create it, and Play refuses API uploads until the first bundle has gone
through the browser once - see docs/PROJECT_STATE.md section 1. Until then every
call returns `404 Package not found`.

Usage:
  publish_play.py check                 # parse copy, list assets, verify API reach
  publish_play.py listing               # dry run: show what would change
  publish_play.py listing --commit      # actually write the listing + graphics
  publish_play.py bundle <path.aab> --track internal --commit

Nothing is written without --commit. A Play edit is a transaction: this builds
one, applies changes, and either commits it or throws it away, so a dry run can
never leave a half-updated listing behind.

Credentials come from store-upload-kit/, which is untracked. This file is not:
keep it that way, and never inline a key here.
"""
import argparse
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from store_listing import listing  # noqa: E402

try:
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload
except ImportError:
    sys.exit("Run with the kit venv: store-upload-kit/.venv/bin/python "
             "tool/publish_play.py ...")

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACKAGE = "studio.gaurav.qpdf"
LANGUAGE = "en-US"
KEY = os.environ.get(
    "PLAY_SA_KEY", str(ROOT / "store-upload-kit/android/play-service-account.json"))

# Play's imageType -> where that asset lives in the repo. Tablet captures are
# landscape 2560x1600, which Play accepts for the ten-inch slot.
GRAPHICS = {
    "icon": [ROOT / "store/graphics/play-icon-512.png"],
    "featureGraphic": [ROOT / "store/graphics/play-feature-graphic-1024x500.png"],
    "phoneScreenshots": sorted((ROOT / "store/screenshots/android-phone").glob("*.png")),
    "tenInchScreenshots": sorted((ROOT / "store/screenshots/android-tablet").glob("*.png")),
}


def service():
    if not os.path.exists(KEY):
        sys.exit(f"Play service-account key not found: {KEY}")
    creds = service_account.Credentials.from_service_account_file(
        KEY, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def _assets():
    """Resolve the graphics set, failing loudly on anything missing."""
    resolved, missing = {}, []
    for image_type, paths in GRAPHICS.items():
        found = [p for p in paths if p.exists()]
        if not found:
            missing.append(image_type)
        resolved[image_type] = found
    return resolved, missing


def check(_args):
    copy = listing()
    print(f"Listing copy parsed from docs/STORE_SUBMISSION.md section 8:")
    print(f"  title            {copy['name']}")
    print(f"  shortDescription {copy['short'][:60]}...")
    print(f"  fullDescription  {len(copy['full'])} chars\n")

    resolved, missing = _assets()
    print("Graphics:")
    for image_type, paths in resolved.items():
        print(f"  {image_type:<20} {len(paths)} file(s)")
        for p in paths:
            print(f"      {p.relative_to(ROOT)}")
    if missing:
        print(f"\n  MISSING: {', '.join(missing)}")

    print("\nAPI reachability:")
    svc = service()
    try:
        edit = svc.edits().insert(packageName=PACKAGE, body={}).execute()
        svc.edits().delete(packageName=PACKAGE, editId=edit["id"]).execute()
        print(f"  OK - {PACKAGE} exists and the service account can edit it.")
    except Exception as exc:  # noqa: BLE001 - the message is the useful part
        print(f"  NOT READY - {exc}")
        print("  Expected until the Play Console record exists and the service")
        print("  account is granted release + view-app-information permissions.")


def push_listing(args):
    copy = listing()
    resolved, missing = _assets()
    if missing:
        sys.exit(f"Refusing to publish, missing graphics: {', '.join(missing)}")

    svc = service()
    edit = svc.edits().insert(packageName=PACKAGE, body={}).execute()
    eid = edit["id"]
    try:
        svc.edits().listings().update(
            packageName=PACKAGE, editId=eid, language=LANGUAGE,
            body={"title": copy["name"],
                  "shortDescription": copy["short"],
                  "fullDescription": copy["full"]},
        ).execute()
        print(f"listing text staged ({LANGUAGE})")

        for image_type, paths in resolved.items():
            svc.edits().images().deleteall(
                packageName=PACKAGE, editId=eid,
                language=LANGUAGE, imageType=image_type).execute()
            for path in paths:
                svc.edits().images().upload(
                    packageName=PACKAGE, editId=eid, language=LANGUAGE,
                    imageType=image_type,
                    media_body=MediaFileUpload(str(path), mimetype="image/png"),
                ).execute()
                print(f"  {image_type:<20} {path.name}")

        if args.commit:
            svc.edits().commit(packageName=PACKAGE, editId=eid).execute()
            print("\ncommitted - the listing is live on Play.")
        else:
            svc.edits().delete(packageName=PACKAGE, editId=eid).execute()
            print("\ndry run - edit discarded. Re-run with --commit to publish.")
    except Exception:
        svc.edits().delete(packageName=PACKAGE, editId=eid).execute()
        raise


def push_bundle(args):
    aab = pathlib.Path(args.aab)
    if not aab.exists():
        sys.exit(f"Bundle not found: {aab}")

    svc = service()
    edit = svc.edits().insert(packageName=PACKAGE, body={}).execute()
    eid = edit["id"]
    try:
        print(f"uploading {aab.name} ({aab.stat().st_size / 1e6:.1f} MB) ...")
        bundle = svc.edits().bundles().upload(
            packageName=PACKAGE, editId=eid,
            media_body=MediaFileUpload(str(aab), mimetype="application/octet-stream",
                                       resumable=True),
        ).execute()
        code = bundle["versionCode"]
        notes = listing()["release_notes"]
        svc.edits().tracks().update(
            packageName=PACKAGE, editId=eid, track=args.track,
            body={"track": args.track,
                  "releases": [{"status": "completed",
                                "versionCodes": [code],
                                "releaseNotes": [{"language": LANGUAGE,
                                                  "text": notes}]}]},
        ).execute()
        print(f"versionCode {code} staged on '{args.track}'")

        if args.commit:
            svc.edits().commit(packageName=PACKAGE, editId=eid).execute()
            print("committed.")
        else:
            svc.edits().delete(packageName=PACKAGE, editId=eid).execute()
            print("dry run - edit discarded. Re-run with --commit to publish.")
    except Exception:
        svc.edits().delete(packageName=PACKAGE, editId=eid).execute()
        raise


parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
sub = parser.add_subparsers(dest="cmd", required=True)
sub.add_parser("check").set_defaults(fn=check)
p_listing = sub.add_parser("listing")
p_listing.add_argument("--commit", action="store_true")
p_listing.set_defaults(fn=push_listing)
p_bundle = sub.add_parser("bundle")
p_bundle.add_argument("aab")
p_bundle.add_argument("--track", default="internal",
                      choices=["internal", "alpha", "beta", "production"])
p_bundle.add_argument("--commit", action="store_true")
p_bundle.set_defaults(fn=push_bundle)

args = parser.parse_args()
args.fn(args)
