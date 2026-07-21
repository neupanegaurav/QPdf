#!/usr/bin/env python3
"""Parse, extract, render, and reopen every generated corpus PDF."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image
from pypdf import PdfReader, PdfWriter


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CORPUS = ROOT / "test_corpus" / "generated"


def command(*args: str) -> None:
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(args)}\n"
            f"{result.stdout}{result.stderr}"
        )


def verify_case(corpus: Path, case: dict, render_dir: Path) -> dict:
    path = corpus / case["file"]
    password = case["password"] or ""
    reader = PdfReader(path)
    if reader.is_encrypted and not reader.decrypt(password):
        raise AssertionError(f"Could not decrypt {case['id']}")
    if len(reader.pages) != case["page_count"]:
        raise AssertionError(f"Unexpected page count for {case['id']}")
    extracted = "\n".join(page.extract_text() or "" for page in reader.pages)
    if case["expected_text"] not in extracted:
        raise AssertionError(f"Expected text missing from {case['id']}")

    pdfinfo = ["pdfinfo"]
    if password:
        pdfinfo.extend(["-upw", password])
    command(*pdfinfo, str(path))

    prefix = render_dir / case["id"]
    render = ["pdftoppm", "-f", "1", "-singlefile", "-r", "96", "-png"]
    if password:
        render.extend(["-upw", password])
    command(*render, str(path), str(prefix))
    png_path = prefix.with_suffix(".png")
    with Image.open(png_path) as image:
        if image.width < 100 or image.height < 100:
            raise AssertionError(f"Implausible render dimensions for {case['id']}")
        dimensions = [image.width, image.height]
    digest = hashlib.sha256(png_path.read_bytes()).hexdigest()

    rewritten = render_dir / f"{case['id']}-rewritten.pdf"
    writer = PdfWriter()
    writer.clone_document_from_reader(reader)
    if password:
        writer.encrypt(password, algorithm="AES-256")
    with rewritten.open("wb") as stream:
        writer.write(stream)
    reopened = PdfReader(rewritten)
    if reopened.is_encrypted:
        reopened.decrypt(password)
    if len(reopened.pages) != case["page_count"]:
        raise AssertionError(f"Reopen failed for {case['id']}")

    return {"id": case["id"], "render_sha256": digest, "dimensions": dimensions}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--corpus", type=Path, default=DEFAULT_CORPUS)
    parser.add_argument("--keep-renders", action="store_true")
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    corpus = args.corpus.resolve()
    manifest = json.loads((corpus / "manifest.json").read_text(encoding="utf-8"))
    end = None if args.limit is None else args.start + args.limit
    cases = manifest["cases"][args.start:end]

    if args.keep_renders:
        render_dir = ROOT / "tmp" / "pdfs" / "corpus-renders"
        render_dir.mkdir(parents=True, exist_ok=True)
        results = [verify_case(corpus, case, render_dir) for case in cases]
    else:
        with tempfile.TemporaryDirectory(prefix="openpdf-renders-") as temporary:
            results = [
                verify_case(corpus, case, Path(temporary))
                for case in cases
            ]

    report = {
        "case_count": len(results),
        "parsed": len(results),
        "rendered": len(results),
        "reopened": len(results),
        "results": results,
    }
    suffix = "all" if args.start == 0 and args.limit is None else f"{args.start}-{args.start + len(results)}"
    report_path = corpus / f"verification-report-{suffix}.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(results)} PDFs; report: {report_path}")


if __name__ == "__main__":
    main()
