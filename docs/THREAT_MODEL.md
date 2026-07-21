# QPdf threat model

## Assets

- PDF contents, form values, annotations, signatures, and recovered revisions.
- User-selected source files and the integrity of saved replacements.
- OCR model integrity and future signing keys/certificates.

## Trust boundaries

- Every opened PDF and embedded object is untrusted input.
- File pickers, print/share targets, URLs, and downloaded OCR models cross an
  operating-system or network boundary.
- The pure-Dart PDF engine is inside the app process today. PDFium remains an
  isolated optional adapter but is not yet a sandbox boundary.

## Implemented controls

- Native overwrite uses a sibling temporary file, PDF validation, flush, and
  atomic replacement with Windows rollback handling.
- Recovery data is bound to source/result hashes and ignored after external
  source changes or journal corruption.
- OCR model artifacts have pinned hashes; page content remains on device.
- Android release builds do not reuse debug signing.
- The app has no background document upload, ad SDK, analytics SDK, or PDF
  JavaScript execution path.
- Applying a redaction is an explicit, irreversible transaction. QPdf applies
  the marks to a working copy, renders every page, and creates a fresh
  image-only PDF object graph. Save and Save As remain blocked while unapplied
  marks exist, and a failed operation leaves the live document unchanged.
- The secure image-only boundary removes hidden source text, partially covered
  image XObjects, forms, links, annotations, bookmarks, attachments, metadata,
  accessibility structure, revision history, and signatures. The confirmation
  explains that these features and selectable/searchable text are flattened.
- Deterministic gates check text extraction, decoded streams, physical bytes,
  revision compaction, preserved surrounding content, rendered fill, and prove
  that a partially covered source image hash is absent after secure flattening.

## Release gates still required

- Parser/render fuzzing, malformed/adversarial corpus, dependency CVE scanning,
  and native sanitizers for any production native core.
- Platform-backed encryption for high-sensitivity recovery journals.
- External-link confirmation and explicit blocking of launch/embedded-file
  actions when those interactions are exposed by the UI.
- Expand redaction tests across unusual color spaces/fonts, transparency,
  malformed inputs, very large documents, and independent commercial viewers.
- Keychain/Keystore/Windows certificate-store integration before private-key
  signing is exposed. Raw signing keys must never enter preferences.
