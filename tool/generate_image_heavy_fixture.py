#!/usr/bin/env python3
"""Generate a deterministic image-heavy PDF for render performance tests."""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path

from PIL import Image, ImageDraw
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "test_corpus" / "generated" / "image-heavy.pdf"


def page_image(page_number: int, width: int = 1600, height: int = 2200) -> bytes:
    image = Image.new("RGB", (width, height))
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            pixels[x, y] = (
                (x * 7 + y * 3 + page_number * 29) % 256,
                (x * 2 + y * 11 + page_number * 47) % 256,
                (x * 13 + y * 5 + page_number * 61) % 256,
            )
    draw = ImageDraw.Draw(image)
    for index in range(24):
        left = (index * 97 + page_number * 31) % (width - 280)
        top = (index * 131 + page_number * 43) % (height - 220)
        draw.rounded_rectangle(
            (left, top, left + 280, top + 180),
            radius=24,
            outline=(255, 255, 255),
            width=8,
        )
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=88, optimize=False, progressive=False)
    return buffer.getvalue()


def generate(output: Path, page_count: int) -> dict[str, int | str]:
    output.parent.mkdir(parents=True, exist_ok=True)
    width, height = A4
    pdf = canvas.Canvas(str(output), pagesize=A4, pageCompression=1, invariant=1)
    pdf.setTitle("QPdf image-heavy render fixture")
    pdf.setAuthor("QPdf")
    for page_number in range(1, page_count + 1):
        encoded = page_image(page_number)
        pdf.drawImage(
            ImageReader(io.BytesIO(encoded)),
            0,
            0,
            width=width,
            height=height,
            preserveAspectRatio=False,
            mask="auto",
        )
        pdf.setFillColorRGB(1, 1, 1)
        pdf.setFont("Helvetica-Bold", 18)
        pdf.drawString(24, 28, f"QPdf render fixture - page {page_number}")
        pdf.showPage()
    pdf.save()
    return {
        "file": str(output),
        "pages": page_count,
        "bytes": output.stat().st_size,
        "source_image_width": 1600,
        "source_image_height": 2200,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--pages", type=int, default=12)
    args = parser.parse_args()
    if args.pages < 1:
        parser.error("--pages must be positive")
    print(json.dumps(generate(args.output.resolve(), args.pages), indent=2))


if __name__ == "__main__":
    main()
