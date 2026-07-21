# QPdf Phase C4 status

Updated: 2026-07-20

## Outcome

The conditional-question and reproducible accuracy corpus through C4.3 is
implemented. It includes radio controls, repeated-row cardinality, larger
multi-page forms, Arabic/RTL, Devanagari, CJK, and dynamic screen-reader
semantics. It is ready for hands-on testing, but does not yet replace the
broader public-form and device matrix.

## Conditional behavior

- Covered groups: spouse, employment/employer, alternate mailing address, and
  dependents.
- Dependent sections accept checkbox, Yes/No radio, choice, or numeric-count
  controllers. Numeric counts are cardinality-aware: `2` shows repeated rows 1
  and 2 while hiding blank row 3. Existing values remain visible even above
  the current count.
- Unknown controller answers keep every question visible.
- Explicit negative answers hide only blank, recognized child fields.
- Existing child values are never hidden.
- Hidden fields are excluded from validation and population and are never
  cleared.
- The model cannot define controllers, children, or visibility decisions.

## Corpus

Location: `output/pdf/c4-form-corpus/`

| Fixture | Controls | Purpose |
| --- | ---: | --- |
| Identity application | 8 | Required flags, contact/address grouping, confirmation |
| Employment application | 6 | Choice-driven employer conditions and income semantics |
| Rental application | 7 | Checkbox-driven alternate mailing address |
| Healthcare intake | 6 | Date, multiline, emergency contact, required consent |
| Multilingual contact | 5 | Spanish/French visible labels with canonical field metadata |
| Dependent benefits | 8 | Two pages, required Yes/No radio, dependent fields, save/reopen |
| Arabic contact | 5 | Embedded Arabic font, shaped RTL labels, Unicode tooltips |
| Household support | 28 | Five pages, three repeated rows, spouse and employment conditions |
| Hindi contact | 5 | CoreText-shaped Devanagari labels and logical Unicode tooltips |
| Japanese contact | 5 | CJK labels and logical Unicode tooltips |

Measured result: 83/83 exact field-name, input-kind, required-flag, and section
matches (100% on this synthetic corpus). QPdf save/reopen and independent
pypdf reads pass for identity, radio/dependent, and five-page repeated-row
forms. All new blank pages and relevant filled outputs were rendered with
Poppler and visually checked. Visual QA caught and corrected the initial Arabic
glyph order, required markers, and a stale phase footer before acceptance.

The Smart Fill conditional summary is now a live accessibility region and form
section labels expose heading semantics. Automated widget tests verify both.

## Reproduce

```sh
python3 -m pip install -r tool/requirements-c4.txt
python3 tool/generate_c4_form_corpus.py
cd apps/openpdf_studio
dart run tool/verify_c4_form_corpus.dart
flutter test test/c4_form_corpus_test.dart
```

The generator uses ReportLab plus pinned Arabic reshaping and bidirectional
layout packages. Complex Devanagari/CJK display labels are shaped through the
checked-in Swift/CoreText helper while AcroForm tooltips retain logical Unicode.
Independent verification uses pypdf and Poppler. These language fixtures are
therefore generated on the supported macOS corpus host; QPdf parsing and form
logic remain cross-platform.

## Remaining C4 gates

- Add reviewed public-domain forms without redistributing restricted content.
- Replace host fonts with redistributable bundled fixture fonts when licensing
  review approves them.
- Expand beyond three fixed dependent rows to producer-specific repeated-group
  naming patterns.
- Run the corpus through physical iPhone/iPad, Windows, and Linux builds.
- Complete screen-reader and keyboard-only review of dynamic visibility.
