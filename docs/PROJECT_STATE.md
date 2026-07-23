# QPdf — project state

**Updated 2026-07-23.** Everything in the "verified" column was checked by
running the command on that date, not copied from an earlier document. Re-run
them rather than trusting this page if more than a few days have passed.

This is the handoff file. When Claude starts on any machine it should read this
before doing anything else, and update it at the end of a session where the
state changed.

---

## 1. Where the release actually stands

| Step | State | Verified how |
| --- | --- | --- |
| Android upload keystore | **Done** — QPdf-specific | `android/qpdf-upload-keystore.jks` present |
| Signed release AAB built | **Done** — 186 MB on disk, 32.6 MB actual arm64 download | file exists, dated 2026-07-22 |
| Android 16 KB page alignment | **Done** — every shipped lib ≥16 KB | `tool/verify_16kb_alignment.sh`, plus a run on a 16 KB emulator |
| Apple Bundle ID `studio.gaurav.qpdf` | **Done** — registered, platform UNIVERSAL, name "QPdf" | `asc.py bundleids` |
| iOS/macOS export-compliance + privacy plist keys | **Done** | `docs/STORE_SUBMISSION.md` §6 |
| Privacy policy + marketing page live | **Done** — both return HTTP 200 | `curl` on both URLs |
| Android screenshots | **Done** — 4 phone portrait + 3 tablet landscape | phone 1080×2400, tablet 2560×1600 |
| Play feature graphic + 512 icon | **Done** | `store/graphics/`, regenerate from `tool/feature_graphic.html` |
| Listing copy matches the binary | **Done** — form-filling claims removed | `0e5986d`, `grep` across docs + site |
| Store push automation | **Done** — dry-run by default | `tool/publish_play.py check`, `tool/publish_asc.py check` |
| Test suite | **Green** — 47 passing | `flutter test` |
| **Play Console app record** | **NOT created** | `publish_play.py check` → `404 Package not found` |
| **App Store Connect app record** | **NOT created** | `publish_asc.py check` → no record for the bundle ID |
| **iOS build ever archived/uploaded** | **No** | no full stable Xcode on the machine that has the source |
| iPhone + iPad screenshots | **Done** — 1 each, Home screen | iPhone 1320×2868 portrait, iPad 2752×2064 landscape, from the simulator |
| macOS screenshot | **Done** — not part of this submission | 1280×800, `store/screenshots/macos/` |
| macOS release build | **Works** — no longer blocked | built 2026-07-23 via `DEVELOPER_DIR`, executable relinked |
| Android APK / AAB release | **Works** | 104 MiB APK, 186 MiB AAB, both rebuilt 2026-07-23 |
| Web release (wasm) | **Works** | `main.dart.wasm` 5.4 MB, rebuilt 2026-07-23 |
| iOS simulator build | **Works** — after moving off SPM | 71s; installs and launches on iPad Pro 13" M5 |
| iOS device build (unsigned) | **Works** — after moving off SPM | `flutter build ios --release --no-codesign`, 69s |

Live URLs, both confirmed serving:

- Privacy policy — <https://neupanegaurav.github.io/QPdf/privacy.html>
- Marketing — <https://neupanegaurav.github.io/QPdf/>
- Support — <https://github.com/neupanegaurav/QPdf/issues>

### The two things blocking a first submission

1. **Both store records still have to be created in a browser.** No API can do
   it. Play returns `404 Package not found` until the listing exists, and Google
   requires that very first bundle to arrive through the browser. Steps and
   every questionnaire answer are written out in `docs/STORE_SUBMISSION.md`
   §3, §4, §8, §9 — they are ready to paste.
2. **No iOS build exists.** See the machine matrix below.

Once both records exist, nothing else needs a browser. Neither script writes
without `--commit`:

```bash
PY=store-upload-kit/.venv/bin/python
$PY tool/publish_play.py listing --commit
$PY tool/publish_play.py bundle \
  apps/openpdf_studio/build/app/outputs/bundle/release/app-release.aab \
  --track internal --commit
$PY tool/publish_asc.py metadata --commit
```

Both read the listing copy from `docs/STORE_SUBMISSION.md` §8, so the stores
cannot drift from that file. See §10 there for the full set.

For that to work on Android, the Play service account
`claude-play-publisher@nearu-play-publisher.iam.gserviceaccount.com` must be
granted *Release to testing tracks*, *Release to production* and *View app
information* under Play Console → Users and permissions.

---

## 2. Machine matrix

Two Macs are in play and they are not interchangeable.

### Mac A — beta machine (holds the source, `/Volumes/1tbMacSSD`)

| | |
| --- | --- |
| macOS | 27.0 beta (26A5388g), arm64 |
| Xcode | **Xcode-beta 27.0 only** — no stable `Xcode.app` |
| `xcode-select -p` | `/Library/Developer/CommandLineTools` ← **misconfigured** |
| Flutter | 3.44.2 stable · Dart 3.12.2 |
| CocoaPods | 1.16.2 |
| Java | Temurin 25.0.2 LTS |
| Android SDK | 36.0.0 at `/Volumes/1tbMacSSD/GauravStudios/Library/Android/sdk` |
| Android emulators | 1 — `Resizable_Experimental` |
| iOS simulators | 32 devices + iOS runtimes `23F77`, `24A5355p` installed, but **invisible** |
| Store credentials | **Present** — `store-upload-kit/`, `key.properties`, keystore |

Two separate problems here, and they are often confused for one:

- **Simulators do not appear** because `xcode-select` points at Command Line
  Tools, which ships no `simctl` and no Simulator app. The simulators and their
  runtimes are installed and fine — 11 iPads among them. Two ways to fix it:

  ```bash
  # Permanent, needs a password:
  sudo xcode-select --switch /Applications/Xcode-beta.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch

  # Per-process, no sudo — what every build in this session actually used:
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
  export PATH=$REPO/tool/xcode-beta-bin:$PATH
  ```

  The `DEVELOPER_DIR` route is enough for `simctl`, `flutter devices`, and every
  Flutter build including macOS. Add `tool/xcode-beta-bin` to `PATH` alongside
  it: Dart native-asset hooks re-invoke a bare `xcrun`, which would otherwise
  fall back to the misconfigured `xcode-select` mid-build.
- **This machine still cannot submit to the App Store**, even after that fix.
  A build produced by a beta Xcode is rejected with `ITMS-90111`. Simulator
  development and App Store submission are different gates; only Mac B clears
  the second.

### Mac B — stable machine (the iOS release machine)

Fill this in on first use — the exact macOS and Xcode versions matter and are
not known here.

| | |
| --- | --- |
| macOS | _stable, version TBC_ |
| Xcode | _stable, version TBC — this is the whole reason this machine exists_ |
| Store credentials | **Absent until copied by hand** — see §4 |

**Mac B owns:** the iOS archive and upload, TestFlight, and the iPhone/iPad
screenshots. Apple rejects screenshots showing Android UI, so the iOS sets can
only be captured from a simulator or device once an iOS build runs.

**Mac A owns:** everything Android, macOS, and web, plus all the source work.

A third option avoids the split entirely: an Xcode Cloud manifest already exists
at `apps/openpdf_studio/ios/Runner.xcodeproj/xcshareddata/xcodecloud/manifest.json`,
which builds on Apple's stable infrastructure and needs neither Mac.

---

## 3. Recent work and the current working tree

**Landed, but not yet pushed.** `main` is **2 commits ahead of `origin/main`**:

- `32e83b2` — drop AcroForm filling, trim the toolbar to 13 tools
- `0e5986d` — drop form-filling claims from every shipping surface

The AcroForm reasoning is in the code comment: field names are machine names
that mean nothing to a reader, and a `/Btn` field owning several widgets stores
a single value, so ticking one grouped checkbox necessarily clears its siblings.
Free text behaves identically on tagged, flattened and scanned documents.

**Uncommitted, from the 2026-07-23 build session** — the SPM → CocoaPods move
described in §3a, plus new store assets:

| File | Change |
| --- | --- |
| `ios/Podfile.lock` | +100 lines — 1 pod became 37 |
| `ios/Runner.xcodeproj/project.pbxproj` | +36 lines — CocoaPods build phases restored |
| `ios/**/swiftpm/Package.resolved` (×2) | Deleted — correct now, SPM is no longer used |
| `store/graphics/`, `store/screenshots/**` | Feature graphic, icon, reshot Android sets |
| `CLAUDE.md`, `docs/PROJECT_STATE.md` | This handoff pair, still untracked |

### Resolved — the copy was corrected in `0e5986d`

The AcroForm removal shipped, so the listing had to stop advertising it. Every
shipping surface was corrected: `STORE_SUBMISSION.md` §8, the live marketing
page, the privacy page, and `STORE_LISTING_DRAFT.md` — which held a second,
hand-maintained copy of the same paragraphs and had drifted, so it is now just a
pointer at §8.

Fill & Sign itself stays. It fills a form by typing on the page instead of
binding to AcroForm fields, which works identically on scanned and flattened
documents, so the copy leads with that rather than hiding it. The tablet
screenshot `store/screenshots/android-tablet/03-fill-and-sign.png` shows the
sheet the shipping binary actually presents — useful evidence if App Review ever
queries the metadata.

---

## 3a. iOS builds use CocoaPods, not Swift Package Manager

Found and fixed on 2026-07-23. **This affects Mac B and CI, not just Mac A** —
it is a Flutter/plugin packaging problem, nothing to do with which Xcode is
installed, so it reproduces anywhere until the setting below is in place.

With `enable-swift-package-manager` on, `ios/Podfile.lock` carried a single pod
(`onnxruntime`) and the other nine plugins resolved through SPM. Every
ObjC-implemented plugin then failed to link while the pure-Swift ones succeeded,
so `GeneratedPluginRegistrant.m` compiled against classes that were never built:

```
Unknown receiver 'FilePickerPlugin'; did you mean 'FileSaverPlugin'?
Use of undeclared identifier 'IntegrationTestPlugin'
Use of undeclared identifier 'PermissionHandlerPlugin'
```

The split was exact — `file_picker` (4 ObjC files), `permission_handler_apple`
(20) and `integration_test` (3) all failed; `file_saver`, `printing`,
`url_launcher_ios`, `shared_preferences_foundation`,
`flutter_secure_storage_darwin` and `cunning_document_scanner` (0 ObjC files
each) all linked. `integration_test` shows the packaging flaw plainly: its
header sits at `Sources/integration_test/include/IntegrationTestPlugin.h`, but
the registrant imports `<integration_test/IntegrationTestPlugin.h>`, which needs
an `include/integration_test/` directory that does not exist.

The fix, which must be set on every machine that builds iOS:

```bash
flutter config --no-enable-swift-package-manager
rm -rf ios/Pods ios/.symlinks ios/Flutter/ephemeral ios/Podfile.lock
flutter pub get && flutter build ios --simulator --debug
```

Note this is a **global** Flutter setting, not per-project — it changes every
Flutter project on the machine. CocoaPods is Flutter's long-standing default, so
that is normally a non-event, but it is worth knowing before it surprises you.

**`ios/Podfile.lock` is the canary.** It must list ~37 pods. If it lists one,
the project has drifted back onto SPM and iOS will fail exactly as above. Do not
run `flutter clean` to fix an iOS problem — it deletes `build/`, taking the
release APK, AAB, macOS app and web bundle with it; clear only the `ios/` paths
listed above.

---

## 4. Bringing a fresh machine up

```bash
git clone https://github.com/neupanegaurav/QPdf.git
cd QPdf
git lfs pull                      # dist/ and the web wasm are LFS pointers
cd apps/openpdf_studio
flutter pub get
flutter test                      # expect 47 passing
flutter run -d macos              # confirm it runs before anything else
```

Then copy these by hand from Mac A — **none of them are in git, and nothing
signed or published can happen without them**:

| What | Where it goes |
| --- | --- |
| `store-upload-kit/` (whole folder) | repo root, stays untracked |
| `key.properties` | `apps/openpdf_studio/android/` |
| `qpdf-upload-keystore.jks` | `apps/openpdf_studio/android/` |

Move them over an encrypted channel — AirDrop, an encrypted drive, or a password
manager. Not email, not a chat app, and not a commit. They are the live
publishing identity for the whole developer account, not just this app, and the
keystore has no recovery path: lose it and updates to the same Play listing
require a Google key-reset request.

---

## 5. Next actions, in order

Steps 1 and 2 are **browser-only and can only be done by Gaurav** — they need a
sign-in with 2FA and acceptance of developer agreements under his legal
identity. No API can do either. Everything after them runs from the terminal.

1. **Play Console** (`docs/STORE_SUBMISSION.md` §3): create the app record,
   upload `app-release.aab` through the browser once, complete Data safety,
   content rating, target audience and the other declarations from §9, then
   grant `claude-play-publisher@nearu-play-publisher.iam.gserviceaccount.com`
   *Release to testing tracks*, *Release to production* and *View app
   information*. Verify with `publish_play.py check`.
2. **App Store Connect** (§4): create the app record — the bundle ID is already
   registered so the picker will offer it — and answer the age-rating and App
   Privacy questions from §9. Verify with `publish_asc.py check`.
3. Push the Play listing and bundle: `publish_play.py listing --commit`, then
   `publish_play.py bundle ... --commit`. Assets are all produced already.
4. On Mac B: `flutter build ipa --release`, upload, then
   `publish_asc.py metadata --commit`.
5. Capture iPhone 6.9" (1290×2796, portrait) and iPad 13" (2752×2064,
   landscape) on Mac B into `store/screenshots/ios-iphone/` and `ios-ipad/`,
   then `publish_asc.py screenshots --commit`.
6. Back up the keystore off-machine if that has not been done yet.

### Building Apple targets on Mac A

`xcode-select` still points at Command Line Tools, so a bare
`flutter build macos` fails with `xcrun: error: unable to find utility
"xcodebuild"`. Point `DEVELOPER_DIR` at the beta for the one command instead of
switching the whole machine with `sudo`:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  flutter build macos --release
```

This unblocks macOS and simulator builds. It does **not** unblock App Store
submission — a beta-Xcode archive is still rejected with `ITMS-90111`. Only
Mac B clears that gate.

Pair it with `PATH=$REPO/tool/xcode-beta-bin:$PATH` for anything that compiles
Dart native assets: those hooks re-invoke a bare `xcrun`, which would otherwise
drop back to the misconfigured `xcode-select` partway through the build.

### What Mac A can and cannot build

All six verified in one run on 2026-07-23, after the §3a CocoaPods fix:

| Target | Command | Result |
| --- | --- | --- |
| macOS release | `flutter build macos --release` | 51s |
| Android APK release | `flutter build apk --release` | 104 MiB |
| Android AAB release | `flutter build appbundle --release` | 186 MiB |
| Web release (wasm) | `flutter build web --release --wasm` | 5.4 MB wasm |
| iOS simulator debug | `flutter build ios --simulator --debug` | 71s |
| iOS device release | `flutter build ios --release --no-codesign` | 69s |

**Windows and Linux cannot be built on any Mac.** Flutter desktop is
host-native with no cross-compilation, so those two README targets need their
own hosts or CI runners.

The iOS device build is unsigned — it proves the code compiles for arm64
hardware, but it cannot install on a device and is not an App Store artifact.
Both Apple builds also ran with `QPDF_ALLOW_MISSING_DSYM=1`, because Xcode 27
beta's `dsymutil` hangs on Flutter AOT binaries and `tool/xcode-beta-bin/xcrun`
substitutes a stand-in Mach-O. **Those artifacts have no usable dSYMs** — do not
ship them or feed them to a crash reporter. Mac B, on stable Xcode, never sets
the flag and produces real symbol bundles.
