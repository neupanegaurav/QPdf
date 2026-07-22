#!/usr/bin/env python3
"""Parse the shipping store copy out of docs/STORE_SUBMISSION.md section 8.

Section 8 is named in CLAUDE.md as the single source of truth for both stores.
Publishing from a parsed copy of it, rather than from a duplicate embedded in a
script, is the whole point: STORE_LISTING_DRAFT.md was a second hand-maintained
copy and it silently drifted into advertising a feature the binary no longer
had, which is an App Review rejection under "accurate metadata".

Import `listing()` from the publish scripts; run this file directly to inspect
what would be pushed.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "STORE_SUBMISSION.md"

# (key, regex) - each captures exactly one field of section 8. Kept explicit
# rather than clever so a copy edit that breaks a pattern fails loudly here
# instead of pushing half a listing to a live store.
_PATTERNS = [
    ("name",         r"\*\*App name \(30 char max\)\*\*\s*\n`([^`]+)`"),
    ("short",        r"\*\*Short description \(80 char max\)\*\*[^\n]*\n`([^`]+)`"),
    ("full",         r"\*\*Full description \(4000 char max\)\*\*\s*\n\n```\n(.*?)\n```"),
    ("subtitle",     r"\*\*Apple subtitle \(30 char max\)\*\*\s*\n`([^`]+)`"),
    ("keywords",     r"\*\*Apple keywords \(100 char max\)\*\*[^\n]*\n`([^`]+)`"),
    ("promo",        r"\*\*Apple promotional text \(170 char max\)\*\*\s*\n`([^`]+)`"),
    ("release_notes", r"\*\*Release notes \(([^)]+)\)\*\*\s*\n```\n(.*?)\n```"),
    ("support_url",  r"\*\*Support URL\*\*:\s*`([^`]+)`"),
    ("marketing_url", r"\*\*Marketing URL\*\*:\s*`([^`]+)`"),
]

# Store-enforced ceilings. Exceeding one is rejected at upload, so check here
# where the error is readable rather than in an API traceback.
LIMITS = {
    "name": 30, "short": 80, "full": 4000,
    "subtitle": 30, "keywords": 100, "promo": 170,
}


def listing():
    text = DOC.read_text()
    out = {}
    for key, pattern in _PATTERNS:
        m = re.search(pattern, text, re.S)
        if not m:
            sys.exit(f"{DOC.name} section 8: could not find '{key}'. "
                     "The copy or its heading changed - fix the pattern in "
                     f"{pathlib.Path(__file__).name} before publishing.")
        out[key] = m.group(m.lastindex).strip()

    for key, cap in LIMITS.items():
        if len(out[key]) > cap:
            sys.exit(f"'{key}' is {len(out[key])} chars, over the {cap} limit.")
    return out


if __name__ == "__main__":
    data = listing()
    for key, value in data.items():
        cap = LIMITS.get(key)
        size = f"{len(value)}/{cap}" if cap else f"{len(value)} chars"
        head = value if "\n" not in value else value.split("\n", 1)[0] + " ..."
        print(f"{key:<15} [{size:>9}]  {head}")
