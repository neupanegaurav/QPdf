# QPdf Phase C4.4 status

Updated: 2026-07-21

## Outcome

The first real-world form acceptance gate is implemented. QPdf now distinguishes
fully compatible AcroForms from hybrid Adobe XFA forms, gives an accessible
warning before Smart Fill on partial forms, and reports opaque producer field
names honestly instead of presenting internal hierarchy paths as labels.

## Official-source corpus

The catalog at `test_corpus/real_forms/catalog.json` pins three official-source
forms by SHA-256. The forms are downloaded into `output/pdf/c4-real-world/` for
local testing and are not packaged with QPdf. This avoids implying agency
endorsement and avoids assuming every asset on a federal website is freely
redistributable.

| Form | Category | Pages | Fillable questions | Result |
| --- | --- | ---: | ---: | --- |
| IRS W-9 | Tax | 6 | 23 | Partial: hybrid XFA and generic producer labels |
| USCIS I-9 | Employment | 4 | 128 | Full AcroForm compatibility |
| VA 10-5345 | Health authorization | 2 | 57 | Partial: hybrid XFA, semantic tooltips retained |

All three checksums match, all three documents open, every widget has a page
location, and a synthetic text value survives QPdf save/reopen in every form.
The report is written to
`output/pdf/c4-real-world/compatibility-report.json`.

## Product behavior

- XFA/hybrid forms display a prominent live-region warning that dynamic rules
  may still require Acrobat and that every page must be reviewed after saving.
- Non-XFA forms with generic producer metadata display a separate limited-label
  warning.
- Hierarchical names such as
  `topmostSubform[0].Page1[0].f1_01[0]` are shown as `Form field f1 01`.
  QPdf does not invent a semantic meaning that the producer failed to provide.
- The questionnaire uses an explicit reading-order focus traversal group for
  keyboard and assistive-technology navigation.
- A widget regression opens the pinned official W-9 and verifies the actual XFA
  warning and generic-label presentation.

## Reproduce

```sh
python3 tool/download_c4_real_forms.py
cd apps/openpdf_studio
dart run tool/verify_c4_real_forms.dart
flutter test test/c4_real_form_compatibility_test.dart
```

The downloader deliberately fails if an agency silently replaces a PDF. The
new file must be reviewed and its checksum updated intentionally.

## Remaining acceptance gates

- Expand the catalog only after source and redistribution review.
- Add conservative page-coordinate label recovery for generic XFA fallback
  fields; never guess labels without a confidence threshold and user review.
- Complete VoiceOver and TalkBack hands-on flows on physical devices.
- Complete keyboard-only traversal on Windows and Linux builds.
- Reopen filled results in current Acrobat, Preview, and PDFium viewers.
