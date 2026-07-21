# QPdf device-test artifacts

Verify every artifact from this directory with:

```sh
shasum -a 256 -c SHA256SUMS
```

## Android

`QPdf-0.1.0-android-debug.apk` is signed with the standard Android debug
certificate. Install it with:

```sh
adb install -r QPdf-0.1.0-android-debug.apk
```

`QPdf-0.1.0-android-release-unsigned.aab` is the verified release-mode bundle
input for store signing. It is intentionally unsigned and cannot be uploaded
or installed until a protected Play upload key is configured.

## iPhone and iPad

`QPdf-0.1.0-ios-profile.ipa` is a profile-mode device build signed by Apple
development team `NTWLLP4VZF`. It is intended only for devices registered to
that development profile; it is not an App Store archive.

The local Xcode 27 beta toolchain hangs while producing AOT dSYMs. This test IPA
was therefore built with the explicitly scoped `QPDF_ALLOW_MISSING_DSYM=1`
workaround in `tool/xcode-beta-bin/xcrun`. It contains the complete signed app
but must not be used as a production archive or crash-symbol source.

## macOS

`QPdf-0.1.0-macos-universal.zip` contains a universal arm64/x86_64 release app.
Its nested code signatures verify, but the outer application is ad-hoc signed
and not notarized. It is suitable for local development testing, not public
distribution.

## Web

`QPdf-0.1.0-web-wasm.zip` contains the WebAssembly release output. Extract and
serve it from an HTTP server; do not open `index.html` directly from disk.

Use non-sensitive fixtures and follow `docs/DEVICE_TEST_PLAN.md`. Store/public
builds still require the release signing, notarization, and acceptance gates in
`docs/RELEASE_CHECKLIST.md`.
