# QPdf Phase 0 Status - Technical Proof

Updated: 2026-07-20

## Completed in the first increment

- Flutter runners for Android, iOS, macOS, Windows, Linux, and web.
- A shared `pdf_domain` package with engine-neutral document models and bounded command history.
- A shared `pdf_engine_api` package with a replaceable engine contract, capability declaration, and normalized open errors.
- An experimental pure-Dart engine adapter that validates PDFs, reads page count/version/metadata, and maps password/parser errors.
- Cross-platform PDF selection, including native path reads and web byte reads.
- An adaptive, local-first empty state and document editor shell.
- Full editor integration for rendering, search, annotations, forms, page editing, undo/redo, and save callbacks.
- Password prompt, unsaved-change indicator, insert-PDF callback, page export, and Save As.
- Light/dark Material 3 themes.
- Unit and widget coverage for command history, engine parsing, invalid files, empty state, picker cancellation, and editor opening.

## Completed in the second increment

- Native Save and Save As are now distinct operations.
- Native Save uses a validated sibling temporary file and atomic replacement.
- Windows-compatible replacement keeps a rollback backup until the new file is in place.
- Invalid/non-PDF output is rejected before the original file is touched.
- A deterministic, legally distributable 120-document generated corpus.
- Six page geometries, four rotations, one-to-three pages, text, vector transparency, AcroForms, links, note annotations, and AES-256 encryption.
- Independent pypdf parsing/text extraction, `pdfinfo`, Poppler rendering, structural rewrite, and reopen verification.
- Application-engine corpus gate: 120 opens plus 120 incremental save/reopen cycles.
- Representative unrotated form, rotated vector, and rotated annotation renders visually inspected with no layout defects.

## Completed in the third increment

- Crash-recovery service with a one-second write debounce.
- Compact recovery journals store only the incremental PDF suffix when the edited revision retains the source as a byte prefix.
- Full-snapshot fallback for compact/destructive revisions.
- Journal integrity checks bind recovery to source ID, source hash, source length, and reconstructed-result hash.
- Recovery data is ignored when the source changed externally or the journal is malformed.
- Restore, Discard, and Cancel workflow before opening a recoverable document.
- Successful Save and Save As clear the matching recovery journal.
- App shutdown flushes pending recovery work.
- A 1,000-page structural performance benchmark with explicit CI ceilings.

## Completed in the fourth increment

- An isolated `pdf_engine_pdfium` comparison adapter with engine-neutral
  metadata/open behavior and native-library lifecycle management.
- A deterministic 29 MB, 12-page image-heavy render fixture and real bitmap
  render/memory smoke test.
- Cross-platform CI definitions for quality, web/Wasm, Android APK and release
  AAB, unsigned iOS, macOS, Windows, and Linux builds.
- Stable QPdf identifiers (`studio.gaurav.qpdf`) across mobile and desktop;
  release builds no longer fall back to Android's debug signing key.
- Local Android debug APK built successfully.
- Written engine decision retaining the pure-Dart engine for beta development
  while keeping PDFium as a replaceable compatibility oracle.

## Verification

- `pdf_domain`: analysis clean; 3 tests passing.
- `pdf_engine_api`: analysis clean; 1 test passing.
- Flutter app: analysis clean; 51 tests passing. Shared engine packages add 5
  passing tests, for 56 automated tests across the workspace.
- JavaScript and WebAssembly web release builds: passing.
- Built web shell served locally and visually inspected at phone, tablet, and
  desktop sizes; layout and typography passed with no browser console errors.
- Generated corpus: 120/120 parse, extract, render, rewrite, and reopen checks passing.
- Dart engine: 120/120 opens and 120/120 incremental save/reopen cycles passing.
- 1,000-page benchmark: 24 ms generation, 15 ms engine open, 74 ms full
  page-tree traversal, 3 ms incremental save/reopen, with no measured RSS
  growth on the development machine.
- Image-heavy render fixture: 12 pages / 29 MB; four sampled bitmap renders
  pass the debug smoke time and 768 MB memory ceilings.
- Android debug build: passing at
  `apps/openpdf_studio/build/app/outputs/flutter-apk/app-debug.apk`.
- Android release AAB: passing at
  `apps/openpdf_studio/build/app/outputs/bundle/release/app-release.aab`; it is
  intentionally unsigned until the protected Play upload key is supplied.

## Apple build evidence

Xcode 27 beta is selected per command without modifying the system developer
path. Unsigned iOS device builds, signed iOS profile builds, and universal
macOS debug/release builds now succeed. See `docs/BUILD_ARTIFACTS.md` for the
beta-only dSYM limitation and distribution gates.

## Phase 0 exit decision

Phase 0 is complete for continued beta development. See
`docs/ENGINE_DECISION.md`. The remaining real-world corpus, pixel-difference,
hostile-input, native PDFium, and independent-viewer checks are release gates;
they remain active while Phase 1 product work proceeds.

## Next increment

Phase 1-3 scoped implementation is tracked in the corresponding status files.
The remaining path is signing plus physical-device and independent-viewer
acceptance using `docs/DEVICE_TEST_PLAN.md`.
