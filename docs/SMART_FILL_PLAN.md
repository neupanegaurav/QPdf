# QPdf Smart Fill

Updated: 2026-07-21

## Product promise

When the user chooses **Fill & Sign > Smart Fill**, QPdf explains what the PDF
asks for, collects the answers in one clean questionnaire, maps them to the
document, and lets the user review before saving. Document contents and answers
stay on the device.

Smart Fill never invents identity, financial, medical, legal, or signature
data. It asks the user. It never saves, submits, shares, or signs automatically.

## Phase A — interactive PDF forms (implemented)

- Read authoritative AcroForm field names, tooltips, required/read-only flags,
  current values, checkboxes, radio groups, and choice options.
- Convert producer identifiers such as `applicant_email_1` into readable
  prompts and infer suitable email, phone, number, date, or multiline inputs.
- Present every detected field together with the message “Nothing leaves this
  device.”
- Validate required inputs and populate the matching fields only after the user
  taps **Populate fields**.
- Keep manual field-by-field filling as a fallback.
- Automated tests cover semantic classification, read-only exclusion, the full
  questionnaire interaction, and saved form persistence.

## Phase B1 — native flat forms (implemented)

- Inspect positioned PDF text and painted vector paths entirely on-device.
- Detect labelled underlines, rectangular text boxes, and square checkboxes.
- Merge labels split across multiple PDF text operators.
- Pair controls with nearby captions and assign a confidence score.
- Present editable labels and selection controls before creating anything.
- Convert approved candidates into real AcroForm fields in one committed
  editor revision, then continue into the Phase A questionnaire.
- Identify image-only pages honestly instead of guessing control coordinates.
- A polished eight-field native fixture, independent detector verifier, unit
  tests, and complete widget workflow all pass.

## Phase B2 — scanned/image forms (baseline implemented)

- Image-only pages with no positioned text now produce an explicit **Run OCR**
  recovery action; QPdf never guesses labels from unidentified pixels.
- After private OCR, QPdf renders the page locally and detects dark connected
  components representing long entry lines and square check boxes.
- Pixel rectangles are mapped back through page crop/rotation transforms into
  exact PDF user-space coordinates.
- Candidate controls are associated with nearby OCR labels, semantically
  boosted, confidence-scored, deduplicated, and rejected below the safety
  threshold.
- The existing editable review sheet is reused, so the user decides which
  candidates become real AcroForm fields before Phase A collects any answers.
- Automated fixtures cover both an OCR-labelled scan and the no-OCR refusal
  path. A polished image-only A4 device fixture is generated at
  `output/pdf/QPdf-Smart-Fill-Scanned-Test.pdf` and visually verified.

The baseline intentionally covers the common line-and-checkbox forms first.
Radio groups, signature-area classification, camera perspective correction,
and a learned compact layout model remain refinement work and must pass the
accuracy, latency, and memory gates below before replacing this deterministic
detector.

## Phase C1 — on-device semantic intelligence (implemented on Apple)

The language model is a semantic helper, not the source of field coordinates.
It receives only field names, short labels, control kinds, and required flags,
then returns guided structured output: readable label, input kind, and grouping.
Document bytes, page text, coordinates, existing values, user answers, and
signatures are excluded from the model payload.

- iOS/iPadOS 26+ and macOS 26+ use Apple's Foundation Models framework when
  the system model reports itself available. QPdf checks device eligibility,
  Apple Intelligence status, and model readiness at runtime.
- Compatible Apple results are visibly marked **On-device AI**. All platforms
  retain deterministic label humanization, input classification, and section
  grouping when a model is absent or unavailable.
- A strict Dart validation boundary requires exactly one result per known
  field, caps text lengths, rejects unknown/duplicate fields, preserves
  checkbox and choice control types, and discards incomplete output wholesale.
- The model can never provide field values or request document saving,
  submission, sharing, or signature placement. Population still occurs only
  after the existing user confirmation.
- Adversarial tests cover privacy payload minimization, incomplete responses,
  invented fields, and prohibited control-type changes. Native iOS and macOS
  builds compile successfully against the Foundation Models SDK.

## Phase C2 — portable compact model (implemented on native targets)

- Android, iOS, and macOS use `lib_llama_cpp` for private in-process CPU
  inference. Windows and Linux compile against the same Flutter boundary but
  still require CI/runtime-device acceptance on those operating systems.
- The optional model is a pinned SmolLM2-135M-Instruct Q4_K_M GGUF (Apache-2.0,
  105,454,144 bytes). QPdf never downloads it automatically. The settings
  sheet shows its size and license, asks for explicit confirmation, reports
  progress, verifies the exact byte count and SHA-256, and supports deletion.
- The compact model receives field names, short labels, and required flags
  only. It returns a strict field-name-to-label result. QPdf's deterministic
  analyzer remains authoritative for field identity, widget kind, section,
  coordinates, and all values; model output cannot weaken a detected date,
  email, checkbox, choice, or multiline field.
- Unknown, duplicated, missing, corrupt, timed-out, or structurally invalid
  output is discarded and the existing deterministic questionnaire is shown.
  Document bytes, page/OCR text, entered values, and signatures never enter the
  portable model prompt.
- A two-field end-to-end benchmark passes in 1.14 seconds on macOS and 7.89
  seconds on a Samsung SM-T860 (Android 12), including load, generation, strict
  validation, and disposal. Android now honestly requires API 28 because the
  native runtime declares that minimum.
- Web deliberately keeps deterministic analysis; no model or runtime is
  downloaded there.

## Phase C3 — quality gate and device self-test (implemented)

- The On-device AI sheet now includes **Test model**. It loads the installed
  model, runs the same two-field private probe used by integration tests,
  validates exact field identity plus authoritative DOB/date and Address
  metadata, reports pass/fail, and displays measured device latency.
- Model-proposed labels must retain semantic overlap with the original field
  name or label. Numeric/date/phone-like strings, email addresses, boolean
  answers, unknown fields, and responses that omit any input field invalidate
  the entire AI result; QPdf then uses the deterministic questionnaire.
- SmolLM2-360M-Instruct Q4_K_M was evaluated as a possible 258 MB quality tier.
  Although structurally valid and slower at 2.72 seconds on macOS, it invented
  `1990-01-01` and `0800000000` as labels. It therefore failed the semantic
  safety gate and is not offered for download.
- The retained 135M model passes the hardened self-test in 1.17 seconds on
  macOS. The Galaxy Tab passed in 37.44 seconds during a later, thermally loaded
  run versus 7.89 seconds in the earlier run; the UI exposes this variability
  instead of promising a fixed speed.
- No paired iPhone was visible during this phase. The iOS device build passes,
  but physical iPhone/iPad inference remains an explicit acceptance gate.

## Phase C4 — conditional forms and accuracy corpus (C4.3 implemented)

- Deterministic conditional rules now cover spouse, employment, alternate
  mailing, and dependent fields. Dependent controllers support checkboxes,
  Yes/No radio/choice answers, and numeric counts. A child is hidden only after
  a clearly identified controller explicitly makes it inapplicable. Unknown
  answers show everything, pre-filled children always remain visible, and
  hidden fields are never cleared or populated.
- The questionnaire updates immediately when a controlling checkbox, choice,
  or text answer changes and reports how many conditional fields are hidden.
  Visibility remains a local QPdf rule; the language model cannot control it.
- Ten blank synthetic forms were produced independently with ReportLab and the
  checked-in CoreText shaping helper. They include identity, employment,
  rental, healthcare, Spanish/French, two-page radio/dependents, Arabic/RTL,
  five-page household, Hindi, and Japanese fixtures. Together they contain 83
  AcroForm controls across text, multiline, choice, radio, checkbox, date,
  email, phone, and number semantics. No real person or organization appears.
- QPdf matches 83/83 expected field identities, input kinds, required flags,
  and sections. Filled identity, radio/dependent, and five-page repeated-row
  fixtures survive QPdf save/reopen; pypdf independently reads the expected
  values and radio states, and Poppler renders correct appearances.
- Visual review caught and corrected heading/field overlaps in the first corpus
  render. All final pages and the filled output were re-rendered and inspected
  with no clipping or overlap.
- Contact-section precedence was corrected so `email_address` and phone fields
  no longer fall into Address merely because their names contain "address".
- Visual review also caught and corrected reversed/unshaped Arabic output and
  detached required markers. The final RTL page uses an embedded Arabic font,
  explicit shaping, and bidirectional layout while preserving logical Unicode
  tooltips for QPdf extraction.
- Numeric dependent counts now control numbered repeated rows individually.
  For example, a count of two exposes rows 1 and 2 while hiding a blank row 3;
  a pre-filled row is never hidden merely because it exceeds the new count.
- The five-page household form covers 28 fields, three dependent rows, spouse
  conditions, employment conditions, and cross-page save/reopen.
  Hindi/Devanagari and Japanese/CJK fixtures preserve exact logical Unicode
  labels through QPdf parsing.
- Dynamic conditional summaries are screen-reader live regions, and question
  sections are exposed as semantic headings. Widget tests verify both flags.
- This is a reproducible safety baseline, not yet a claim of accuracy on every
  public government or commercial form. Public-domain form sampling, broader
  producer naming patterns, keyboard-only review, and physical iPhone screen
  reader acceptance remain C4 expansion gates.

## Phase C4.4 — real-world compatibility and accessible warnings (implemented)

- A download-only official-source catalog pins IRS W-9, USCIS I-9, and VA
  10-5345 by SHA-256. Agency PDFs are local acceptance inputs and are not
  packaged with QPdf or presented as endorsed samples.
- The compatibility analyzer distinguishes full AcroForm support, partial
  hybrid XFA support, and unsupported forms. It records page count, field types,
  semantic-label coverage, widget locations, and save/reopen behavior.
- USCIS I-9 passes as a 4-page, 128-question AcroForm. IRS W-9 and VA 10-5345
  preserve compatible field values but are correctly marked partial because
  they carry XFA data. W-9 exposes 23 generic producer labels and receives no
  invented semantic labels.
- Smart Fill presents partial compatibility and limited-metadata warnings as
  screen-reader live regions. Hierarchical XFA field paths are reduced to
  concise generic identifiers, and an explicit reading-order traversal group
  protects keyboard focus order.
- All three official PDFs pass checksum, open, widget-location, QPdf
  save/reopen, independent report generation, and first-page Poppler visual
  review.

## Phase C4.5 — conservative generic-label recovery (implemented)

- Generic fallback fields are paired with nearby positioned page text using
  their authoritative AcroForm widget rectangle and page index.
- Only above-widget captions, adjacent checkbox captions, and nearby captions
  for short code boxes are eligible. Instruction-like, distant, malformed,
  overly long, and sub-threshold text is rejected.
- The minimum confidence is 84%. Recovered labels expose their score and an
  editable review control; unresolved fields keep the explicit `Form field ...`
  fallback.
- Recovery never changes field identity, coordinates, control type, current
  value, or answers. It runs only for generic labels, while meaningful producer
  metadata remains untouched.
- Partial/XFA forms skip semantic-model relabelling. This ensures an AI model
  cannot override coordinate uncertainty or the partial-compatibility warning.
- The pinned W-9 recovers 21 of 23 labels, leaving two ambiguous fields generic.
  Synthetic absence-of-evidence and real-form/widget regressions protect both
  the positive and refusal paths.
- Saved W-9, I-9, and VA outputs pass QPdf reopen and Poppler visual review;
  W-9 also loads and renders through Chrome/PDFium. Preview launch succeeds,
  while full Preview interaction and Acrobat reopen remain manual gates.

## Acceptance gates

- At least 98% field-to-control mapping accuracy on well-formed AcroForms.
- Flat-form evaluation split by phone camera scans, native PDFs, handwriting,
  rotation, multiple languages, and accessibility labels.
- Zero values populated without confirmation; zero signature placements by AI.
- No document bytes, OCR text, or answers transmitted during offline mode.
- Peak memory and latency budgets measured on lower-end supported phones.
- Saved output reopened in Acrobat, Preview, Chrome/PDFium, and Poppler.
