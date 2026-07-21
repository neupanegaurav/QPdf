# QPdf Phase C4.5 status

Updated: 2026-07-21

## Outcome

Generic interactive fields can now receive conservative, coordinate-derived
label suggestions from text already printed next to their PDF widgets. Every
suggestion is visibly marked with confidence and remains editable before any
value is populated. Ambiguous fields stay generic.

## Safety boundary

- Producer tooltips and meaningful field names remain authoritative.
- Recovery runs only for fields already classified as generic fallbacks.
- It uses widget rectangles, widget page ownership, and positioned page text.
- Labels must satisfy an 84% confidence threshold and strict distance,
  orientation, length, and instruction-text filters.
- On-device language models are disabled for partial/XFA forms, so model output
  cannot override coordinate evidence or compatibility warnings.
- Editing a suggested display label never changes the authoritative field name,
  field coordinates, control type, current value, or save target.
- Population still requires the existing **Populate fields** confirmation.

## Official-form result

The checksum-pinned IRS W-9 has 23 generic producer fields. QPdf recovers 21
high-confidence suggestions and intentionally leaves two ambiguous fields with
generic labels. Examples include:

| Field | Suggested label | Confidence |
| --- | --- | ---: |
| `f1_01` | Name of entity/individual | 95% |
| `f1_02` | Business name/disregarded entity name, if different from above | 95% |
| first `c1_1` | Individual/sole proprietor | 95% |
| second `c1_1` | C corporation | 95% |

The compatibility report now records recovered counts, examples, confidence,
and stable verification-output filenames at
`output/pdf/c4-real-world/compatibility-report.json`.

## Verification

- Flutter analysis is clean and all 83 application tests pass.
- A blank generic field proves that absent nearby text remains unrecovered.
- The official W-9 regression pins the 21 recovered / 2 generic boundary.
- A widget test opens the real W-9, verifies the XFA warning, confidence text,
  review control, and propagation of an edited display label.
- W-9, I-9, and VA verification copies preserve a synthetic value through
  QPdf save/reopen and render cleanly through Poppler.
- Chrome/PDFium independently loads the six-page saved W-9 and visually shows
  the populated value without clipping.
- Preview launches the saved W-9, but its accessibility capture timed out, so a
  complete Preview visual-interaction pass is not claimed. Acrobat is not
  installed on this host.
- Fresh Android debug, JavaScript web release, WebAssembly web release,
  unsigned iOS release, and universal macOS release builds pass. The macOS app
  passes strict nested signature verification after the packaging script
  restores the third-party llama framework's canonical version symlinks, and
  the fresh app launches to the QPdf Home screen.

## Device state

The Phase C4.5 Android debug APK SHA-256 is
`8be42bbb07be3271b32964895c63efbca0974a1afb994847405745d3ef074629`.
No Android or iPhone device was connected after the build, so C4.5 physical
installation, TalkBack, VoiceOver, and hands-on form review remain open.

## Reproduce

```sh
cd apps/openpdf_studio
dart run tool/verify_c4_real_forms.dart
flutter analyze
flutter test
flutter build apk --debug
flutter build web --release --wasm
```

Use the Xcode beta environment and wrapper documented in
`docs/BUILD_ARTIFACTS.md` for Apple builds on this host.
