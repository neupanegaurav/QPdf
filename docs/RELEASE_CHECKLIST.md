# QPdf release and device-test checklist

## Automated gates

- Analyze and test `pdf_domain`, `pdf_engine_api`, `pdf_engine_pdfium`, and the
  Flutter application.
- Generate and verify the 120-document compatibility corpus.
- Run the independent forensic redaction gate and the partial-image object-hash
  regression test.
- Run image-heavy rendering and the 1,000-page structural benchmark.
- Build JavaScript and WebAssembly web releases.
- Build and upload Android debug APK and unsigned release AAB, unsigned iOS
  release app, macOS release app, Windows release directory, and Linux release
  bundle in CI.

## Android

1. Create a Play upload key and keep it outside the repository.
2. Copy `apps/openpdf_studio/android/key.properties.example` to
   `apps/openpdf_studio/android/key.properties` and supply protected values.
3. Run `flutter build appbundle --release` and verify the AAB in Play Console's
   internal testing track.
4. Test file picker/provider access, camera scan, print/share, OCR model
   download, process death recovery, and atomic overwrite on phone and tablet.
5. Apply secure redaction, save the image-only result, and confirm covered text
   and image content cannot be recovered in independent viewers.

## iPhone and iPad

1. Install/select full Xcode and run its first-launch setup.
2. Set the Apple development team and register `studio.gaurav.qpdf`.
3. Build an Archive, upload to App Store Connect, and distribute with TestFlight.
4. Test Files-provider open/save, camera/VisionKit scan, AirPrint/share, OCR,
   rotation, split view, memory pressure, and recovery on iPhone and iPad.

## Desktop and web

- Sign and notarize macOS; sign Windows; produce Linux bundle/AppImage/package.
- Verify native open/save dialogs, print, keyboard navigation, HiDPI, dark mode,
  large files, and recent-file behavior.
- Serve `build/web` over HTTPS with immutable hashed assets and restrictive
  CSP/security headers. Web OCR is intentionally unavailable unless a separate
  opt-in service is designed.

## Manual release gates

- Run the real-world/adversarial corpus and visual-difference baselines.
- Verify edited files in Acrobat Reader, Preview, Chrome, PDFium, Poppler, and
  qpdf; extend forensic redaction checks to unusual fonts/color spaces,
  transparency, malformed inputs, and large documents.
- Complete accessibility and localization reviews.
- Review licenses/notices and dependency vulnerabilities.
- Host the privacy policy and complete store privacy/data-safety forms.
- Increment build number, tag the exact source, archive symbols, retain signing
  provenance, and document rollback.
- Recheck the tracked Flutter/plugin migration risks in `DEPENDENCY_RISKS.md`.
