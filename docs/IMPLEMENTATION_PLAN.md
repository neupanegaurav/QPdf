# QPdf - Product and Implementation Plan

## 1. Product definition

Build a single Flutter application that feels native on phone, tablet, and desktop. It should work offline by default and share most UI, document state, commands, tests, and business rules across platforms.

"Acrobat-like" should mean familiar workflows and broad PDF compatibility, not a pixel-for-pixel clone or an immediate promise of every Acrobat feature. The first release should be excellent at common jobs:

- open large and password-protected PDFs;
- search, select, copy, print, and share;
- annotate with text markup, ink, shapes, notes, stamps, and images;
- fill and save AcroForms;
- reorder, rotate, insert, delete, extract, split, and merge pages;
- create a drawn signature and place it visibly;
- save safely without corrupting the source;
- undo and redo every edit;
- work without an account or upload.

The advanced product can add true redaction, OCR, scanning, content editing, cryptographic signatures, comparison, accessibility tools, PDF/A, and preflight.

## 2. Scope boundary

### Launch scope (Reader + Editor)

| Area | Launch capabilities | Later capabilities |
| --- | --- | --- |
| Reader | thumbnails, outline, links, search, selection, zoom, continuous/single/two-page modes, recent files | read aloud, liquid/reflow view, shared review |
| Annotation | highlight, underline, strikeout, ink, shapes, free text, notes, stamps, image, undo/redo | audio/video annotations, measurement calibration, custom tool sets |
| Forms | fill text, checkbox, radio, combo/list; reset; flatten copy | form field authoring, calculations, JavaScript actions, XFA strategy |
| Pages | reorder, rotate, insert, delete, duplicate, crop, extract, split, merge | headers/footers, Bates numbering, page labels, background templates |
| Signing | saved drawn signature/initials; visible date/name fields | certificate signing, signature validation, timestamps, LTV, trust store |
| Security | password open; encrypted save; permission display; safe temporary files | certificate encryption, enterprise policy, information protection |
| Export | save/save-as, print, share, flatten copy, images-to-PDF | PDF/A, PDF/X, optimized PDF, preflight and repair reports |
| Scan/OCR | camera scan and basic on-device OCR in phase 2 | deskew/dewarp tuning, handwriting, table extraction, multilingual packs |
| Content edit | add new text/images in phase 2 | edit existing text/images, font substitution, paragraph reflow |
| Redaction | mark areas in phase 1; true apply-redaction in phase 2 | pattern detection and bulk redaction |

### Explicit non-goals for version 1

- XFA form authoring or full XFA runtime compatibility;
- Illustrator-style vector editing;
- exact Word-like paragraph reflow for arbitrary PDFs;
- enterprise certificate authority, qualified e-signature, or legal identity service;
- cloud collaboration, unless separately funded and designed;
- perfect repair of every malformed PDF found in the wild.

## 3. Architecture decision

### Use Flutter for product UI, not as the PDF engine

Flutter should own:

- adaptive phone/tablet/desktop UI;
- toolbars, panels, shortcuts, command palette, dialogs, themes, and localization;
- document session state and command history;
- annotation interaction overlays and selection handles;
- feature flags, preferences, telemetry consent, and update UX;
- platform-neutral tests.

A PDF engine layer should own:

- parsing and rendering;
- text geometry and hit testing;
- annotations and appearance streams;
- form fields;
- page-object and document transformations;
- incremental and compact saves;
- encryption, signatures, sanitization, and validation.

Keep the boundary behind a Dart interface from day one:

```dart
abstract interface class PdfEngine {
  Future<PdfDocumentHandle> open(PdfSource source, {String? password});
  Stream<PdfTile> renderTiles(PdfRenderRequest request);
  Future<PdfTextPage> extractText(PdfPageRef page);
  Future<PdfRevision> apply(PdfCommand command);
  Future<PdfValidationReport> validate();
  Future<Uint8List> save(PdfSaveOptions options);
  Future<void> close();
}
```

No screen should call PDFium, a pub package, or a native platform API directly.

### Recommended engine strategy

Use a two-stage decision rather than committing blindly:

1. **Prototype adapter:** evaluate `dart_pdf_editor` for a rapid vertical slice. It currently advertises all Flutter targets, annotations, forms, page editing, redaction, OCR integration, and PAdES signing under Apache-2.0. It is very new and must pass our corpus, performance, security, maintenance, and fuzz tests before product dependence.
2. **Production fallback/companion:** maintain a `pdf_engine_pdfium` adapter for rendering, text geometry, forms, and broad compatibility. Use a structure-preserving library such as qpdf for merge/split/encryption/linearization and implement missing high-level edit operations in a controlled native core.

Do not use MuPDF in a closed-source distributed app without either complying with AGPL or buying a commercial license.

Do not build the main product on Apple PDFKit or Android PdfRenderer alone. Their features and minimum OS behavior differ, which would make documents behave differently by platform. They remain useful for OS integration and as rendering oracles in tests.

### Proposed repository layout

```text
apps/openpdf_studio/             Flutter application
packages/pdf_domain/             immutable models, commands, errors
packages/pdf_engine_api/         Dart engine contract
packages/pdf_engine_dart/        evaluated pure-Dart adapter
packages/pdf_engine_native/      FFI/native production adapter
packages/editor_ui/              adaptive editor widgets
packages/design_system/          tokens and reusable controls
packages/platform_services/      file picker, print, share, camera, keychain
native/pdf_core/                 C/C++ or Rust facade over chosen libraries
test_corpus/                     licensed/generated PDFs and expected results
tool/                            build, corpus, render-diff, fuzz, release tools
docs/                            decisions, threat model, specifications
```

### Document session model

All mutations are commands, not arbitrary widget state:

```text
Open bytes -> immutable base revision -> command log -> preview -> save revision
                                      \-> undo/redo
                                      \-> crash recovery journal
```

Each command contains stable page/object identifiers, PDF-space coordinates, author, timestamp, and inverse data where practical. UI coordinates must always be converted through one tested transform that handles crop box, media box, rotation, zoom, and device pixel ratio.

## 4. UX that stays easy on every platform

### Shared interaction model

- One top-level mode at a time: Read, Comment, Edit, Organize, Fill & Sign, Scan/OCR, Protect.
- A contextual properties bar appears only after selecting an object.
- The left panel holds thumbnails, outline, comments, search, and attachments.
- Autosave recovery is separate from overwriting the user's source file.
- Destructive or irreversible operations, especially apply-redaction and flatten, always create a new revision and clearly explain the result.
- Tool defaults persist per device; last-used color and width do not reset constantly.

### Responsive layouts

- **Phone:** bottom tool rail, one panel as a sheet, full-screen page canvas, large touch targets.
- **Tablet:** top toolbar plus collapsible side panel; stylus hover/pressure where available.
- **Desktop:** menu bar, keyboard shortcuts, right-click menus, drag-and-drop, resizable sidebars, multiple windows/tabs.

Use familiar shortcuts (`Cmd/Ctrl+O`, `S`, `P`, `F`, `Z`, `Shift+Z`, `+`, `-`) and expose all commands through menus for accessibility.

## 5. Hard engineering problems and the implementation tricks

### Rendering performance

- Render visible pages as tiles, not full pages at maximum zoom.
- Keep low-resolution previews while scrolling; request high-resolution tiles after scroll settles.
- Render outside the UI isolate/thread and cap worker count based on memory pressure.
- Use an LRU cache keyed by document revision, page, scale bucket, rotation, crop box, and tile rectangle.
- Cancel stale render jobs immediately when zoom or revision changes.
- Never keep every page bitmap in memory.

Targets for the first benchmark device set:

- first visible page under 500 ms for a normal local document;
- interaction at 60 fps while ink is drawn;
- no crash opening a 1,000-page or 500 MB test PDF;
- bounded cache, initially 128 MB mobile and 512 MB desktop;
- save operations are atomic and recoverable.

### Existing text editing

This is the largest parity gap. PDF stores positioned glyphs, not paragraphs. The safe progression is:

1. add new text boxes;
2. replace text within one existing text run when the embedded font supports required glyphs;
3. substitute and embed a compatible font when licensing permits;
4. reflow within a detected bounding region;
5. only later attempt multi-column or multi-object paragraph reflow.

Always preview font substitution and provide undo. Never silently rasterize a page to make editing appear successful.

### Annotations

- Store annotations as standard PDF annotation objects with valid appearance streams, not a Flutter-only JSON overlay.
- Keep a sidecar journal only for recovery/collaboration metadata.
- Normalize pressure samples and simplify ink paths before generating appearance streams.
- Generate both screen and print appearances and test the saved file in independent viewers.

### Redaction

Black rectangles are not redaction. Applying redaction must remove covered text, image regions, and relevant metadata/content streams, then compact-save and verify that extracted text and decompressed objects no longer contain the target. Treat apply-redaction as a separate, well-tested pipeline.

### OCR and scanning

- Use platform camera/document scanning APIs for capture and on-device ML where they are clearly better.
- Normalize outputs into one engine-neutral list of `(text, confidence, polygon, language)` values.
- Insert an invisible, correctly transformed text layer and preserve the original image.
- Offer optional language packs rather than bloating every install.
- Tesseract is Apache-2.0 and useful as a desktop/offline fallback, but mobile native OCR may give better packaging and latency.

### Signatures

Keep two features distinct:

- **Drawn signature:** an ink/image annotation; easy and useful, but not cryptographic proof.
- **Digital signature:** a byte-range cryptographic signature with certificate chain, modification detection, validation status, and possibly PAdES timestamp/LTV data.

Signing must use incremental save. Private keys belong in Keychain/Keystore/Windows certificate facilities or a user-selected secure token; never store raw key files in app preferences.

### Safe saving

- Write to a sibling temporary file, flush, validate, then atomically replace where the platform supports it.
- Keep the original until validation succeeds.
- Maintain a small crash-recovery command journal, not duplicate full PDFs after every stroke.
- Offer incremental save for signatures/history and compact save for optimization/redaction.
- Detect external file changes before overwriting on desktop.

### Security

- Treat every PDF as hostile input.
- Parse/render on workers with minimal privileges; Android's own documentation recommends isolated processing for untrusted PDFs.
- Disable PDF JavaScript, launch actions, embedded executables, and network access by default.
- Sanitize URLs and require confirmation before opening external links.
- Fuzz parsers and transformation entry points; run AddressSanitizer/UndefinedBehaviorSanitizer in native CI.
- Delete decrypted temporary files and exclude recovery data from cloud backups where APIs permit.

## 6. Delivery roadmap

Estimates assume a focused team of 4-6 engineers plus part-time design/QA. A solo build should reduce scope rather than multiply deadlines optimistically.

### Phase 0 - Technical proof (4-6 weeks)

- create the Flutter monorepo and engine interfaces;
- implement open/render/search/select on all four primary targets;
- implement one standard highlight, one ink annotation, undo, save, reopen;
- reorder a page, fill one form field, and open an encrypted file;
- run the same 100+ document corpus through every platform;
- compare the pure-Dart adapter against PDFium and independent viewers;
- decide the production engine using written exit criteria.

Exit: no coordinate drift, saved annotations reopen correctly in Acrobat/Preview/Chrome, and the engine choice is evidence-based.

### Phase 1 - Public MVP (12-16 additional weeks)

- polished reader, thumbnails, outlines, links, search, selection, print/share;
- common annotations, properties, undo/redo, autosave recovery;
- page organization, merge/split, images-to-PDF;
- AcroForm filling and flatten-copy;
- drawn signatures and initials;
- password open/save and permission display;
- desktop menus/shortcuts and mobile adaptive UX;
- crash reporting only with consent; no document content in telemetry.

Exit: common personal and office workflows are reliable; app-store beta quality.

### Phase 2 - Strong free editor (4-6 months)

- camera scanning, cleanup, deskew, compression;
- OCR with selectable/searchable output;
- true apply-redaction with verification;
- add/replace text and images with clear limitations;
- headers/footers, watermarks, page numbers, Bates numbering;
- encryption controls, metadata cleanup, optimization;
- document comparison and bulk operations on desktop.

Exit: compelling alternative for most non-enterprise users.

### Phase 3 - Professional features (6-12 months)

- certificate signing and validation, timestamp integration, trust UI;
- advanced existing-content editing and font substitution;
- form authoring and calculations with a safe JavaScript policy;
- accessibility reading order, tagging, alt text, and audit;
- PDF/A conversion and validation; preflight/repair tooling;
- optional end-to-end encrypted sync and collaboration as a separate product.

## 7. Quality strategy

### Corpus

Build a legally distributable corpus that covers:

- PDF versions, cross-reference tables/streams, object streams, linearized files;
- Latin, CJK, RTL, Indic, emoji, ligatures, vertical text, missing fonts;
- transparency, blend modes, patterns, gradients, clipping, huge page sizes;
- AcroForms, malformed forms, JavaScript actions, XFA detection;
- annotations with and without appearance streams;
- encrypted documents and permissions;
- signed documents with valid, expired, revoked, unknown, and modified states;
- scanned pages, rotations, unusual crop/media boxes;
- damaged, adversarial, and very large files.

### Automated checks

- golden render diffs at several scales and rotations;
- save/reopen semantic tests in our engine and an independent parser;
- extracted-text checks after OCR and redaction;
- coordinate property tests for every page rotation/crop combination;
- fuzzing and mutation testing for open/edit/save;
- performance and memory budgets per release;
- accessibility tests and keyboard-only workflows;
- build smoke tests on macOS, Windows, iOS, and Android.

Never claim support for a feature solely because its toolbar button works on the sample PDF.

## 8. Licensing and business choices

- Flutter is appropriate for the shared UI and officially supports the target platform families.
- PDFium has broad real-world rendering coverage but requires careful native builds, binary updates, vulnerability response, and license/notice review.
- qpdf is Apache-2.0 and useful for content-preserving structural transforms; it is not a renderer or high-level content editor.
- Tesseract is Apache-2.0 and can supply offline OCR.
- MuPDF is AGPL for open-source use or commercially licensed for proprietary distribution.
- Every dependency must have a pinned version, license record, source URL, notices, update owner, and security response plan.

The app may be free to users, paid, or open source; decide that separately from framework choice. If it remains fully free, sustainable options include donations, paid optional sync, enterprise support, or an open-core model. Do not fund basic operation by uploading private documents for advertising or model training.

## 9. Team and ownership

Minimum balanced team for the stated ambition:

- 1-2 Flutter/editor interaction engineers;
- 1-2 PDF/native engine engineers;
- 1 platform/release engineer spanning stores, installers, signing, and CI;
- 1 QA automation engineer with PDF corpus ownership;
- part-time product design, accessibility, security, and PKI expertise.

For a solo first release, ship Reader + Comment + Organize + Fill & Sign. Defer existing-text editing, cryptographic validation, accessibility remediation, and preflight.

## 10. First sprint backlog

1. Select a product name and application identifiers.
2. Create the Flutter workspace and four primary platform runners.
3. Define `PdfEngine`, immutable domain types, error taxonomy, and command history.
4. Implement two engine spikes behind identical tests: pure-Dart candidate and PDFium.
5. Add a generated 20-document smoke corpus with no third-party copyright concerns.
6. Build the vertical workflow: open -> render -> highlight -> undo -> save-as -> reopen.
7. Add thumbnail virtualization, render cancellation, and memory instrumentation.
8. Add Windows/macOS file open/save and Android/iOS document-provider flows.
9. Run saved outputs through qpdf validation and independent visual diffs.
10. Record the engine decision, threat model, and supported-feature contract before expanding UI.

## 11. Go/no-go gates

Before promising a public date, require:

- the same edited document renders consistently on all primary platforms;
- no source-file loss in forced-crash save tests;
- corpus pass rate and known incompatibilities are published internally;
- licenses are reviewed for distribution model compatibility;
- large-document memory stays within target budgets;
- redaction is not marketed until forensic tests pass;
- digital signing is not marketed until independent validation passes;
- store packaging, code signing, notarization, and update mechanisms work in CI.
