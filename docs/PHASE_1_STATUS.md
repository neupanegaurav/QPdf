# QPdf Phase 1 Status - Public MVP

Updated: 2026-07-20

## Implemented

- Apple-inspired adaptive Home dashboard with a featured Fill & Sign action,
  compact task cards, and a persistent newest-first recent-document group.
- Fill & Sign is the primary Home action and a persistent editor shortcut.
  A dedicated accessible Form fields sheet lists text, checkbox, radio,
  combo-box, and list-box fields without requiring precise canvas taps;
  handwritten and cryptographic self-signed signatures are separately
  identified.
- Reader/editor shell with zoom, search, selection, thumbnails, outlines,
  links, annotations, page organization, forms, drawn signatures, undo/redo,
  Save, Save As, export, and flatten-form tools.
- Password prompt and propagation into the editor session.
- A Protect report that identifies encryption type and decodes print, modify,
  copy, annotation, form, accessibility, assembly, and high-quality-print
  permissions from the PDF standard security handler.
- Atomic native overwrite, validated Save As, compact crash-recovery journal,
  and unsaved-change guards.
- Desktop/native overwrite compares the current file with the exact bytes QPdf
  opened, checks again after flushing the temporary revision, and refuses to
  replace a file changed by another application.
- Print/share from the live in-memory revision.
- Images-to-PDF, explicit merge workflow, and page extraction/splitting.
- Android and iOS PDF file registration, cold-start open, and warm-app open;
  desktop command-line file open.
- Minimal light/dark visual system built on accessible Material controls:
  system typography, neutral grouped surfaces, pill controls, generous spacing,
  responsive phone/tablet/desktop layouts, labels, and tooltips.
- Stable identifiers (`studio.gaurav.qpdf`) and QPdf launcher assets.

## Verification

- Flutter analysis is clean and all 51 application tests pass, including form
  fill/save/reopen, handwritten-signature persistence, and Save-state tests.
- Responsive dashboard tests cover 390×844, 1024×1366, and 1440×900.
- JavaScript and WebAssembly web release builds pass.
- Android debug APK and unsigned release AAB build with native scanner, OCR,
  and open-intent code.
- The final debug build installs and launches on a physical Samsung SM-T860
  tablet running Android 12. A real form's text and checkbox values were
  changed, visibly updated, and saved on that tablet.
- Unsigned iOS and signed profile builds succeed. The signed build was installed
  on a connected iPhone 16 Pro Max; foreground launch awaits an unlocked phone.
- Universal macOS debug and release builds succeed, validate, and launch.

## Phase 1 exit

The code and automated gates for Phase 1 are complete. Store signing and
physical-device acceptance are release operations, not missing application
features. Use `docs/DEVICE_TEST_PLAN.md` before distributing a beta.

## Password controls

QPdf preserves existing standard encryption during supported incremental edits.
The Protect workflow can also add, replace, or remove password protection using
an AES-256 structure-preserving full rewrite, with explicit user permissions.
Because a full rewrite invalidates existing digital signatures, the UI warns
before changing protection.
