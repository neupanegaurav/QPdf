# QPdf — working notes for Claude

Local-first, cross-platform PDF reader and editor. Flutter. No account, no
analytics SDK, no ad SDK; documents never leave the device.

**Read [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) at the start of every
session.** This file describes how the repo works and does not change often.
That one records where the release actually stands — which machine did what,
what is uploaded, what is blocked — and is the thing to trust and to update.

| | |
| --- | --- |
| Repo | `github.com/neupanegaurav/QPdf` · default branch `main` |
| App | `apps/openpdf_studio` · version `0.1.0+1` |
| App ID | `studio.gaurav.qpdf` (Android, iOS, macOS) |
| Store name | `QPdf - PDF Reader & Editor` |

## Layout

```
apps/openpdf_studio/     the Flutter app — all platform folders live here
packages/pdf_domain/     platform-free document model
packages/pdf_engine_api/ engine interface
packages/pdf_engine_pdfium/  PDFium-backed implementation
third_party/pdf_manipulator/ vendored engine runtime (patched — read its README
                             before touching anything under it)
docs/                    design + release docs, and the GitHub Pages site
                         (docs/index.html, docs/privacy.html — served live)
store/screenshots/       store screenshots captured from real builds
dist/                    released artifacts — Git LFS pointers, run `git lfs pull`
tool/                    build + verification scripts
store-upload-kit/        UNTRACKED, live publishing credentials — see below
```

## Running it

Everything runs from the app directory:

```bash
cd apps/openpdf_studio
flutter pub get
```

| Target | Command |
| --- | --- |
| macOS | `flutter run -d macos` |
| iOS simulator | `open -a Simulator` then `flutter run -d iphone` |
| Android emulator | `flutter emulators --launch Resizable_Experimental` then `flutter run -d emulator-5554` |
| Web | `flutter run -d chrome` |
| Devices visible now | `flutter devices` |

macOS and Chrome run on any machine here. iOS needs a full stable Xcode — see
`docs/PROJECT_STATE.md`, this is the main thing that differs per machine.

### iOS plugins go through CocoaPods, not Swift Package Manager

Keep `flutter config --no-enable-swift-package-manager` set on any machine that
builds iOS. Under Flutter's SPM path every ObjC-implemented plugin
(`file_picker`, `permission_handler_apple`, `integration_test`) fails to link
while the pure-Swift ones succeed, so `GeneratedPluginRegistrant.m` compiles
against classes that were never built:

```
Unknown receiver 'FilePickerPlugin'; did you mean 'FileSaverPlugin'?
Use of undeclared identifier 'IntegrationTestPlugin'
Use of undeclared identifier 'PermissionHandlerPlugin'
```

`ios/Podfile.lock` must list ~37 pods. If it lists one (`onnxruntime` alone),
the project has drifted back onto SPM — that file is the fastest way to tell.
This is a Flutter/plugin packaging problem, not an Xcode one, so it reproduces
on stable Xcode too.

## Checks before calling anything done

```bash
cd apps/openpdf_studio && flutter test      # 47 tests, all green as of 2026-07-23
cd apps/openpdf_studio && flutter analyze
tool/verify_16kb_alignment.sh               # Play blocker — see below
tool/verify_release_artifacts.sh
```

`verify_16kb_alignment.sh` is not optional for Android releases. Since
1 November 2025 Play rejects apps targeting Android 15+ whose native libraries
are laid out for 4 KB memory pages. A 4 KB-page phone runs a bad build
perfectly, so ordinary device testing cannot catch it — only a 16 KB emulator or
the upload itself will. The Gradle build drops the `onnxruntime` plugin's
prebuilt `libonnxruntime.so` and takes
`com.microsoft.onnxruntime:onnxruntime-android:1.20.0` instead; do not undo that
without re-running the gate.

## Release builds

```bash
cd apps/openpdf_studio
flutter build appbundle --release   # → build/app/outputs/bundle/release/app-release.aab
flutter build ipa --release         # needs full stable Xcode
flutter build macos --release
tool/build_apple_test_artifacts.sh  # picks stable Xcode.app, falls back to Xcode-beta.app
```

Android release signing reads `apps/openpdf_studio/android/key.properties`,
which points at `android/qpdf-upload-keystore.jks`. Both are gitignored, so a
fresh clone cannot produce a signed build until they are copied across by hand.

## Secrets

`store-upload-kit/` holds live App Store Connect and Google Play publishing
credentials — an API `.p8`, a Play service-account JSON, and keystores. It is
untracked, has its own `.gitignore` of `*`, and the root `.gitignore` blocks
`*.p8`, service-account JSON and `secrets/`.

Never commit it, never paste its contents into a file, a commit message, or a
store listing. It moves between machines by hand only. Same rule for
`android/key.properties` and `android/qpdf-upload-keystore.jks` — git is not a
backup of those, and losing them means never shipping an update to the same Play
listing without a Google key-reset request.

## Conventions

- Conventional Commits, lowercase, imperative: `fix(android): ship 16 KB
  page-aligned native libraries`. Scopes in use: `app`, `android`, `ios`,
  `release`, `store`, `site`, `fill`, `core`, `engine`, `fixtures`, `repo`,
  `git`, `home`.
- User-facing strings go through `AppLocalizations` (`lib/l10n/*.arb`, en + es).
  `localization_test.dart` fails if Spanish misses an English key.
- Comments explain why a decision was made, not what the line does. Match the
  density already in the file.
- Store listing copy lives in `docs/STORE_SUBMISSION.md` §8 and is the single
  source of truth — if a feature changes, fix the copy in the same change.
