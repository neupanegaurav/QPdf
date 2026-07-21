# QPdf dependency and toolchain risks

Updated: 2026-07-20

These items do not prevent the current Flutter 3.44.2 test builds, but must be
resolved before adopting the indicated future toolchains.

## Android built-in Kotlin migration

`file_picker` and `file_saver` still apply the Kotlin Gradle Plugin. QPdf keeps
the Flutter template compatibility switches `android.builtInKotlin=false` and
`android.newDsl=false`; Android Gradle Plugin 10 removes that compatibility
path. Upgrade both plugins to built-in-Kotlin-compatible releases before moving
to AGP 10, then remove the switches and the compatibility overrides together.

## Apple Swift Package Manager migration

Flutter supports Swift Package Manager but currently falls back to CocoaPods
because the OCR runtime dependency does not provide a compatible Swift package.
Track an SPM-capable `onnxruntime` integration before Flutter makes missing SPM
support a hard error. Do not remove the working CocoaPods fallback prematurely.

## Xcode 27 beta dSYM generation

The installed Xcode 27 beta hangs in `dsymutil` for Flutter AOT/native assets.
`tool/xcode-beta-bin/xcrun` has an explicit
`QPDF_ALLOW_MISSING_DSYM=1` device-test workaround. It must never be used for a
production archive: use a stable supported Xcode release and retain real dSYMs
for App Store submission and crash symbolication.

## Portable llama runtime

`lib_llama_cpp` 0.7.3 supplies the in-process GGUF runtime for native portable
Smart Fill. Its Android library declares API 28, so QPdf must not lower its
Android minimum or force a manifest override. Its macOS XCFramework currently
emits a non-fatal `Versions/Current` symlink warning during Xcode packaging;
debug inference and release compilation pass, but this packaging warning must
be rechecked before notarization and after every runtime upgrade. Windows and
Linux runtime inference remain CI/device acceptance gates rather than claims.
