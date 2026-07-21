# Engine decision: pure Dart primary, PDFium compatibility oracle

Status: accepted for QPdf beta development on 2026-07-19.

## Decision

QPdf will continue with the `dart_pdf_editor` / `pdf_document` stack as its
primary application engine. The `pdf_engine_pdfium` package remains an isolated
native comparison adapter and compatibility oracle; it is not linked into the
shipping application yet.

This decision is deliberately reversible. Screens depend on `pdf_engine_api`,
and the PDFium implementation lives in a separate Flutter package.

## Evidence

- The generated 120-document corpus passes 120 opens and 120 incremental
  save/reopen cycles through the primary adapter.
- Independent pypdf, Poppler, and `pdfinfo` gates pass all 120 generated files.
- Password-protected documents, forms, annotations, rotation, transparency,
  six page geometries, and one-to-three-page documents are represented.
- The 1,000-page structural benchmark stays far inside its five-second and
  512 MB smoke ceilings on the development machine.
- Four sampled pages in the deterministic 29 MB image-heavy fixture render
  inside the debug-test time and memory ceilings.
- Flutter analysis, unit/widget tests, web release/Wasm checks, and a local
  Android debug APK build pass.
- The pure-Dart stack preserves one implementation across Android, iOS,
  macOS, Windows, Linux, and web. PDFium would add native binary distribution,
  vulnerability-response, and platform-build work.

## Conditions and risks

This is approval for beta development, not a claim of universal PDF
compatibility. Before a public production release, QPdf still needs licensed
real-world and hostile corpora, render-difference baselines, independent viewer
checks for edited outputs, fuzzing, and release-profile device measurements.

The PDFium package currently passes analysis and its adapter metadata test. Its
native corpus run requires a supported native host with the PDFium binary
linked; that gate remains in CI/device acceptance. If the primary engine fails
compatibility or security thresholds, PDFium can replace rendering and text
geometry without changing product screens.
