#!/usr/bin/env python3
"""Generate privacy-safe, independent AcroForm fixtures for QPdf Phase C4."""

from __future__ import annotations

import json
from pathlib import Path

import arabic_reshaper
from bidi.algorithm import get_display
import hashlib
import shutil
import subprocess
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "c4-form-corpus"
PAGE_W, PAGE_H = A4

BLUE = HexColor("#246BFD")
INK = HexColor("#172033")
MUTED = HexColor("#667085")
LINE = HexColor("#D0D5DD")
SURFACE = HexColor("#F7F9FC")
ARABIC_FONT = Path("/System/Library/Fonts/SFArabic.ttf")
NATIVE_LABEL_TOOL = ROOT / "tool" / "render_native_label.swift"
NATIVE_LABEL_TMP = ROOT / "tmp" / "pdfs" / "c4-3-labels"


def rtl(text: str) -> str:
    """Shape Arabic and convert logical order to renderer-safe visual order."""
    return get_display(arabic_reshaper.reshape(text))


FORMS = [
    {
        "file": "01-identity-application.pdf",
        "title": "Identity application",
        "subtitle": "Synthetic benchmark - no personal information",
        "sections": [
            (
                "Personal details",
                [
                    ("text", "full_name", "Full name", True),
                    ("text", "date_of_birth", "Date of birth", True),
                    ("text", "email_address", "Email address", False),
                    ("text", "phone_number", "Phone number", False),
                ],
            ),
            (
                "Address",
                [
                    ("text", "residential_address", "Residential address", True),
                    ("text", "city", "City", True),
                    ("text", "postcode", "Postcode", True),
                    ("check", "confirm_details", "I confirm these details are correct", True),
                ],
            ),
        ],
    },
    {
        "file": "02-employment-application.pdf",
        "title": "Employment application",
        "subtitle": "Conditional employer fields benchmark",
        "sections": [
            (
                "Applicant",
                [("text", "applicant_name", "Applicant name", True)],
            ),
            (
                "Employment and income",
                [
                    (
                        "choice",
                        "employment_status",
                        "Employment status",
                        True,
                        ["Unemployed", "Employed", "Self employed"],
                    ),
                    ("text", "employer_name", "Employer name", False),
                    ("text", "occupation", "Occupation", False),
                    ("text", "annual_income", "Annual income", False),
                    ("text", "work_phone", "Work phone", False),
                ],
            ),
        ],
    },
    {
        "file": "03-rental-application.pdf",
        "title": "Rental application",
        "subtitle": "Alternate mailing address benchmark",
        "sections": [
            (
                "Applicant",
                [
                    ("text", "applicant_name", "Applicant name", True),
                    ("text", "number_of_occupants", "Number of occupants", True),
                    ("check", "has_pets", "Will pets live at the property?", False),
                ],
            ),
            (
                "Mailing address",
                [
                    (
                        "check",
                        "different_mailing_address",
                        "Use a different mailing address",
                        False,
                    ),
                    ("text", "mailing_address", "Mailing address", False),
                    ("text", "mailing_city", "Mailing city", False),
                    ("text", "mailing_postcode", "Mailing postcode", False),
                ],
            ),
        ],
    },
    {
        "file": "04-healthcare-intake.pdf",
        "title": "Healthcare intake",
        "subtitle": "Blank synthetic form - not for clinical use",
        "sections": [
            (
                "Patient",
                [
                    ("text", "patient_name", "Patient name", True),
                    ("text", "patient_dob", "Date of birth", True),
                    ("text", "allergies", "Allergies or sensitivities", False, "multiline"),
                ],
            ),
            (
                "Emergency contact",
                [
                    ("text", "emergency_contact_name", "Emergency contact name", True),
                    ("text", "emergency_contact_tel", "Emergency contact telephone", True),
                    ("check", "treatment_consent", "I consent to the information above", True),
                ],
            ),
        ],
    },
    {
        "file": "05-multilingual-contact.pdf",
        "title": "Formulario de contacto / Formulaire de contact",
        "subtitle": "Spanish and French label benchmark",
        "sections": [
            (
                "Datos / Coordonnees",
                [
                    ("text", "full_name", "Nombre completo", True),
                    ("text", "email_address", "Correo electronico", True),
                    ("text", "phone_number", "Telephone", False),
                    ("text", "postcode", "Code postal", False),
                    ("check", "accept_terms", "Acepto las condiciones", True),
                ],
            ),
        ],
    },
]


def field_manifest(spec: tuple, section: str) -> dict:
    kind, name, label, required, *extra = spec
    inferred = "checkBox" if kind == "check" else "choice" if kind == "choice" else "text"
    searchable = f"{name} {label}".lower()
    if kind == "text":
        if extra and extra[0] == "multiline":
            inferred = "multiline"
        elif "email" in searchable:
            inferred = "email"
        elif any(value in searchable for value in ("phone", "telephone", "tel")):
            inferred = "phone"
        elif any(value in searchable for value in ("date", "dob", "birth")):
            inferred = "date"
        elif any(value in searchable for value in ("number", "income", "amount")):
            inferred = "number"
    expected_section = "Personal details"
    if any(value in searchable for value in ("consent", "confirm", "terms")):
        expected_section = "Declarations"
    elif any(value in searchable for value in ("employer", "employment", "occupation", "income", "job title", "work phone")):
        expected_section = "Employment and income"
    elif any(value in searchable for value in ("email", "phone", "mobile", "telephone", " tel")):
        expected_section = "Contact details"
    elif any(value in searchable for value in ("address", "city", "postcode", "postal")):
        expected_section = "Address"
    return {
        "name": name,
        "label": label,
        "kind": inferred,
        "required": required,
        "expectedSection": expected_section,
        "visualSection": section,
    }


def draw_form(form: dict) -> list[dict]:
    path = OUTPUT / form["file"]
    pdf = canvas.Canvas(str(path), pagesize=A4, pageCompression=1)
    pdf.setTitle(f"QPdf C4 - {form['title']}")
    pdf.setAuthor("QPdf synthetic benchmark")

    pdf.setFillColor(SURFACE)
    pdf.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    pdf.setFillColor(BLUE)
    pdf.roundRect(36, PAGE_H - 112, PAGE_W - 72, 76, 16, fill=1, stroke=0)
    pdf.setFillColor(white)
    pdf.setFont("Helvetica-Bold", 20)
    pdf.drawString(56, PAGE_H - 72, form["title"])
    pdf.setFont("Helvetica", 9)
    pdf.drawString(56, PAGE_H - 92, form["subtitle"])

    y = PAGE_H - 150
    manifest_fields = []
    for section, fields in form["sections"]:
        pdf.setFillColor(INK)
        pdf.setFont("Helvetica-Bold", 12)
        pdf.drawString(48, y, section)
        y -= 42
        for spec in fields:
            kind, name, label, required, *extra = spec
            manifest_fields.append(field_manifest(spec, section))
            pdf.setFillColor(INK)
            pdf.setFont("Helvetica", 9)
            label_y = y + (25 if kind == "check" else 34)
            pdf.drawString(52, label_y, f"{label}{' *' if required else ''}")
            flags = "required" if required else ""
            if kind == "check":
                pdf.acroForm.checkbox(
                    name=name,
                    tooltip=label,
                    x=52,
                    y=y,
                    size=17,
                    buttonStyle="check",
                    borderWidth=1,
                    borderColor=LINE,
                    fillColor=white,
                    textColor=BLUE,
                    fieldFlags=flags,
                    forceBorder=True,
                )
                pdf.setFillColor(MUTED)
                pdf.setFont("Helvetica", 8)
                pdf.drawString(77, y + 5, "Select when applicable")
                y -= 48
            elif kind == "choice":
                options = extra[0]
                pdf.acroForm.choice(
                    name=name,
                    tooltip=label,
                    value=options[0],
                    options=options,
                    x=52,
                    y=y,
                    width=PAGE_W - 104,
                    height=24,
                    borderWidth=1,
                    borderColor=LINE,
                    fillColor=white,
                    textColor=INK,
                    fieldFlags=flags,
                    forceBorder=True,
                )
                y -= 55
            else:
                multiline = bool(extra and extra[0] == "multiline")
                field_flags = "multiline" if multiline else flags
                if multiline and required:
                    field_flags = "multiline required"
                height = 58 if multiline else 26
                pdf.acroForm.textfield(
                    name=name,
                    tooltip=label,
                    x=52,
                    y=y - (height - 26),
                    width=PAGE_W - 104,
                    height=height,
                    borderWidth=1,
                    borderColor=LINE,
                    fillColor=white,
                    textColor=INK,
                    fontName="Helvetica",
                    fontSize=10,
                    fieldFlags=field_flags,
                    forceBorder=True,
                )
                y -= 87 if multiline else 57
        y -= 4

    pdf.setFillColor(MUTED)
    pdf.setFont("Helvetica", 8)
    pdf.drawString(48, 30, "QPdf Phase C4 synthetic fixture - blank by design")
    pdf.drawRightString(PAGE_W - 48, 30, "Review before saving")
    pdf.save()
    return manifest_fields


def draw_page_chrome(
    pdf: canvas.Canvas,
    title: str,
    subtitle: str,
    page: int,
    total_pages: int = 2,
    phase: str = "C4.2",
) -> None:
    pdf.setFillColor(SURFACE)
    pdf.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    pdf.setFillColor(BLUE)
    pdf.roundRect(36, PAGE_H - 112, PAGE_W - 72, 76, 16, fill=1, stroke=0)
    pdf.setFillColor(white)
    pdf.setFont("Helvetica-Bold", 20)
    pdf.drawString(56, PAGE_H - 72, title)
    pdf.setFont("Helvetica", 9)
    pdf.drawString(56, PAGE_H - 92, subtitle)
    pdf.setFillColor(MUTED)
    pdf.setFont("Helvetica", 8)
    pdf.drawString(48, 30, f"QPdf Phase {phase} synthetic fixture - blank by design")
    pdf.drawRightString(PAGE_W - 48, 30, f"Page {page} of {total_pages}")


def draw_native_label(
    pdf: canvas.Canvas,
    *,
    text: str,
    x: float,
    y: float,
    width: float,
    height: float = 24,
    font: str,
    size: float = 10,
    alignment: str = "left",
) -> None:
    """Render complex scripts through macOS CoreText, then embed the result."""
    NATIVE_LABEL_TMP.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha1(
        f"{font}|{size}|{alignment}|{text}".encode("utf-8")
    ).hexdigest()
    image_path = NATIVE_LABEL_TMP / f"{digest}.png"
    if not image_path.exists():
        subprocess.run(
            [
                "/usr/bin/swift",
                str(NATIVE_LABEL_TOOL),
                str(image_path),
                str(round(width)),
                str(round(height)),
                font,
                str(size),
                text,
                alignment,
            ],
            check=True,
        )
    pdf.drawImage(
        ImageReader(str(image_path)),
        x,
        y,
        width=width,
        height=height,
        preserveAspectRatio=False,
        mask="auto",
    )


def draw_text_field(
    pdf: canvas.Canvas,
    *,
    name: str,
    label: str,
    y: float,
    required: bool = False,
    x: float = 52,
    width: float | None = None,
) -> None:
    width = width if width is not None else PAGE_W - 104
    pdf.setFillColor(INK)
    pdf.setFont("Helvetica", 9)
    pdf.drawString(x, y + 34, f"{label}{' *' if required else ''}")
    pdf.acroForm.textfield(
        name=name,
        tooltip=label,
        x=x,
        y=y,
        width=width,
        height=26,
        borderWidth=1,
        borderColor=LINE,
        fillColor=white,
        textColor=INK,
        fontName="Helvetica",
        fontSize=10,
        fieldFlags="required" if required else "",
        forceBorder=True,
    )


def draw_choice_field(
    pdf: canvas.Canvas,
    *,
    name: str,
    label: str,
    options: list[str],
    y: float,
    required: bool = False,
    x: float = 52,
    width: float | None = None,
) -> None:
    width = width if width is not None else PAGE_W - 104
    pdf.setFillColor(INK)
    pdf.setFont("Helvetica", 9)
    pdf.drawString(x, y + 34, f"{label}{' *' if required else ''}")
    pdf.acroForm.choice(
        name=name,
        tooltip=label,
        value=options[0],
        options=options,
        x=x,
        y=y,
        width=width,
        height=26,
        borderWidth=1,
        borderColor=LINE,
        fillColor=white,
        textColor=INK,
        fieldFlags="required" if required else "",
        forceBorder=True,
    )


def draw_check_field(
    pdf: canvas.Canvas,
    *,
    name: str,
    label: str,
    y: float,
    required: bool = False,
) -> None:
    pdf.setFillColor(INK)
    pdf.setFont("Helvetica", 9)
    pdf.drawString(78, y + 5, f"{label}{' *' if required else ''}")
    pdf.acroForm.checkbox(
        name=name,
        tooltip=label,
        x=52,
        y=y,
        size=17,
        buttonStyle="check",
        borderWidth=1,
        borderColor=LINE,
        fillColor=white,
        textColor=BLUE,
        fieldFlags="required" if required else "",
        forceBorder=True,
    )


def draw_multipage_radio_form() -> tuple[str, list[dict]]:
    file_name = "06-dependent-benefits-multipage.pdf"
    pdf = canvas.Canvas(str(OUTPUT / file_name), pagesize=A4, pageCompression=1)
    pdf.setTitle("QPdf C4.2 - Dependent benefits application")
    pdf.setAuthor("QPdf synthetic benchmark")
    fields = [
        field_manifest(("text", "applicant_name", "Applicant name", True), "Applicant"),
        field_manifest(("choice", "has_dependents", "Do you have dependents?", True, ["Yes", "No"]), "Dependents"),
        field_manifest(("text", "dependent_full_name", "Dependent full name", False), "Dependents"),
        field_manifest(("text", "dependent_date_of_birth", "Dependent date of birth", False), "Dependents"),
        field_manifest(("text", "email_address", "Email address", True), "Contact"),
        field_manifest(("text", "phone_number", "Phone number", False), "Contact"),
        field_manifest(("text", "benefit_reference", "Benefit reference", False), "Application"),
        field_manifest(("check", "confirm_application", "I confirm this application is correct", True), "Declaration"),
    ]

    draw_page_chrome(
        pdf,
        "Dependent benefits application",
        "Two-page radio and conditional-field benchmark",
        1,
    )
    pdf.setFillColor(INK)
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(48, PAGE_H - 150, "Applicant and dependents")
    draw_text_field(pdf, name="applicant_name", label="Applicant name", y=PAGE_H - 222, required=True)
    pdf.setFont("Helvetica", 9)
    pdf.drawString(52, PAGE_H - 266, "Do you have dependents? *")
    for x, value in ((52, "Yes"), (148, "No")):
        pdf.acroForm.radio(
            name="has_dependents",
            value=value,
            selected=value == "No",
            tooltip="Do you have dependents?",
            x=x,
            y=PAGE_H - 298,
            size=18,
            buttonStyle="circle",
            borderWidth=1,
            borderColor=LINE,
            fillColor=white,
            textColor=BLUE,
            forceBorder=True,
        )
        pdf.setFillColor(MUTED)
        pdf.drawString(x + 25, PAGE_H - 292, value)
    draw_text_field(pdf, name="dependent_full_name", label="Dependent full name", y=PAGE_H - 365)
    draw_text_field(pdf, name="dependent_date_of_birth", label="Dependent date of birth", y=PAGE_H - 430)
    pdf.showPage()

    draw_page_chrome(
        pdf,
        "Dependent benefits application",
        "Contact and declaration",
        2,
    )
    pdf.setFillColor(INK)
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(48, PAGE_H - 150, "Contact details")
    draw_text_field(pdf, name="email_address", label="Email address", y=PAGE_H - 222, required=True)
    draw_text_field(pdf, name="phone_number", label="Phone number", y=PAGE_H - 287)
    draw_text_field(pdf, name="benefit_reference", label="Benefit reference", y=PAGE_H - 352)
    pdf.setFont("Helvetica", 9)
    pdf.drawString(52, PAGE_H - 397, "I confirm this application is correct *")
    pdf.acroForm.checkbox(
        name="confirm_application",
        tooltip="I confirm this application is correct",
        x=52,
        y=PAGE_H - 430,
        size=17,
        buttonStyle="check",
        borderWidth=1,
        borderColor=LINE,
        fillColor=white,
        textColor=BLUE,
        fieldFlags="required",
        forceBorder=True,
    )
    pdf.save()
    return file_name, fields


def draw_arabic_form() -> tuple[str, list[dict]]:
    if not ARABIC_FONT.exists():
        raise FileNotFoundError(f"Arabic test font not found: {ARABIC_FONT}")
    pdfmetrics.registerFont(TTFont("QPdfArabic", str(ARABIC_FONT), shapable=True))
    file_name = "07-arabic-contact.pdf"
    pdf = canvas.Canvas(str(OUTPUT / file_name), pagesize=A4, pageCompression=1)
    pdf.setTitle("QPdf C4.2 - Arabic contact form")
    pdf.setAuthor("QPdf synthetic benchmark")
    labels = [
        ("full_name", "الاسم الكامل", True),
        ("email_address", "البريد الإلكتروني", True),
        ("phone_number", "رقم الهاتف", False),
        ("postcode", "الرمز البريدي", False),
    ]
    fields = [
        field_manifest(("text", name, label, required), "بيانات الاتصال")
        for name, label, required in labels
    ]
    fields.append(
        field_manifest(("check", "accept_terms", "أوافق على الشروط", True), "الإقرار")
    )

    pdf.setFillColor(SURFACE)
    pdf.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    pdf.setFillColor(BLUE)
    pdf.roundRect(36, PAGE_H - 112, PAGE_W - 72, 76, 16, fill=1, stroke=0)
    pdf.setFillColor(white)
    pdf.setFont("QPdfArabic", 20)
    pdf.drawRightString(PAGE_W - 56, PAGE_H - 72, rtl("نموذج بيانات الاتصال"))
    pdf.setFont("QPdfArabic", 9)
    pdf.drawRightString(
        PAGE_W - 56,
        PAGE_H - 92,
        rtl("نموذج تجريبي آمن بلا بيانات شخصية"),
    )
    y = PAGE_H - 190
    for name, label, required in labels:
        pdf.setFillColor(INK)
        pdf.setFont("QPdfArabic", 10)
        visual_label = rtl(label)
        pdf.drawRightString(PAGE_W - 52, y + 34, visual_label)
        if required:
            pdf.setFillColor(BLUE)
            pdf.setFont("Helvetica-Bold", 9)
            label_width = pdfmetrics.stringWidth(
                visual_label,
                "QPdfArabic",
                10,
            )
            pdf.drawString(PAGE_W - 60 - label_width, y + 34, "*")
        pdf.acroForm.textfield(
            name=name,
            tooltip=label,
            x=52,
            y=y,
            width=PAGE_W - 104,
            height=26,
            borderWidth=1,
            borderColor=LINE,
            fillColor=white,
            textColor=INK,
            fontName="Helvetica",
            fontSize=10,
            fieldFlags="required" if required else "",
            forceBorder=True,
        )
        y -= 65
    pdf.setFillColor(INK)
    pdf.setFont("QPdfArabic", 10)
    terms_label = rtl("أوافق على الشروط")
    pdf.drawRightString(PAGE_W - 80, y + 6, terms_label)
    pdf.setFillColor(BLUE)
    pdf.setFont("Helvetica-Bold", 9)
    terms_width = pdfmetrics.stringWidth(terms_label, "QPdfArabic", 10)
    pdf.drawString(PAGE_W - 88 - terms_width, y + 6, "*")
    pdf.acroForm.checkbox(
        name="accept_terms",
        tooltip="أوافق على الشروط",
        x=PAGE_W - 70,
        y=y,
        size=17,
        buttonStyle="check",
        borderWidth=1,
        borderColor=LINE,
        fillColor=white,
        textColor=BLUE,
        fieldFlags="required",
        forceBorder=True,
    )
    pdf.setFillColor(MUTED)
    pdf.setFont("Helvetica", 8)
    pdf.drawString(48, 30, "QPdf Phase C4.2 Arabic/RTL synthetic fixture")
    pdf.save()
    return file_name, fields


def draw_large_household_form() -> tuple[str, list[dict]]:
    file_name = "08-household-support-five-page.pdf"
    pdf = canvas.Canvas(str(OUTPUT / file_name), pagesize=A4, pageCompression=1)
    pdf.setTitle("QPdf C4.3 - Household support application")
    pdf.setAuthor("QPdf synthetic benchmark")
    sections = [
        ("Applicant", [
            ("text", "applicant_full_name", "Applicant full name", True),
            ("text", "date_of_birth", "Date of birth", True),
            ("choice", "marital_status", "Marital status", True, ["Single", "Married", "Partnered"]),
            ("text", "spouse_full_name", "Spouse full name", False),
        ]),
        ("Contact and address", [
            ("text", "residential_address", "Residential address", True),
            ("text", "city", "City", True),
            ("text", "postcode", "Postcode", True),
            ("text", "email_address", "Email address", True),
            ("text", "phone_number", "Phone number", False),
        ]),
        ("Dependents", [
            ("text", "number_of_dependents", "Number of dependents", True),
            *[
                spec
                for index in range(1, 4)
                for spec in (
                    ("text", f"dependent_{index}_full_name", f"Dependent {index} full name", False),
                    ("text", f"dependent_{index}_date_of_birth", f"Dependent {index} date of birth", False),
                    ("text", f"dependent_{index}_relationship", f"Dependent {index} relationship", False),
                )
            ],
        ]),
        ("Employment and income", [
            ("choice", "employment_status", "Employment status", True, ["Unemployed", "Employed", "Self employed"]),
            ("text", "employer_name", "Employer name", False),
            ("text", "occupation", "Occupation", False),
            ("text", "annual_income", "Annual income", False),
            ("text", "work_phone", "Work phone", False),
        ]),
        ("Application details", [
            ("choice", "payment_method", "Preferred payment method", True, ["Bank transfer", "Cheque"]),
            ("text", "bank_reference", "Bank reference", False),
            ("text", "additional_notes", "Additional notes", False),
            ("check", "confirm_application", "I confirm this application is correct", True),
        ]),
    ]
    fields = [
        field_manifest(spec, section)
        for section, specs in sections
        for spec in specs
    ]

    def page(page_number: int, subtitle: str, heading: str) -> None:
        draw_page_chrome(
            pdf,
            "Household support application",
            subtitle,
            page_number,
            total_pages=5,
            phase="C4.3",
        )
        pdf.setFillColor(INK)
        pdf.setFont("Helvetica-Bold", 12)
        pdf.drawString(48, PAGE_H - 150, heading)

    page(1, "Applicant identity and household status", "Applicant")
    draw_text_field(pdf, name="applicant_full_name", label="Applicant full name", y=PAGE_H - 222, required=True)
    draw_text_field(pdf, name="date_of_birth", label="Date of birth", y=PAGE_H - 287, required=True)
    draw_choice_field(pdf, name="marital_status", label="Marital status", options=["Single", "Married", "Partnered"], y=PAGE_H - 352, required=True)
    draw_text_field(pdf, name="spouse_full_name", label="Spouse full name", y=PAGE_H - 417)
    pdf.showPage()

    page(2, "Address and contact details", "Contact and address")
    for y, name, label, required in (
        (PAGE_H - 222, "residential_address", "Residential address", True),
        (PAGE_H - 287, "city", "City", True),
        (PAGE_H - 352, "postcode", "Postcode", True),
        (PAGE_H - 417, "email_address", "Email address", True),
        (PAGE_H - 482, "phone_number", "Phone number", False),
    ):
        draw_text_field(pdf, name=name, label=label, y=y, required=required)
    pdf.showPage()

    page(3, "Dependent count controls repeated rows", "Dependents 1 and 2")
    draw_text_field(pdf, name="number_of_dependents", label="Number of dependents", y=PAGE_H - 222, required=True)
    for index, top in ((1, PAGE_H - 310), (2, PAGE_H - 505)):
        pdf.setFillColor(BLUE)
        pdf.setFont("Helvetica-Bold", 10)
        pdf.drawString(52, top + 28, f"Dependent {index}")
        draw_text_field(pdf, name=f"dependent_{index}_full_name", label="Full name", y=top - 35)
        half = (PAGE_W - 116) / 2
        draw_text_field(pdf, name=f"dependent_{index}_date_of_birth", label="Date of birth", y=top - 100, width=half)
        draw_text_field(pdf, name=f"dependent_{index}_relationship", label="Relationship", y=top - 100, x=58 + half, width=half)
    pdf.showPage()

    page(4, "Third dependent and employment", "Dependent 3")
    draw_text_field(pdf, name="dependent_3_full_name", label="Dependent 3 full name", y=PAGE_H - 222)
    half = (PAGE_W - 116) / 2
    draw_text_field(pdf, name="dependent_3_date_of_birth", label="Dependent 3 date of birth", y=PAGE_H - 287, width=half)
    draw_text_field(pdf, name="dependent_3_relationship", label="Dependent 3 relationship", y=PAGE_H - 287, x=58 + half, width=half)
    pdf.setFillColor(INK)
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(48, PAGE_H - 350, "Employment and income")
    draw_choice_field(pdf, name="employment_status", label="Employment status", options=["Unemployed", "Employed", "Self employed"], y=PAGE_H - 417, required=True)
    draw_text_field(pdf, name="employer_name", label="Employer name", y=PAGE_H - 482)
    draw_text_field(pdf, name="occupation", label="Occupation", y=PAGE_H - 547)
    draw_text_field(pdf, name="annual_income", label="Annual income", y=PAGE_H - 612)
    draw_text_field(pdf, name="work_phone", label="Work phone", y=PAGE_H - 677)
    pdf.showPage()

    page(5, "Payment preference and declaration", "Application details")
    draw_choice_field(pdf, name="payment_method", label="Preferred payment method", options=["Bank transfer", "Cheque"], y=PAGE_H - 222, required=True)
    draw_text_field(pdf, name="bank_reference", label="Bank reference", y=PAGE_H - 287)
    draw_text_field(pdf, name="additional_notes", label="Additional notes", y=PAGE_H - 352)
    draw_check_field(pdf, name="confirm_application", label="I confirm this application is correct", y=PAGE_H - 420, required=True)
    pdf.save()
    return file_name, fields


def draw_complex_script_form(
    *,
    file_name: str,
    title: str,
    subtitle: str,
    font: str,
    labels: list[tuple[str, str, bool]],
) -> tuple[str, list[dict]]:
    pdf = canvas.Canvas(str(OUTPUT / file_name), pagesize=A4, pageCompression=1)
    pdf.setTitle(f"QPdf C4.3 - {title}")
    pdf.setAuthor("QPdf synthetic benchmark")
    fields = [
        field_manifest(("check" if name == "accept_terms" else "text", name, label, required), title)
        for name, label, required in labels
    ]
    pdf.setFillColor(SURFACE)
    pdf.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    pdf.setFillColor(BLUE)
    pdf.roundRect(36, PAGE_H - 112, PAGE_W - 72, 76, 16, fill=1, stroke=0)
    pdf.setFillColor(white)
    pdf.setFont("Helvetica-Bold", 20)
    pdf.drawString(56, PAGE_H - 72, title)
    pdf.setFont("Helvetica", 9)
    pdf.drawString(56, PAGE_H - 92, subtitle)
    y = PAGE_H - 190
    for name, label, required in labels:
        if name == "accept_terms":
            draw_native_label(pdf, text=label, x=82, y=y - 2, width=PAGE_W - 134, font=font, size=11)
            pdf.acroForm.checkbox(
                name=name,
                tooltip=label,
                x=52,
                y=y,
                size=17,
                buttonStyle="check",
                borderWidth=1,
                borderColor=LINE,
                fillColor=white,
                textColor=BLUE,
                fieldFlags="required" if required else "",
                forceBorder=True,
            )
            break
        draw_native_label(pdf, text=label, x=52, y=y + 29, width=PAGE_W - 104, font=font, size=11)
        if required:
            pdf.setFillColor(BLUE)
            pdf.circle(43, y + 40, 2, fill=1, stroke=0)
        pdf.acroForm.textfield(
            name=name,
            tooltip=label,
            x=52,
            y=y,
            width=PAGE_W - 104,
            height=26,
            borderWidth=1,
            borderColor=LINE,
            fillColor=white,
            textColor=INK,
            fontName="Helvetica",
            fontSize=10,
            fieldFlags="required" if required else "",
            forceBorder=True,
        )
        y -= 65
    pdf.setFillColor(MUTED)
    pdf.setFont("Helvetica", 8)
    pdf.drawString(48, 30, "QPdf Phase C4.3 complex-script synthetic fixture")
    pdf.save()
    return file_name, fields


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "version": 1,
        "privacy": "Synthetic blank forms only. No real people or organizations.",
        "forms": [],
    }
    for form in FORMS:
        fields = draw_form(form)
        manifest["forms"].append({"file": form["file"], "fields": fields})
    c43_forms = (
        draw_multipage_radio_form(),
        draw_arabic_form(),
        draw_large_household_form(),
        draw_complex_script_form(
            file_name="09-hindi-contact.pdf",
            title="Hindi contact form",
            subtitle="Devanagari Unicode metadata benchmark",
            font="Devanagari Sangam MN",
            labels=[
                ("full_name", "पूरा नाम", True),
                ("email_address", "ईमेल पता", True),
                ("phone_number", "फ़ोन नंबर", False),
                ("city", "शहर", False),
                ("accept_terms", "मैं शर्तें स्वीकार करता हूँ", True),
            ],
        ),
        draw_complex_script_form(
            file_name="10-japanese-contact.pdf",
            title="Japanese contact form",
            subtitle="CJK Unicode metadata benchmark",
            font="Hiragino Sans GB",
            labels=[
                ("full_name", "氏名", True),
                ("email_address", "メールアドレス", True),
                ("phone_number", "電話番号", False),
                ("city", "市区町村", False),
                ("accept_terms", "利用規約に同意します", True),
            ],
        ),
    )
    for file_name, fields in c43_forms:
        manifest["forms"].append({"file": file_name, "fields": fields})
    (OUTPUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )
    if NATIVE_LABEL_TMP.exists():
        shutil.rmtree(NATIVE_LABEL_TMP)
    print(f"Generated {len(manifest['forms'])} forms in {OUTPUT}")


if __name__ == "__main__":
    main()
