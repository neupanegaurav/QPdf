#!/usr/bin/env python3
"""Generate a deterministic, legally distributable PDF compatibility corpus."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.lib.colors import Color, HexColor
from reportlab.lib.pagesizes import A4, LEGAL, LETTER, landscape
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "test_corpus" / "generated"
PASSWORD = "openpdf-test"
PAGE_SIZES = {
    "a4": A4,
    "letter": LETTER,
    "legal": LEGAL,
    "landscape-a4": landscape(A4),
    "square": (540.0, 540.0),
    "receipt": (226.8, 680.0),
}
ROTATIONS = (0, 90, 180, 270)
CONTENT_MODES = ("text", "vector", "form", "annotation", "encrypted")


def draw_header(pdf: canvas.Canvas, width: float, height: float, case_id: str) -> None:
    pdf.setFillColor(HexColor("#264A9B"))
    pdf.rect(0, height - 62, width, 62, stroke=0, fill=1)
    pdf.setFillColorRGB(1, 1, 1)
    pdf.setFont("Helvetica-Bold", 18)
    pdf.drawString(28, height - 39, "QPdf compatibility fixture")
    pdf.setFillColorRGB(0.12, 0.14, 0.18)
    pdf.setFont("Helvetica", 10)
    pdf.drawString(28, height - 82, f"Case: {case_id}")


def draw_content(
    pdf: canvas.Canvas,
    width: float,
    height: float,
    mode: str,
    page_number: int,
) -> None:
    marker = f"OPENPDF-CORPUS-{mode.upper()}"
    pdf.setFillColorRGB(0.12, 0.14, 0.18)
    pdf.setFont("Helvetica-Bold", 14)
    pdf.drawString(28, height - 112, marker)
    pdf.setFont("Helvetica", 11)
    pdf.drawString(28, height - 132, f"Page {page_number}")

    if mode in ("text", "encrypted"):
        text = pdf.beginText(28, height - 166)
        text.setFont("Times-Roman", 11)
        for line in (
            "The quick brown fox jumps over the lazy dog.",
            "0123456789  !?@#$%  ligatures: office efficient affine",
            "Coordinates and text extraction must remain stable.",
        ):
            text.textLine(line)
        pdf.drawText(text)
        pdf.setFont("Courier", 9)
        for row in range(5):
            pdf.drawString(28, height - 230 - row * 18, f"row-{row:02d}  value={row * 17:04d}")
    elif mode == "vector":
        pdf.setLineWidth(2)
        for index, color in enumerate(("#3867D6", "#20BF6B", "#FA8231", "#EB3B5A")):
            pdf.setFillColor(HexColor(color))
            pdf.setStrokeColor(HexColor("#1E272E"))
            pdf.roundRect(30 + index * 74, height - 250, 58, 82, 8, fill=1)
        pdf.setFillColor(Color(0.2, 0.4, 0.9, alpha=0.35))
        pdf.circle(width * 0.55, height * 0.56, min(width, height) * 0.16, fill=1)
        pdf.setFillColor(Color(0.9, 0.2, 0.3, alpha=0.35))
        pdf.circle(width * 0.68, height * 0.56, min(width, height) * 0.16, fill=1)
    elif mode == "form":
        pdf.setFont("Helvetica", 10)
        pdf.drawString(28, height - 175, "Name")
        pdf.acroForm.textfield(
            name=f"name_{page_number}",
            x=28,
            y=height - 215,
            width=min(260, width - 56),
            height=26,
            borderWidth=1,
            value="OpenPDF Test User",
        )
        pdf.acroForm.checkbox(
            name=f"approved_{page_number}",
            x=28,
            y=height - 260,
            checked=True,
            buttonStyle="check",
        )
        pdf.drawString(50, height - 255, "Approved")
    elif mode == "annotation":
        pdf.setFillColor(HexColor("#3867D6"))
        pdf.drawString(28, height - 175, "Open standards reference")
        pdf.linkURL(
            "https://www.pdfa.org/resource/iso-32000-pdf/",
            (28, height - 180, min(width - 28, 260), height - 162),
            relative=0,
        )
        pdf.textAnnotation(
            "Generated note annotation for compatibility testing.",
            Rect=(28, height - 240, 52, height - 216),
            name=f"Comment_{page_number}",
        )


def create_case(output: Path, case: dict) -> None:
    raw_path = output / f".{case['id']}.raw.pdf"
    final_path = output / case["file"]
    width, height = PAGE_SIZES[case["page_size"]]
    pdf = canvas.Canvas(
        str(raw_path),
        pagesize=(width, height),
        pageCompression=1,
        invariant=1,
    )
    pdf.setTitle(f"OpenPDF corpus {case['id']}")
    pdf.setAuthor("QPdf")
    pdf.setCreator("QPdf corpus generator")
    for page_number in range(1, case["page_count"] + 1):
        draw_header(pdf, width, height, case["id"])
        draw_content(pdf, width, height, case["mode"], page_number)
        pdf.showPage()
    pdf.save()

    reader = PdfReader(raw_path)
    writer = PdfWriter()
    writer.clone_document_from_reader(reader)
    for page in writer.pages:
        if case["rotation"]:
            page.rotate(case["rotation"])
    writer.add_metadata(
        {
            "/Title": f"OpenPDF corpus {case['id']}",
            "/Author": "QPdf",
            "/Producer": "OpenPDF deterministic test corpus",
        }
    )
    if case["password"]:
        writer.encrypt(PASSWORD, algorithm="AES-256")
    with final_path.open("wb") as stream:
        writer.write(stream)
    raw_path.unlink()


def build_cases() -> list[dict]:
    cases = []
    sequence = 0
    for size_name in PAGE_SIZES:
        for rotation in ROTATIONS:
            for mode in CONTENT_MODES:
                sequence += 1
                case_id = f"case-{sequence:03d}-{size_name}-r{rotation}-{mode}"
                cases.append(
                    {
                        "id": case_id,
                        "file": f"{case_id}.pdf",
                        "page_size": size_name,
                        "rotation": rotation,
                        "mode": mode,
                        "page_count": 1 + sequence % 3,
                        "password": PASSWORD if mode == "encrypted" else None,
                        "expected_text": f"OPENPDF-CORPUS-{mode.upper()}",
                    }
                )
    return cases


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    cases = build_cases()
    for case in cases:
        create_case(output, case)
    manifest = {
        "schema_version": 1,
        "generator": "tool/generate_pdf_corpus.py",
        "case_count": len(cases),
        "cases": cases,
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Generated {len(cases)} PDFs in {output}")


if __name__ == "__main__":
    main()
