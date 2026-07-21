# Changelog

<!--
═══════════════════════════════════════════════════════════════════════
CHANGELOG STANDARD — read before editing. Applies to both changelogs.
═══════════════════════════════════════════════════════════════════════
Two INDEPENDENT lane changelogs — do NOT mirror one from the other:
  • CHANGELOG.pre.md — the prerelease lane (`## X.Y.Z-dev.N`). Add an
    entry per prerelease you cut on dev.
  • CHANGELOG.md — the stable lane (`## X.Y.Z`). Add an entry per stable
    release, CONSOLIDATING the prerelease entries that ship under it.
They share prose but track their OWN version sequences. There is no
`cp + sed` regen: that mirror falsely assumed every prerelease becomes a
same-numbered stable, so it manufactured stable headings for versions
that never shipped — which `tool/ci/release.sh --check-versions` now flags.
Hand-edit each lane's file directly.

ADDING A VERSION
  Add a heading at the TOP (newest first) of the right lane's file and
  write the summary. Exactly ONE new (untagged) version may sit at the
  top of each file — every heading BELOW it must already have its git tag
  (or a verified `release: no-tag` HTML-comment directive). `--check-versions`
  enforces this at PR + release time: a second un-released version is
  rejected, since it would collapse into the one release the merge cuts.
  Versions, commit lists, tags, publishing — the release tooling owns all
  of it; you only write the human summary.

ENTRY SHAPE
  ## X.Y.Z-dev.0
  <one-line prose lead — only to frame a big release or signal "no
   behavior change"; omit when the bullets speak for themselves>
  - **Breaking:** <what changed> → <migration step, INLINE>   ← always first
  - <upgrade action, e.g. "re-run setup --force web">         ← any required action next
  - Added/Changed <capability or improvement>                ← then improvements
  - Fixed <bug> ([#N](issue-url) reported by [@user](abs-url), [PR #N](abs-url))  ← fixes last

  Order IS the grouping — Breaking → action → added/changed → fixed. No
  `###` subsections: bullet order carries the categories. Only Breaking
  is bold-tagged; everything else is verb-led. Fixes start with "Fixed".

  EXCEPTION — the genesis entry (a ground-up rewrite, no prior version)
  uses facet tags instead of deltas: **Engine:** / **API:** / **I/O:** /
  etc., describing the new package's dimensions. See the 1.0.0 entry.

CONTENT RULES (never change)
  • Migrate from the entry ALONE — breaking changes inline, old → new.
    (pub.dev freezes each version's CHANGELOG as a snapshot, so an entry
    can't rely on anything that later moves.)
  • NEVER link a living doc (README, docs/*) from an entry — it rots when
    the doc moves on. The migration guide is reached from the README.
  • Links point only at IMMUTABLE targets — a PR, commit, or issue:
    ([#N](https://github.com/whuppi/pdf_manipulator/issues/N) reported by
    [@user](https://github.com/user), [PR #N](https://github.com/whuppi/pdf_manipulator/pull/N)).
    Credit the issue + reporter when a reported issue drove the fix; the PR
    (or commit) link alone otherwise.
  • No capability inventories — "what's shipped" lives in README +
    docs/CAPABILITY_ROADMAP.md; the changelog says only what CHANGED.
  • Engine/submodule bump → web re-fetch action (NEVER miss this). When a
    release bumps a vendored engine submodule (vendor/pdf_oxide,
    vendor/office_oxide), the web WASM is rebuilt and consumers must
    re-fetch it, so ALWAYS add the action bullet:
      - Engine updated — web: re-run `flutter pub run pdf_manipulator:setup --force web` (native updates itself)
    Native self-updates via the build hook; only web needs the manual step.
    When cutting a release, diff the submodule pointer against the previous
    tag (`git ls-tree <prev-tag> vendor/pdf_oxide`) so an engine bump never
    ships without the bullet.
═══════════════════════════════════════════════════════════════════════
-->

<!-- Add new versions below, newest first. -->

## 2.1.4


- Engine updated — web: re-run `flutter pub run pdf_manipulator:setup --force web` (native updates itself)
- Fixed `flattenForms` dropping a field's value when the fill and the flatten happen in separate editor sessions — a reopened editor carries no in-session modified-field map, so the flattener now regenerates the appearance from the persisted `/V` (saved alongside `/NeedAppearances`) instead of baking the stale placeholder ([#161](https://github.com/whuppi/pdf_manipulator/issues/161) reported by [@DarkWingMcQuack](https://github.com/DarkWingMcQuack), [PR #162](https://github.com/whuppi/pdf_manipulator/pull/162))
- Fixed `addImageStamp` erasing a page's existing form widgets when the page references its annotations through an indirect `/Annots` reference rather than a direct array ([#161](https://github.com/whuppi/pdf_manipulator/issues/161) reported by [@DarkWingMcQuack](https://github.com/DarkWingMcQuack), [PR #162](https://github.com/whuppi/pdf_manipulator/pull/162))
- Fixed a reopened filled form rendering blank where its value should appear — the renderer now regenerates a widget's appearance from `/V` when the AcroForm sets `/NeedAppearances`, matching the flattener ([PR #162](https://github.com/whuppi/pdf_manipulator/pull/162))

<details><summary>Commits since v2.1.3 (8)</summary>

- b7fdb35 stamp: asset hashes for v2.1.4
- 260091e release: v2.1.4
- 14cd751 chore: promote dev to prod (2.1.4) (#164)
- cefb01f Merge branch 'prod' into dev
- 0f751b1 docs: 2.1.4 — split-session flatten, indirect /Annots stamp, NeedAppearances render (#163)
- 0245950 fix: #161 split-session flatten + indirect /Annots stamp (bump pdf_oxide v0.3.73 / office_oxide v0.1.3) (#162)
- 7dd115d chore: refresh lockfiles (#160)
- 6e7e8fa chore: bump Flutter SDK (#159)

</details>

## 2.1.3


- Engine updated — web: re-run `flutter pub run pdf_manipulator:setup --force web` (native updates itself)
- Fixed `setFormFieldValue` reporting field-not-found on forms whose field names are stored as raw UTF-8 (LibreOffice-class producers) — one spec-tolerant text-string decoder now handles UTF-16BE/LE, UTF-8 with and without BOM, and PDFDocEncoding across every read ([#155](https://github.com/whuppi/pdf_manipulator/issues/155), [PR #156](https://github.com/whuppi/pdf_manipulator/pull/156))
- Fixed `flattenForms` baking mojibake for values outside ASCII (`ß` → `ÃŸ` or `�`) — values decode per ISO 32000-1 §7.9.2.2 and appearance text is written one WinAnsi byte per character instead of UTF-8 ([#155](https://github.com/whuppi/pdf_manipulator/issues/155), [PR #156](https://github.com/whuppi/pdf_manipulator/pull/156))
- Fixed fill → flatten silently dropping the value on widgets without an appearance stream when the field name is non-ASCII — the flattener and the form extractor now agree on how names decode ([#155](https://github.com/whuppi/pdf_manipulator/issues/155), [PR #156](https://github.com/whuppi/pdf_manipulator/pull/156))
- Fixed flattening CJK and emoji values drawing nothing — the bundled fallback font now ships in both native and web builds and is embedded when the field's own font cannot render the text ([#155](https://github.com/whuppi/pdf_manipulator/issues/155), [PR #156](https://github.com/whuppi/pdf_manipulator/pull/156))
- Fixed document metadata (`getTitle` and friends) mangling non-ASCII on read, and metadata writes now encode per spec so other readers see the right text ([#155](https://github.com/whuppi/pdf_manipulator/issues/155), [PR #156](https://github.com/whuppi/pdf_manipulator/pull/156))

<details><summary>Commits since v2.1.2 (7)</summary>

- 6aa4e45 stamp: asset hashes for v2.1.3
- 99c6e61 release: v2.1.3
- cce6645 chore: promote dev to prod (2.1.3) (#158)
- efa47f2 Merge branch 'prod' into dev
- 9ed0c7c docs: 2.1.3 — form text-string encoding fixes (#157)
- 10dee1f chore: bump Flutter SDK (#154)
- fb5ee1f fix: form fill/flatten non-ASCII text handling (ß, umlauts, CJK) (#156)

</details>

## 2.1.2


- Engine updated — web: re-run `flutter pub run pdf_manipulator:setup --force web` (native updates itself)
- Fixed a Flutter Web WASM (`dart2wasm`) compile failure — the `_post` switch over `Object?` was non-exhaustive under dart2wasm (dart2js treats `JSAny` as a catch-all, dart2wasm doesn't), now converted with `jsify()` ([#145](https://github.com/whuppi/pdf_manipulator/issues/145) reported by [@DarkWingMcQuack](https://github.com/DarkWingMcQuack), [PR #146](https://github.com/whuppi/pdf_manipulator/pull/146))
- Fixed pub.dev not advertising Flutter Web support — the web runtime now resolves to a stub default that `pana` can analyze, so the package shows web (dart2js) support ([PR #133](https://github.com/whuppi/pdf_manipulator/pull/133))

<details><summary>Commits since v2.1.1 (31)</summary>

- 99d9159 stamp: asset hashes for v2.1.2
- 398d566 release: v2.1.2
- 9b21629 chore: promote dev to prod (2.1.2) (#153)
- 4f61ed1 Merge branch 'prod' into dev
- ec338d8 ci: bump whuppi/ci to v2.0.4 (#151)
- 8ae80af ci: bump whuppi/ci to v2.0.3 (#150)
- 6c267f8 ci: bump whuppi/ci to v2.0.2 (#149)
- 711055d ci: bump whuppi/ci to v2.0.1 (#148)
- f8fdf61 docs: 2.1.2 — dart2wasm web fix + web platform on pub.dev (#147)
- 7c0e15a fix: dart2wasm web build; adopt whuppi/ci v2.0.0 dual-compiler gate (#146)
- 6fc0ec3 chore: adopt whuppi/ci v1.0.8 (#144)
- f724639 build: adopt the shared platforms gate + shell lint (#142)
- f237ade ci: align dependabot/labels/upgrade-body with the workspace shape (#141)
- 6fe4598 chore: bump pinned versions (#139)
- f05ed54 build: shared strict analyze gate + whuppi/ci pin bump to v1.0.6 (#140)
- a98a69f docs: fix stale branch-protection recipe (#138)
- aa20ef0 ci: bump whuppi/ci shared refs to v1.0.4 (#137)
- 1614841 ci: migrate onto the shared whuppi/ci`@v1`.0.1 (#136)
- 79dc1f8 chore: bump pinned versions (#134)
- ffb3048 fix: show web platform support on pub.dev (stub-default seam) + pana platform gate (#133)
- ed305ea chore: bump pinned versions (#130)
- a82d751 chore: refresh lockfiles (#131)
- 1ccf266 fix(ci): resolve fvm on windows via native fvm.exe, not a .bat shim (#132)
- 657804e chore: promote dev to prod (#129)
- 9af712c Merge branch 'prod' into dev
- af178e9 fix(ci): refresh the example lockfile with flutter, not dart (#128)
- 9a8f5d0 chore: bump pinned versions (#127)
- 21368ff chore: refresh lockfiles (#125)
- cce4135 ci: verify the dependency floor compiles (analyze on oldest deps) (#126)
- 464f06c chore: bump pinned versions (#124)
- 0a58c7b ci: gate .gitmodules to the owner (#123)

</details>

## 2.1.1


- Fixed the README banner not rendering on pub.dev — the `<picture>` element is flattened to a plain image in the published package ([PR #111](https://github.com/whuppi/pdf_manipulator/pull/111))

<details><summary>Commits since v2.1.0 (14)</summary>

- 655a804 stamp: asset hashes for v2.1.1
- ae38450 release: v2.1.1
- 7295a0e chore: promote dev to prod (2.1.1) (#122)
- e9c3bd5 Merge branch 'prod' into dev
- 3ac56cb ci: unblock the release pipeline + supply-chain & workflow hardening (#121)
- 8c63ea2 chore: promote dev to prod (2.1.1) (#119)
- cd4f499 Merge branch 'prod' into dev
- c9ef5d0 fix(ci): re-supply git push auth in release.sh (#120)
- 2724150 docs: add 2.1.1 changelog entry for the README fix (#118)
- 16d2241 ci: declare repo labels as code with a sync workflow (#117)
- dc1037d ci: harden CI to zizmor-auditor zero with a supply-chain SSOT (#113)
- 441ec72 ci: bump actions/stale from 9 to 10 in the actions group (#114)
- 2dde3f0 ci: auto-close resolved issues with an opt-out guard (#112)
- 3dbae4e ci: flatten README <picture> banner for the pub.dev tarball (#111)

</details>

## 2.1.0


- Engine updated — web: re-run `flutter pub run pdf_manipulator:setup --force web` (native updates itself)
- Added document producer and creation-date metadata — `PdfEditor.setProducer()` / `getProducer()` and `setCreationDate()` / `getCreationDate()` (raw PDF date strings, e.g. `D:20240101120000Z`), plus `PdfDoc.producer`, `PdfDoc.creator`, and `PdfDoc.creationDate` read on open
- Fixed `addImageStamp` rendering a transparent-background PNG as a solid black box — the alpha channel now ships as a grayscale `/SMask` and the PNG predictor params are preserved, so transparent areas reveal the page instead of painting black ([#103](https://github.com/whuppi/pdf_manipulator/issues/103) reported by [@DarkWingMcQuack](https://github.com/DarkWingMcQuack), [PR #104](https://github.com/whuppi/pdf_manipulator/pull/104))
- Fixed the `RenderedPage.data` doc — `render()` returns PNG-encoded bytes (decode to read pixels), not raw RGBA ([PR #104](https://github.com/whuppi/pdf_manipulator/pull/104))

<details><summary>Commits since v2.0.1 (11)</summary>

- 5f06717 stamp: asset hashes for v2.1.0
- cefb51e release: v2.1.0
- f8c7bf1 chore: promote dev to prod (#109)
- 4bb7149 ci: add changelog version check (#110)
- 779495f Merge branch 'prod' into dev
- 2b5c35e feat: add producer and creation-date document metadata (#108)
- cc837da docs: changelog 2.0.2 — addImageStamp PNG transparency fix (#107)
- 5392e95 ci: bump actions/checkout from 6 to 7 in the actions group across 1 directory (#106)
- eb15b4d fix: addImageStamp preserves PNG transparency (no black box) (#104)
- 271c1d5 ci: vendored-engine cargo tests + consistent job names (#105)
- 0d623bf ci: bump actions/labeler from 5 to 6 in the actions group (#102)

</details>

## 2.0.1


Docs-only — no code or API changes.

- README and every guide (architecture, capabilities, migration, updating, contributing) rewritten, restructured, and verified against the source

<details><summary>Commits since v2.0.0 (6)</summary>

- 9afea02 stamp: asset hashes for v2.0.1
- a393f2b release: v2.0.1
- 15ea53a chore: promote dev to prod (2.0.1) (#101)
- 8a41292 Merge branch 'prod' into dev
- 9786314 feat: pdf_manipulator/io.dart + README & docs polish (#100)
- c59fd4a chore: bump Flutter 3.44.1 → 3.44.2 (#98)

</details>

## 2.0.0


The concurrency rewrite. Every operation now runs fully isolated on its
own *lane* — a dedicated Rust thread (native) or Web Worker (web).

- **Breaking:** `webCoordinatorUrl` + `webWorkerUrl` → one `webLaneWorkerUrl`
- **Breaking:** web now ships `lane_worker.js` (was `coordinator.js` + `worker.js`)
- Engine updated — web: re-run `flutter pub run pdf_manipulator:setup --force web` (native updates itself)
- Every method returns `PdfTask<T>` — a `Future` plus `cancel()`; cancelling kills just that job
- `pdf.dispose()` is instant — no joins, no timeouts, no leaks; in-flight ops resolve with `PdfCancelled`
- Operations on different handles now run truly parallel on native (1.x serialized them)
- Lane budgets never error — past the cap, work queues instead of failing
- Added `PdfConfig.maxLanes` — concurrent lanes per instance (default: half the cores, min 2)
- All three web modes (JSPI, Atomics, OPFS) behave identically; a bad worker/WASM URL now fails instantly with a typed error instead of hanging
- Fixed flattening — translated appearances no longer land off-page, unfilled fields render their default value, stamps render their label
- Fixed missing WASM binaries in the 1.0.6 release
- Fixed Android 16 KB page-size alignment for Google Play API 35+ ([PR whuppi/pdf_oxide#1](https://github.com/whuppi/pdf_oxide/pull/1), [@Binary-Parse](https://github.com/Binary-Parse))

<details><summary>Commits since v1.0.6 (9)</summary>

- ad1cb65 stamp: asset hashes for v2.0.0
- e8134c3 release: v2.0.0
- 60e4200 chore: promote dev to prod (1.0.7) (#92)
- b3d1823 feat: lane runtime rewrite + test, docs & CI overhaul (#97)
- e202281 fix: release gate tag-check fallback for workflow_dispatch (#93)
- d031a96 Merge branch 'prod' into dev
- fb93efa feat: 16 KB Android page-size alignment (vendor/pdf_oxide update) (#91)
- 78dfd87 fix(ci): WASM release assets + binary verification gate (#89)
- 0091e99 fix(ci): WASM artifacts missing from releases + binary verification

</details>

## 1.0.6


- Fixed release build routing for consumer builds ([PR #80](https://github.com/whuppi/pdf_manipulator/pull/80), [@Binary-Parse](https://github.com/Binary-Parse))
- Fixed Windows NDK linker `.cmd` extension for Android cross-compilation ([PR #81](https://github.com/whuppi/pdf_manipulator/pull/81), [@Binary-Parse](https://github.com/Binary-Parse))
- Added CI verify tests — release builds now verified on all 6 targets (Android, iOS, macOS, Linux, Windows, Web)

<details><summary>Commits since v1.0.5 (9)</summary>

- f53de02 stamp: asset hashes for v1.0.6
- 9ea4073 release: v1.0.6
- c8ff236 chore: promote dev to prod (#88)
- cc4f9b8 Merge branch 'prod' into dev
- 0679c51 chore: add 1.0.6 changelog entries (#86)
- ce9d7ec fix(ci): release gate only triggers on new changelog versions (#85)
- 5083450 refactor(ci): capability-based architecture + verify release builds (#82)
- 0132518 fix(hook): append .cmd to the NDK clang linker on Windows hosts (Android cross-compile fails) (#81)
- 453b39e fix(hook): add link.dart passthrough, build.json, release-build tests (#80)

</details>

## 1.0.5


- Fixed README version not stamped on pub.dev
- Updated tracking links for web build hook support

<details><summary>Commits since v1.0.4 (4)</summary>

- 8d3e363 stamp: asset hashes for v1.0.5
- 86ade5b release: v1.0.5
- 1288d12 chore: promote dev to prod (#79)
- 694c96e chore: 1.0.5 release — fix README stamp + tracking links (#78)

</details>

## 1.0.4


- Web setup now verifies all assets against release hashes — detects stale files automatically
- `setup` supports `--force` to re-download everything, `--native` to pre-fetch the native binary

<details><summary>Commits since v1.0.3 (6)</summary>

- 902cf4f stamp: asset hashes for v1.0.4
- d1266fb release: v1.0.4
- 5cd981f chore: promote dev to prod (#77)
- cdabb02 Merge branch 'prod' into dev
- 8dbad3b chore: add 1.0.4 changelog entries (#76)
- d912aa1 feat: unified asset resolver — same waterfall for native and web (#75)

</details>

## 1.0.3


- Fixed changelog on pub.dev

<details><summary>Commits since v1.0.2 (10)</summary>

- 6bbaaa8 stamp: asset hashes for v1.0.3
- 1339dc4 release: v1.0.3
- 9b228dc chore: promote dev to prod (#73)
- 223c1a4 Merge branch 'prod' into dev
- 3e0ebd8 chore: add 1.0.3 changelog entries (#72)
- 6a33c47 chore: promote dev to prod (#71)
- 77c8738 feat(ci): preview filtered changelog in CI logs before publish approval (#70)
- c7ffae8 docs: move slopfairy manual comments to workspace rule
- d4471ac docs: add slopfairy manual comments + changelog preview recipes
- ab0a74e fix(ci): same-file read-write race in stamp-changelog + bash 3.2 compat

</details>

## 1.0.2


- Fixed changelog on pub.dev missing commit history between versions

<details><summary>Commits since v1.0.1 (10)</summary>

- e420ba0 stamp: asset hashes for v1.0.2
- 1154d43 release: v1.0.2
- 0b610c0 fix(ci): edit asset_hashes.dart between markers instead of overwriting
- 91bd9ad fix(ci): add doc comment to generated asset_hashes.dart constant
- bd78225 fix(ci): version-scoped staging branch + updated UPDATING.md
- eb2e822 fix(ci): delete stale _release-staging before push to avoid lock conflicts
- 6990128 fix(ci): fall back to HEAD when tag doesn't exist yet in commits_collapsible
- 0ddc9ce fix(ci): correct repo fallback to whuppi/pdf_manipulator
- 83b44cb feat(ci): rewrite release pipeline — single release.sh, changelog builder, idempotent (#68)
- 392aaa8 fix(ci): version-level release concurrency + branch-file gate (#67)

</details>

## 1.0.1


- Added public API doc comments across all exported classes and methods
- Minimum Android API corrected from 35 to 21 (Android 5.0)
- Setup command is now `flutter pub run pdf_manipulator:setup` (avoids triggering native build hooks with `dart run`)

<details><summary>Commits since v1.0.0 (48)</summary>

- 4ed5b3b release: v1.0.1
- 722b2dd chore: add 1.0.1 changelog entry (#65)
- d04b556 chore: add 1.0.1-dev.0 prerelease changelog entry (#64)
- 52b6d52 ci: bump the actions group across 1 directory with 5 updates (#57)
- 9c798ee fix(ci): notify maintainer to recreate dependabot PRs on new pushes
- 4ade698 docs: explain Windows DLL lock in dispose test (#60)
- e8dee7b fix: analyzer clean + web CI + native dispose safety
- ea9c961 ci: write bore port to artifact for API access
- 88197b4 ci: split setup/keepalive steps so SSH port shows immediately
- 07749ec ci: fix bore version (0.6.0), serveo was dead
- 4b4d6e5 ci: raw sshd + serveo.net tunnel (no binary downloads)
- 4a4bd3a ci: raw sshd + bore tunnel, no tmate, 5hr timeout
- 015b951 ci: update debug-ssh workflow
- 5b71adf ci: add debug-ssh workflow for interactive CI debugging
- 5874c1a chore: bump Flutter 3.44.0 → 3.44.1 (#50)
- a26b3c2 chore: add Dependabot for GitHub Actions updates (#56)
- 684b840 docs: fix rendering + add fvmrc pinning section (#54)
- c06e2d9 fix: flutter-upgrade PRs created as draft (#53)
- 9d18776 fix: slopfairy PR#51 suggestions — printf credentials + remove redundant gitignore (#52)
- a548f42 feat: secrets.sh + per-env pub.dev credentials (#51)
- 8ac73ea fix: add vendor false_secrets at stamp-tag time (#49)
- 53c52aa fix: force-add Cargo.lock in stamp-tag (gitignored in vendor) (#48)
- cbae62b fix: auto-detect wasm-bindgen-cli version from Cargo.lock (#47)
- 3e4e5f6 fix: force-push temp branch + stale comment refs (#46)
- 81a789f fix: push stamped commit before creating release tag (#45)
- 90617d2 fix: mode guard was rejecting --github-notes (#44)
- a07b935 fix: install snippets on release, generic version, cancel-in-progress (#43)
- 8b4387f feat: unified release pipeline with approval gate (#42)
- 7b1fac9 fix: move asset_hashes.dart to lib/src/hook/ (#41)
- 7637a29 fix: false_secrets for test PEM keys + pin example .fvmrc (#40)
- b16ccc4 fix: single stamp_release.sh for all pre-publish stamping (#39)
- 51c845b fix: API-based asset hashes, MSVC-first Windows, git identity (#38)
- 6d44016 fix: publish fails on dirty git + create-release YAML syntax (#36)
- 5909946 fix: YAML syntax error in create-release.yml (#35)
- ab2e79f fix: auto-generate commit lists + asset hashes at publish time (#34)
- 6adbed3 docs: add rebuild-release recovery flow to UPDATING.md (#33)
- 193c460 fix: compile per-platform — CI builds only the targets it installed (#32)
- f874171 fix: add validation gate to publish.yml (#31)
- 8da554d fix: quote YAML expression in publish.yml (#30)
- 7fc4ae6 fix: publish.yml errors on branch push — replace all bare inputs.tag (#29)
- d5630a0 docs: fix UPDATING.md release section — correct workflow names, document auto-trigger chain
- 2d6d65c fix: publish.yml fails on branch push due to inputs.tag in concurrency
- 26ce093 feat!: cross-platform Rust engine, streaming I/O, web WASM (#28)
- 7456369 chore: rename main → prod (workflows, docs, ruleset) (#26)
- 8dcc13f ci: commit-msg hook (merge blocker + printf), promotion-check, hooksPath docs (#23)
- 074868f ci: fix release-please config and PR formatting (#21)
- 945a51f ci: add release-please + tag-triggered release pipeline (#19)
- e5e698e ci: enforce conventional commits via hook + PR title check (#17)

</details>

## 1.0.0


Complete ground-up rewrite — new Rust engine, new instance API, cross-platform (previously Android only). The package docs carry the migration guide and the full capability list.

- **Engine:** pdf_oxide (Rust, MIT/Apache-2.0) replaces the Android-only backend
- **Targets:** iOS, Android, macOS, Windows, Linux, Web — previously Android only
- **API:** instance-based `Pdf()` with `dispose()`; batch editing via `pdf.edit(source)`, create from scratch via `pdf.build()`
- **I/O:** `DataSource` in, `DataSink` out — no file paths, no `dart:io`, same code on every target
- **Errors:** typed `PdfError` sealed class — no more `PlatformException`
- **Performance:** every operation off the main thread, no full-file buffers
- **SDK:** requires Dart >=3.10.0

## 0.5.9


- The last release of Android-only version before the cross-platform rewrite.

<details><summary>Commits since initial (223)</summary>

- b7fdb35 stamp: asset hashes for v2.1.4
- 260091e release: v2.1.4
- 14cd751 chore: promote dev to prod (2.1.4) (#164)
- cefb01f Merge branch 'prod' into dev
- 0f751b1 docs: 2.1.4 — split-session flatten, indirect /Annots stamp, NeedAppearances render (#163)
- 0245950 fix: #161 split-session flatten + indirect /Annots stamp (bump pdf_oxide v0.3.73 / office_oxide v0.1.3) (#162)
- 7dd115d chore: refresh lockfiles (#160)
- 6e7e8fa chore: bump Flutter SDK (#159)
- cce6645 chore: promote dev to prod (2.1.3) (#158)
- efa47f2 Merge branch 'prod' into dev
- 9ed0c7c docs: 2.1.3 — form text-string encoding fixes (#157)
- 10dee1f chore: bump Flutter SDK (#154)
- fb5ee1f fix: form fill/flatten non-ASCII text handling (ß, umlauts, CJK) (#156)
- 9b21629 chore: promote dev to prod (2.1.2) (#153)
- 4f61ed1 Merge branch 'prod' into dev
- ec338d8 ci: bump whuppi/ci to v2.0.4 (#151)
- 8ae80af ci: bump whuppi/ci to v2.0.3 (#150)
- 6c267f8 ci: bump whuppi/ci to v2.0.2 (#149)
- 711055d ci: bump whuppi/ci to v2.0.1 (#148)
- f8fdf61 docs: 2.1.2 — dart2wasm web fix + web platform on pub.dev (#147)
- 7c0e15a fix: dart2wasm web build; adopt whuppi/ci v2.0.0 dual-compiler gate (#146)
- 6fc0ec3 chore: adopt whuppi/ci v1.0.8 (#144)
- f724639 build: adopt the shared platforms gate + shell lint (#142)
- f237ade ci: align dependabot/labels/upgrade-body with the workspace shape (#141)
- 6fe4598 chore: bump pinned versions (#139)
- f05ed54 build: shared strict analyze gate + whuppi/ci pin bump to v1.0.6 (#140)
- a98a69f docs: fix stale branch-protection recipe (#138)
- aa20ef0 ci: bump whuppi/ci shared refs to v1.0.4 (#137)
- 1614841 ci: migrate onto the shared whuppi/ci`@v1`.0.1 (#136)
- 79dc1f8 chore: bump pinned versions (#134)
- ffb3048 fix: show web platform support on pub.dev (stub-default seam) + pana platform gate (#133)
- ed305ea chore: bump pinned versions (#130)
- a82d751 chore: refresh lockfiles (#131)
- 1ccf266 fix(ci): resolve fvm on windows via native fvm.exe, not a .bat shim (#132)
- 657804e chore: promote dev to prod (#129)
- 9af712c Merge branch 'prod' into dev
- af178e9 fix(ci): refresh the example lockfile with flutter, not dart (#128)
- 9a8f5d0 chore: bump pinned versions (#127)
- 21368ff chore: refresh lockfiles (#125)
- cce4135 ci: verify the dependency floor compiles (analyze on oldest deps) (#126)
- 464f06c chore: bump pinned versions (#124)
- 0a58c7b ci: gate .gitmodules to the owner (#123)
- 7295a0e chore: promote dev to prod (2.1.1) (#122)
- e9c3bd5 Merge branch 'prod' into dev
- 3ac56cb ci: unblock the release pipeline + supply-chain & workflow hardening (#121)
- 8c63ea2 chore: promote dev to prod (2.1.1) (#119)
- cd4f499 Merge branch 'prod' into dev
- c9ef5d0 fix(ci): re-supply git push auth in release.sh (#120)
- 2724150 docs: add 2.1.1 changelog entry for the README fix (#118)
- 16d2241 ci: declare repo labels as code with a sync workflow (#117)
- dc1037d ci: harden CI to zizmor-auditor zero with a supply-chain SSOT (#113)
- 441ec72 ci: bump actions/stale from 9 to 10 in the actions group (#114)
- 2dde3f0 ci: auto-close resolved issues with an opt-out guard (#112)
- 3dbae4e ci: flatten README <picture> banner for the pub.dev tarball (#111)
- f8c7bf1 chore: promote dev to prod (#109)
- 4bb7149 ci: add changelog version check (#110)
- 779495f Merge branch 'prod' into dev
- 2b5c35e feat: add producer and creation-date document metadata (#108)
- cc837da docs: changelog 2.0.2 — addImageStamp PNG transparency fix (#107)
- 5392e95 ci: bump actions/checkout from 6 to 7 in the actions group across 1 directory (#106)
- eb15b4d fix: addImageStamp preserves PNG transparency (no black box) (#104)
- 271c1d5 ci: vendored-engine cargo tests + consistent job names (#105)
- 0d623bf ci: bump actions/labeler from 5 to 6 in the actions group (#102)
- 15ea53a chore: promote dev to prod (2.0.1) (#101)
- 8a41292 Merge branch 'prod' into dev
- 9786314 feat: pdf_manipulator/io.dart + README & docs polish (#100)
- c59fd4a chore: bump Flutter 3.44.1 → 3.44.2 (#98)
- 60e4200 chore: promote dev to prod (1.0.7) (#92)
- b3d1823 feat: lane runtime rewrite + test, docs & CI overhaul (#97)
- e202281 fix: release gate tag-check fallback for workflow_dispatch (#93)
- d031a96 Merge branch 'prod' into dev
- fb93efa feat: 16 KB Android page-size alignment (vendor/pdf_oxide update) (#91)
- 78dfd87 fix(ci): WASM release assets + binary verification gate (#89)
- 0091e99 fix(ci): WASM artifacts missing from releases + binary verification
- c8ff236 chore: promote dev to prod (#88)
- cc4f9b8 Merge branch 'prod' into dev
- 0679c51 chore: add 1.0.6 changelog entries (#86)
- ce9d7ec fix(ci): release gate only triggers on new changelog versions (#85)
- 5083450 refactor(ci): capability-based architecture + verify release builds (#82)
- 0132518 fix(hook): append .cmd to the NDK clang linker on Windows hosts (Android cross-compile fails) (#81)
- 453b39e fix(hook): add link.dart passthrough, build.json, release-build tests (#80)
- 1288d12 chore: promote dev to prod (#79)
- 694c96e chore: 1.0.5 release — fix README stamp + tracking links (#78)
- 5cd981f chore: promote dev to prod (#77)
- cdabb02 Merge branch 'prod' into dev
- 8dbad3b chore: add 1.0.4 changelog entries (#76)
- d912aa1 feat: unified asset resolver — same waterfall for native and web (#75)
- 9b228dc chore: promote dev to prod (#73)
- 223c1a4 Merge branch 'prod' into dev
- 3e0ebd8 chore: add 1.0.3 changelog entries (#72)
- 6a33c47 chore: promote dev to prod (#71)
- 77c8738 feat(ci): preview filtered changelog in CI logs before publish approval (#70)
- c7ffae8 docs: move slopfairy manual comments to workspace rule
- d4471ac docs: add slopfairy manual comments + changelog preview recipes
- ab0a74e fix(ci): same-file read-write race in stamp-changelog + bash 3.2 compat
- 0b610c0 fix(ci): edit asset_hashes.dart between markers instead of overwriting
- 91bd9ad fix(ci): add doc comment to generated asset_hashes.dart constant
- bd78225 fix(ci): version-scoped staging branch + updated UPDATING.md
- eb2e822 fix(ci): delete stale _release-staging before push to avoid lock conflicts
- 6990128 fix(ci): fall back to HEAD when tag doesn't exist yet in commits_collapsible
- 0ddc9ce fix(ci): correct repo fallback to whuppi/pdf_manipulator
- 83b44cb feat(ci): rewrite release pipeline — single release.sh, changelog builder, idempotent (#68)
- 392aaa8 fix(ci): version-level release concurrency + branch-file gate (#67)
- 722b2dd chore: add 1.0.1 changelog entry (#65)
- d04b556 chore: add 1.0.1-dev.0 prerelease changelog entry (#64)
- 52b6d52 ci: bump the actions group across 1 directory with 5 updates (#57)
- 9c798ee fix(ci): notify maintainer to recreate dependabot PRs on new pushes
- 4ade698 docs: explain Windows DLL lock in dispose test (#60)
- e8dee7b fix: analyzer clean + web CI + native dispose safety
- ea9c961 ci: write bore port to artifact for API access
- 88197b4 ci: split setup/keepalive steps so SSH port shows immediately
- 07749ec ci: fix bore version (0.6.0), serveo was dead
- 4b4d6e5 ci: raw sshd + serveo.net tunnel (no binary downloads)
- 4a4bd3a ci: raw sshd + bore tunnel, no tmate, 5hr timeout
- 015b951 ci: update debug-ssh workflow
- 5b71adf ci: add debug-ssh workflow for interactive CI debugging
- 5874c1a chore: bump Flutter 3.44.0 → 3.44.1 (#50)
- a26b3c2 chore: add Dependabot for GitHub Actions updates (#56)
- 684b840 docs: fix rendering + add fvmrc pinning section (#54)
- c06e2d9 fix: flutter-upgrade PRs created as draft (#53)
- 9d18776 fix: slopfairy PR#51 suggestions — printf credentials + remove redundant gitignore (#52)
- a548f42 feat: secrets.sh + per-env pub.dev credentials (#51)
- 8ac73ea fix: add vendor false_secrets at stamp-tag time (#49)
- 53c52aa fix: force-add Cargo.lock in stamp-tag (gitignored in vendor) (#48)
- cbae62b fix: auto-detect wasm-bindgen-cli version from Cargo.lock (#47)
- 3e4e5f6 fix: force-push temp branch + stale comment refs (#46)
- 81a789f fix: push stamped commit before creating release tag (#45)
- 90617d2 fix: mode guard was rejecting --github-notes (#44)
- a07b935 fix: install snippets on release, generic version, cancel-in-progress (#43)
- 8b4387f feat: unified release pipeline with approval gate (#42)
- 7b1fac9 fix: move asset_hashes.dart to lib/src/hook/ (#41)
- 7637a29 fix: false_secrets for test PEM keys + pin example .fvmrc (#40)
- b16ccc4 fix: single stamp_release.sh for all pre-publish stamping (#39)
- 51c845b fix: API-based asset hashes, MSVC-first Windows, git identity (#38)
- 6d44016 fix: publish fails on dirty git + create-release YAML syntax (#36)
- 5909946 fix: YAML syntax error in create-release.yml (#35)
- ab2e79f fix: auto-generate commit lists + asset hashes at publish time (#34)
- 6adbed3 docs: add rebuild-release recovery flow to UPDATING.md (#33)
- 193c460 fix: compile per-platform — CI builds only the targets it installed (#32)
- f874171 fix: add validation gate to publish.yml (#31)
- 8da554d fix: quote YAML expression in publish.yml (#30)
- 7fc4ae6 fix: publish.yml errors on branch push — replace all bare inputs.tag (#29)
- d5630a0 docs: fix UPDATING.md release section — correct workflow names, document auto-trigger chain
- 2d6d65c fix: publish.yml fails on branch push due to inputs.tag in concurrency
- 26ce093 feat!: cross-platform Rust engine, streaming I/O, web WASM (#28)
- 7456369 chore: rename main → prod (workflows, docs, ruleset) (#26)
- 8dcc13f ci: commit-msg hook (merge blocker + printf), promotion-check, hooksPath docs (#23)
- 074868f ci: fix release-please config and PR formatting (#21)
- 945a51f ci: add release-please + tag-triggered release pipeline (#19)
- e5e698e ci: enforce conventional commits via hook + PR title check (#17)
- 67edc60 add pre-commit hook: reject commits with gitignored files
- da16d8a untrack example/pubspec.lock (gitignored, should never have been tracked)
- 9a3dc68 fix: .pubignore for vendor/ + compile WASM before web tests
- 02e92a5 fix(ci): checkout in workflows before local composite actions
- 55d9e58 ci: 10 composite actions, zero duplication, test-first flow
- e6bf54b release: manual re-trigger + overwrite existing releases
- 9328919 ci: split WASM into its own compile job
- dfcd65f fix: WASM target + Rust warnings in release CI
- 2dbb00e hook: rewrite using native_toolchain_rust patterns
- 28daa58 hook: use StaticLinking for iOS + install both device and sim targets
- c8f4bfe hook: set NDK linker for Android cargo cross-compilation
- 4e72a4a ci: add x86_64-linux-android rust target for Android emulator tests
- c9c26ab ci: fix android emulator-runner cd not persisting between commands
- eef11c8 ci: commit .metadata, remove destructive flutter create
- f144ba5 ci: fix Android + iOS integration test failures
- 6b9e7d7 updating.md: add submodule commit discipline (3-step sequence)
- bf50a39 submodule: update to include all Rust patches
- 8fcec5f ci: fix pub get failure — skip example deps in Dart-only jobs
- a62a36b roadmap: add upstream v0.3.48 office conversion features
- 621f091 fix upstream URL + expand S1 bump recipe
- 8e67064 provenance: link to fork repo + branch, document fork convention
- b93b9ec v1.0.0 API redesign + web feature parity + doc cleanup
- e7e0338 editor: add missing addStamp + addWatermarkPositioned wrappers
- 4ba4264 fix migration guide + expand contributing
- 0374c59 readme: feature×platform matrix, docs table, community files
- c0e712c bump to 1.0.0, fix stale README references
- 581e844 v1.0.0 — complete ground-up rewrite
- a99fbdb Make plugin compatible with Gradle 8+ while keeping support for older versions
- 4a0102b Update issue templates
- 257bc10 Update issue templates
- 9dc0251 * Fixed error "Build file '\pdf_manipulator\android\build.gradle' should not contain a package statement".
- 8d17db2 * Attempts to fix "x + width must be <= bitmap.width()" exception on some devices in some case of PDF compressing. * Updated documentation regarding PlatformException in Release build: AbstractITextEvent is only for internal usage [#2](https://github.com/chaudharydeepanshu/pdf_manipulator/issues/2).
- 8e7c094 Update README.md
- 51a54b6 Update README.md
- 939c73f Update README.md
- bbf346f Update README.md
- ad48def Update README.md
- 51eac08 * Updated pub version.
- 5531a95 * Updated dependency.
- 4a787c1 * Pub version update.
- 2a40976 Merge remote-tracking branch 'origin/master'
- bd9155e * Added new description.
- 30ab01b Update README.md
- 2603470 * Updated documentation. * Improved example app.
- bf5ca20 Merge branch 'master' of https://github.com/chaudharydeepanshu/pdf_manipulator
- 083f86c Update README.md
- aab073a Merge branch 'master' of https://github.com/chaudharydeepanshu/pdf_manipulator
- c8b771e Create LICENSE
- 76e31b2 Update README.md
- 64d4388 * Fixes crash on `pdfCompressor` with `unEmbedFonts` set true for some pdfs.
- bcf78e3 * Removed unnecessary catch blocks.
- dc681b6 * Now `pdfDecryption` finishes with error on BadPasswordException and PdfException.
- 22e58a9 * Fixed `imagesToPdfs` method not working for absolute file paths of files with names containing `:`.
- 0d0a83f * Fixed `imagesToPdfs` method not working for android absolute file paths.
- a31774e * Fixed `imagesToPdfs` method not working for android uris. * Fixed `imagesToPdfs` adding unnecessary padding to pdfs when `createSinglePdf` is set to false or default. * Updated example and example dependency.
- 1dea7a8 * Added `imagesToPdfs` method for converting images to single pdf or multiple pdfs.
- c21c1f1 * Added `pdfEncryption` method for pdf encryption. * Added `pdfDecryption` method for pdf decryption. * Added `pdfValidityAndProtection` method for getting pdf validity and protection info.
- c28db0a * Fixed `pdfPagesSize` method OOM issue also removed redundant properties.
- 81ae92c * Added `positionType` in `pdfWatermark` method which provides various predefined and allows providing custom watermark positions.` * Added `pdfPagesSize` method for getting size info of pages of pdf. * Added `customPositionXCoordinatesList`, `customPositionYCoordinatesList` in `pdfWatermark` method for more fine controlling of watermark position.
- 18a5dc9 * Added `pdfWatermark` method for watermarking pdf.
- 6886f97 * Added `unEmbedFonts` for `pdfCompressor`.
- c192813 * Added `pdfCompressor` method for compressing pdf.
- 48df0f6 * `pdfUri` is replaced with `pdfPath` as now `pdfPath` is capable of taking care both URI path and absolute file path. * `pdfsUris` is replaced with `pdfsPaths` as now `pdfsPaths` is capable of taking care both URI paths and absolute file paths. * Fixed issue of not being able to use absolute file paths. * Flushing pdfWriters when splitting documents for trying to fix OOfM error in some cases.
- db77334 * Support for rotating, deleting and reordering pdf pages. * Fixes OOfM error in some cases. * Fixes few errors in splitting by byte size.
- 439b37d new pub.dev version
- dcd3568 typo fix
- 42ea493 dependencies updated
- b4143c9 Update README.md
- cb740ed Update LICENSE
- 1bb42a3 Update README.md
- 87a7c36 added pdf page deleter functionality
- 90aff66 added other split pdf functions
- d903a62 Initial commit

</details>

