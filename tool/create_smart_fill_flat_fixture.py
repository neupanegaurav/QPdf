#!/usr/bin/env python3
"""Create a polished native flat PDF for QPdf Smart Fill acceptance."""

from pathlib import Path

from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "QPdf-Smart-Fill-Flat-Test.pdf"


def labelled_line(pdf: canvas.Canvas, label: str, y: float) -> None:
    pdf.setFont("Helvetica", 10)
    pdf.setFillColor(HexColor("#4B5563"))
    pdf.drawString(54, y + 7, label)
    pdf.setStrokeColor(HexColor("#64748B"))
    pdf.setLineWidth(0.9)
    pdf.line(180, y, 535, y)


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    width, height = A4
    pdf = canvas.Canvas(str(OUTPUT), pagesize=A4, pageCompression=1)
    pdf.setTitle("QPdf Smart Fill Flat Form Test")

    pdf.setFillColor(HexColor("#0B67F0"))
    pdf.roundRect(36, height - 118, width - 72, 76, 14, fill=1, stroke=0)
    pdf.setFillColor(HexColor("#FFFFFF"))
    pdf.setFont("Helvetica-Bold", 22)
    pdf.drawString(54, height - 78, "Service application")
    pdf.setFont("Helvetica", 10)
    pdf.drawString(54, height - 98, "Flat PDF fixture - no interactive fields are embedded")

    pdf.setFillColor(HexColor("#111827"))
    pdf.setFont("Helvetica-Bold", 13)
    pdf.drawString(54, height - 154, "Applicant details")

    labelled_line(pdf, "Full name:", height - 194)
    labelled_line(pdf, "Email address:", height - 236)
    labelled_line(pdf, "Phone number:", height - 278)
    labelled_line(pdf, "Date of birth:", height - 320)

    pdf.setFont("Helvetica-Bold", 13)
    pdf.setFillColor(HexColor("#111827"))
    pdf.drawString(54, height - 372, "Address")
    labelled_line(pdf, "Street address:", height - 412)
    labelled_line(pdf, "City:", height - 454)
    labelled_line(pdf, "Postal code:", height - 496)

    pdf.setStrokeColor(HexColor("#64748B"))
    pdf.setLineWidth(1)
    box_y = height - 550
    pdf.rect(54, box_y, 15, 15, fill=0, stroke=1)
    pdf.setFillColor(HexColor("#111827"))
    pdf.setFont("Helvetica", 10)
    pdf.drawString(79, box_y + 3, "I confirm that the information above is correct")

    pdf.setFillColor(HexColor("#6B7280"))
    pdf.setFont("Helvetica", 8)
    pdf.drawString(54, 54, "Open in QPdf, choose Fill & Sign, then Smart Fill.")
    pdf.save()
    print(OUTPUT)


if __name__ == "__main__":
    main()
