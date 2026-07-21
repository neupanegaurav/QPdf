# QPdf device-test status

Updated: 2026-07-21

> Note (2026-07-21): The Smart Fill form-detection feature and the optional
> on-device AI model were removed from QPdf. Entries below that referenced a
> portable/SmolLM model or Phase C1–C4 form intelligence have been dropped;
> the remaining device-test results still apply to the shipping app.

## Samsung SM-T860 tablet — Android 12 / API 32

Passed on the physical tablet:

- fresh debug APK installation;
- cold launch into QPdf without a crash or ANR;
- native dark theme with the minimal Apple-inspired visual system;
- Home dashboard at the device's landscape tablet resolution;
- a wide featured Fill & Sign action plus four compact supporting actions;
- inset Recent documents group and privacy footer render without clipping;
- a real three-page PDF opens and renders with thumbnails and page content;
- the persistent Fill & Sign editor action is visible;
- a real AcroForm opens through Home > Fill & Sign in Select mode;
- the accessible Form fields sheet lists the fixture's text and checkbox
  fields;
- text editing and checkbox toggling update the rendered page and mark the
  document modified;
- Save writes the changed form and clears QPdf's unsaved state;
- forced display rotation reconfigures the final app without clipping, loss of
  Home/Recent semantics, crash, or ANR; automatic rotation was restored after
  the check;
- current logcat contains no QPdf fatal exception or ANR.

The final-source `QPdf-0.1.0-android-debug.apk` was installed over the prior
build and launched successfully. It remains the handoff artifact because it
supports debugging and device acceptance.

Not yet claimed as passed:

- handwritten signature placement and independent-viewer reopen;
- camera scan and OCR model download;
- process-death recovery and a real third-party file-provider warm-open;
- portrait rotation, split-screen, printing, and sharing.

These require an intentional hands-on acceptance session using the non-sensitive
fixtures and steps in `docs/DEVICE_TEST_PLAN.md`.

An ADB-only attempt to synthesize a DocumentsProvider URI was rejected by
Android before QPdf launched because the shell process did not own a persisted
URI grant. This is expected platform security behavior and is not recorded as
an application failure; the Files/Drive/OneDrive share flows remain manual
acceptance cases.

## Apple devices

Xcode 27 beta was selected per command and the final source now passes:

- unsigned iOS device compilation;
- signed iOS profile compilation with development team `NTWLLP4VZF`;
- code-signature inspection for bundle ID `studio.gaurav.qpdf`;
- wireless installation of the final signed profile build on a connected
  iPhone 16 Pro Max running iOS 27;
- universal arm64/x86_64 macOS debug and release builds;
- strict nested-signature verification and local macOS launch;
- visual inspection of the macOS Home dashboard.

The iPhone was locked when the final profile build was installed. CoreDevice
correctly denied foreground launch until the owner unlocks it, so iPhone UI and
workflow acceptance are not yet claimed. The local Xcode beta also requires the
test-only missing-dSYM workaround documented in `docs/BUILD_ARTIFACTS.md`;
production archives must use real symbols.
