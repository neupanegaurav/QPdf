#!/usr/bin/env python3
"""Download pinned official PDFs for QPdf's local C4.4 acceptance suite."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "test_corpus" / "real_forms" / "catalog.json"
OUTPUT = ROOT / "output" / "pdf" / "c4-real-world"


def main() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []
    for form in catalog["forms"]:
        target = OUTPUT / form["file"]
        request = Request(
            form["downloadUrl"],
            headers={"User-Agent": "QPdf compatibility testing"},
        )
        try:
            with urlopen(request, timeout=45) as response:
                data = response.read()
            if not data.startswith(b"%PDF-"):
                raise ValueError("server response is not a PDF")
            digest = hashlib.sha256(data).hexdigest()
            if digest != form["sha256"]:
                raise ValueError(
                    "official file changed; review it and update the pinned checksum "
                    f"(expected {form['sha256']}, received {digest})"
                )
            target.write_bytes(data)
            print(f"verified {form['id']}: {len(data)} bytes")
        except Exception as error:
            failures.append(f"{form['id']}: {error}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
