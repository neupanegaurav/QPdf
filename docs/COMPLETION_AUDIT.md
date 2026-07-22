# QPdf completion audit

Updated: 2026-07-21

> Note (2026-07-21): The Smart Fill form-detection feature and the optional
> on-device AI model (SmolLM/llama.cpp runtime and Apple Foundation Models
> integration) were removed from QPdf. Bullets describing them have been
> dropped and the dependent facts below (test counts, Android minimum, Apple
> packaging) updated accordingly.

## Current outcome

The scoped Phase 0-3 application is implemented and locally test-ready on the
platforms available to this macOS host. This is not yet a claim that every
public store release gate has passed.

## Proven from the final source

- Flutter analysis is clean and all 47 application tests pass.
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
- Android debug APK and unsigned release AAB build successfully. The final APK
  installs and foreground-launches on a Samsung SM-T860 tablet; real form text,
  checkbox, modified-state, and Save behavior passed there.
- JavaScript and WebAssembly web release compilation succeeds. The final Wasm
  artifact also runs in Chrome at 390×844, 1024×1366, and 1440×900 with no
  horizontal overflow, browser warnings, or browser errors.
- Unsigned iOS device and signed iOS profile builds succeed. The final signed
  app installs on a paired iPhone 16 Pro Max; automated launch was denied only
  because the phone remained locked.
- Universal arm64/x86_64 macOS release builds, passes strict signature checks,
  and launches locally.
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

## Post-audit release-configuration hardening (2026-07-21)

These fixes close release-only gaps that debug-build device testing could not
observe. They still require a fresh release-build acceptance pass.

- Android: `INTERNET` and `CAMERA` are now declared in the `main` manifest, not
  only the debug/profile manifests. Prior release AABs could not download the
  OCR model and could not grant camera access for scanning; the passing device
  test used the debug APK, which masked this.
- macOS: the sandboxed release entitlements now grant user-selected file
  read-write, outgoing `network.client`, and `print`. Previously a sandboxed
  release build could launch but could not open/save picked files, download
  models, or print.
- Mobile save: `savePdf` no longer overwrites the `file_picker` cache copy on
  Android/iOS (a silent no-op against the user's real document). Those
  platforms now export through the system save sheet; in-place atomic overwrite
  is restricted to desktop, where the picked path is the user's real file.

## Store-submission blockers closed (2026-07-22)

- Android 16 KB page size. Google Play rejects apps targeting Android 15 or
  later when a shipped `.so` has LOAD segments aligned below 16 KB. The
  `onnxruntime` plugin's prebuilt `libonnxruntime.so` was 4 KB aligned, so the
  release bundle would have been refused at upload. The app's Gradle build now
  drops that copy and takes `com.microsoft.onnxruntime:onnxruntime-android`
  1.20.0, which is 16 KB aligned for every ABI, and excludes its unused Java
  JNI bridge (`libonnxruntime4j_jni.so`, still 4 KB aligned). Every shipped
  library now passes; `tool/verify_16kb_alignment.sh` is the gate.
  Verified on the `sdk_gphone16k_arm64` 16 KB emulator: the release APK no
  longer raises the system page-size warning, opens a form PDF, and completes a
  full on-device OCR pass, so ONNX Runtime 1.20 works with the plugin's
  OrtApi 14 bindings.
- iOS `ITSAppUsesNonExemptEncryption` was absent, which stalls every App Store
  Connect upload on the manual export-compliance question.
- iOS `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription`
  were absent while the scanner links `DKImagePickerController`, which uses the
  Photos framework. That is a review rejection, or a crash when the picker opens.
- macOS lacked `LSApplicationCategoryType`, required by the Mac App Store, and
  had no `CFBundleDocumentTypes` entry, so it could not be offered as a PDF
  handler.

Measured Android download size after the fix: 32.6 MB for an arm64-v8a device
(75.4 MB installed). The 186 MB bundle on disk is mostly debug symbols that
Play strips and never ships.
