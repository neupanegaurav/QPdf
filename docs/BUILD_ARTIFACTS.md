# QPdf build artifact matrix

Updated: 2026-07-20

| Target | Current artifact/evidence | Device-test state | Public-release gate |
| --- | --- | --- | --- |
| Android | Final-source debug APK plus unsigned release AAB, SHA-256 manifest | APK installed and foreground-launched on Samsung SM-T860; real form edit/save passed | Play upload key and store testing |
| iOS/iPadOS | Final-source signed profile IPA plus successful unsigned device build | Installed on iPhone 16 Pro Max; launch awaits an unlocked device | Distribution profile, archive dSYMs, App Store Connect/TestFlight |
| macOS | Universal arm64/x86_64 release app ZIP | Signature verified and app launched locally | Developer ID signing and notarization |
| Web | WebAssembly release ZIP | JS/Wasm compilers pass; final Wasm bundle runtime-smoked in Chrome at phone, tablet, and desktop sizes | HTTPS host, CSP, broader browser acceptance matrix |
| Windows | Release artifact job in GitHub Actions | Awaiting execution on a Windows runner | Authenticode signing and Windows device acceptance |
| Linux | Release bundle job in GitHub Actions | Awaiting execution on an Ubuntu runner | Package/AppImage policy and Linux device acceptance |

All locally packaged artifacts are listed in `dist/SHA256SUMS`. GitHub Actions
uploads native release directories for web, iOS, macOS, Windows, and Linux,
plus the signed debug APK and unsigned release AAB for Android.

`tool/verify_release_artifacts.sh` verifies all five hashes and archive
structures, Android APK v2 signing, and the intentionally unsigned AAB. The
iOS and macOS app bundles also pass strict nested code-signature verification;
the macOS executable and App framework contain both arm64 and x86_64 slices.

The final WebAssembly bundle was served locally and rendered in Chrome
150 at 390×844, 1024×1366, and 1440×900. Each viewport had matching
layout/scroll widths and no browser warning or error logs; screenshots were
visually inspected for clipping and responsive layout.

The Android release AAB builds successfully on this host after disabling
Gradle's native file watcher, which can stall while snapshotting projects on an
external macOS volume. It is deliberately unsigned until a protected Play
upload key is supplied through `android/key.properties`.

## Apple toolchain note

The host has Xcode 27 beta at `/Applications/Xcode-beta.app` while the global
developer path remains Command Line Tools. Local commands select the toolchain
without changing the machine globally:

```sh
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
export PATH="$PWD/tool/xcode-beta-bin:$PATH"
```

Xcode 27 requires iOS 15 and macOS 12 or later, so QPdf and every generated Pod
target use those explicit minimums. The optional
`QPDF_ALLOW_MISSING_DSYM=1` workaround is only for locally launchable
profile/release test apps on this beta; production archives must generate and
retain real dSYMs.
