# QPdf device-test status

Updated: 2026-07-21

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
- the verified 105.5 MB portable SmolLM2 model loads from private app storage,
  performs a two-field Smart Fill semantic pass in 7.89 seconds, preserves the
  authoritative DOB/date and address metadata, and disposes cleanly;
- the portable runtime build raises the supported Android minimum to Android 9
  / API 28; the tablet runs Android 12 / API 32.
- the Phase C3 in-app self-test executes the real model plus strict semantic
  validator and reports elapsed time. Its later instrumentation run passed in
  37.44 seconds, showing significant thermal/load variability from the earlier
  7.89-second result; both remain below the 60-second safety timeout.
- the Phase C4 debug APK installs over the existing app without clearing its
  verified private model, launches normally, and shows no QPdf fatal exception
  or ANR in the inspected log. Conditional questionnaire interaction remains
  automated on this build and is ready for hands-on fixture testing.
- the Phase C4.2 APK (SHA-256
  `8dccb2d92fab713cecf6d4672fbd6fdb1d0e5e5585107fb760463113f94707ff`)
  installs in place, foregrounds successfully, and preserves the 101 MiB
  private model at `files/qpdf/models/SmolLM2-135M-Instruct.Q4_K_M.gguf`.
  Android reports the activity fully drawn with no fatal exception or ANR in
  the inspected post-launch log.
- the Phase C4.3 APK (SHA-256
  `ea8ab81589e7f0aba4f809ab292f5036fd6c2390552ce6f6f3854b9dd3a238aa`)
  was byte-compared against the installed package after a staged ADB transfer,
  cold-launched in 4.809 seconds, and preserved the 101 MiB private AI model.
  The inspected post-launch log contains no QPdf fatal exception or ANR.

The final-source `QPdf-0.1.0-android-debug.apk` was installed over the prior
build and launched successfully. It remains the handoff artifact because it
supports debugging and device acceptance.

Not yet claimed as passed:

- handwritten signature placement and independent-viewer reopen;
- camera scan and OCR model download;
- process-death recovery and a real third-party file-provider warm-open;
- portrait rotation, split-screen, printing, and sharing.
- Phase C4.4 Android installation: the latest APK built successfully with
  SHA-256
  `6360851521d938af19764c3a719aa70026f3eaaeea0230054158b239170a142a`,
  but the Samsung tablet disconnected before installation and byte comparison.
  The prior C4.3 installation remains the latest physically verified Android
  build.
- Phase C4.5 Android installation: the fresh APK built successfully with
  SHA-256
  `8be42bbb07be3271b32964895c63efbca0974a1afb994847405745d3ef074629`.
  No Android device was connected after the build, so the C4.3 installation
  remains the latest physically verified Android build. C4.5's editable W-9
  label review and TalkBack flow remain ready for the next connection.

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
- real portable-model inference on macOS completes the same strict two-field
  benchmark in 1.14 seconds; unsigned iOS device compilation includes the
  portable runtime, while inference on a physical iPhone remains a hands-on
  acceptance item.

No paired or wireless iPhone was visible to Flutter/CoreDevice during Phase C3,
so no new physical-iPhone inference claim is made.

The iPhone was locked when the final profile build was installed. CoreDevice
correctly denied foreground launch until the owner unlocks it, so iPhone UI and
workflow acceptance are not yet claimed. The local Xcode beta also requires the
test-only missing-dSYM workaround documented in `docs/BUILD_ARTIFACTS.md`;
production archives must use real symbols.
