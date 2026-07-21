# QPdf completion audit

Updated: 2026-07-21

## Current outcome

The scoped Phase 0-3 application is implemented and locally test-ready on the
platforms available to this macOS host. This is not yet a claim that every
public store release gate has passed.

## Proven from the final source

- Flutter analysis is clean and all 83 application tests pass.
- The shared domain and engine packages add 5 passing tests.
- A deterministic 120-PDF corpus passes independent parsing, extraction,
  rendering, rewrite/reopen, plus 120 app-engine open and save/reopen cycles.
- The independent redaction gate proves a repeated secret absent from Poppler
  text extraction, decoded content streams, and physical output bytes; it also
  verifies single-revision compaction, surrounding-content preservation, and
  the rendered black fill.
- Redaction workflow tests prove unsafe Save is blocked, the operation replaces
  the editor only after success, and secure flatten removes a partially covered
  source image object. The result is intentionally image-only.
- Smart Fill privately analyzes interactive form metadata, produces a single
  reviewable questionnaire, validates required fields, and populates text,
  checkbox, radio, and choice controls only after confirmation.
- Native flat-form Smart Fill detects labelled vector lines/boxes, while its
  scanned-form baseline pairs private OCR labels with pixel-detected lines and
  check boxes. Both paths show editable confidence-scored suggestions and
  convert only approved candidates into real fields; scans without OCR produce
  a clear on-device OCR recovery action instead of guessed labels.
- Smart Fill's semantic layer uses Apple Foundation Models on eligible
  iOS/iPadOS/macOS devices, exposes only non-value field metadata, validates
  guided output against the authoritative form, and falls back to the same
  deterministic questionnaire on every platform. Adversarial tests prove that
  incomplete, invented, or control-changing model output is rejected.
- Other native targets can explicitly download a pinned 105.5 MB compact GGUF
  model for private in-process label assistance. Size and SHA-256 verification,
  retry/delete lifecycle, platform fallback, and strict field-name validation
  are automated. End-to-end inference passes in 1.14 seconds on macOS and 7.89
  seconds on the Samsung tablet; deterministic field types, sections, values,
  and confirmation remain authoritative.
- The model settings now include an end-to-end timed self-test. Additional
  adversarial validation rejects labels that resemble invented dates, phone
  numbers, email addresses, or answer literals, and requires semantic overlap
  with the authoritative field identity. A 360M candidate failed this gate and
  was intentionally rejected rather than exposed as a larger download tier.
- Smart Fill now applies deterministic, reversible conditional visibility for
  spouse, employment, alternate-mailing, and dependent sections. Its C4.3
  corpus covers 10 synthetic AcroForms and 83 controls with 83/83 expected
  metadata matches, including radio controls, shaped Arabic/RTL labels, a
  five-page 28-field household form with three count-controlled dependent rows,
  and exact Devanagari/CJK Unicode labels. Repeated values survive save/reopen;
  pypdf reads the expected values; Poppler rendering and visual review pass;
  and dynamic visibility exposes live-region and section-heading semantics.
- Real-world acceptance now uses three checksum-pinned, download-only official
  forms. USCIS I-9 passes full AcroForm compatibility with 128 questions; IRS
  W-9 and VA 10-5345 pass compatible-field save/reopen but are explicitly
  marked partial XFA forms. Smart Fill exposes accessible warnings. Its
  coordinate-only recovery produces editable, confidence-scored labels for 21
  of W-9's 23 generic producer fields and leaves two ambiguous fields generic;
  semantic AI is disabled for these partial/XFA paths.
- Verification copies of all three official forms preserve a synthetic value
  through save/reopen and pass first-page Poppler visual review. Chrome/PDFium
  independently loads and visually renders the saved six-page W-9. Preview
  launch succeeds, but its UI capture timed out and Acrobat is unavailable, so
  those full viewer passes remain open rather than being overstated.
- Android debug APK and unsigned release AAB build successfully with API 28 as
  the native portable-runtime minimum. The final APK
  installs and foreground-launches on a Samsung SM-T860 tablet; real form text,
  checkbox, modified-state, and Save behavior passed there.
- JavaScript and WebAssembly web release compilation succeeds. The final Wasm
  artifact also runs in Chrome at 390×844, 1024×1366, and 1440×900 with no
  horizontal overflow, browser warnings, or browser errors.
- Unsigned iOS device and signed iOS profile builds succeed. The final signed
  app installs on a paired iPhone 16 Pro Max; automated launch was denied only
  because the phone remained locked.
- Universal arm64/x86_64 macOS release builds, passes strict signature checks,
  and launches locally. Apple packaging now restores canonical symlinks in the
  expanded llama XCFramework before applying the local test signature.
- All five files in `dist/` pass their SHA-256 and structural verification.

## Gates that require another environment or owner credentials

- Execute the existing Windows and Linux GitHub Actions jobs and device-test
  their produced bundles. No Windows/Linux runner is connected to this host.
- Unlock the paired iPhone and complete the iPhone/iPad hands-on workflow.
- Supply protected Android Play and Apple Distribution/Developer ID
  credentials, create production archives with full dSYMs, notarize macOS,
  and run store beta review.
- Complete the remaining manual matrix: independent-viewer signature/form
  reopen, camera/OCR, process-death recovery, third-party provider warm-open,
  printing/sharing, accessibility review, and hostile-document security review.
- Run the optional PDFium corpus oracle in an environment that provides its
  native dynamic library; the pure-Dart and independent Poppler/pypdf gates
  already pass.

Use `docs/DEVICE_TEST_PLAN.md` for hands-on steps and
`tool/verify_release_artifacts.sh` before transferring any build.
