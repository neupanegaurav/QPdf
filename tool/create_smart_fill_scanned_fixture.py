#!/usr/bin/env python3
"""Rasterize the QPdf flat-form fixture into a true image-only PDF."""

from pathlib import Path
import subprocess
import tempfile

from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output" / "pdf" / "QPdf-Smart-Fill-Flat-Test.pdf"
OUTPUT = ROOT / "output" / "pdf" / "QPdf-Smart-Fill-Scanned-Test.pdf"


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Create the flat fixture first: {SOURCE}")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="qpdf-scanned-") as temporary:
        image_prefix = Path(temporary) / "page"
        subprocess.run(
            [
                "pdftoppm",
                "-f",
                "1",
                "-singlefile",
                "-jpeg",
                "-jpegopt",
                "quality=90",
                "-r",
                "150",
                str(SOURCE),
                str(image_prefix),
            ],
            check=True,
        )
        image_path = image_prefix.with_suffix(".jpg")
        width, height = A4
        pdf = canvas.Canvas(str(OUTPUT), pagesize=A4, pageCompression=1)
        pdf.setTitle("QPdf Smart Fill Scanned Form Test")
        pdf.drawImage(
            ImageReader(str(image_path)),
            0,
            0,
            width=width,
            height=height,
            preserveAspectRatio=False,
            mask="auto",
        )
        pdf.save()
    print(OUTPUT)


if __name__ == "__main__":
    main()
