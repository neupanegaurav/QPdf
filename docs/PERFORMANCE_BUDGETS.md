# QPdf performance budgets

Performance gates are correctness requirements, not optional polish. Measure release/profile builds on representative low, middle, and high-tier hardware before changing these budgets.

## Automated structural benchmark

Run:

```sh
cd apps/openpdf_studio
dart run tool/benchmark_large_document.dart 1000
```

The current gate creates a 1,000-page PDF, opens it through the application engine, traverses all page geometry, performs an incremental edit, saves, and reopens it.

Latest local result (2026-07-19): generation 28 ms, open 15 ms, traversal
70 ms, save/reopen 4 ms, and 0.6 MB measured RSS growth. Resident-memory
sampling can be noisy when the Dart
runtime releases memory during the run, so the gate evaluates excessive
positive growth rather than requiring the delta to be positive.

CI-friendly ceilings:

- each structural stage under 5 seconds;
- desktop RSS growth under 512 MB;
- page count unchanged after save/reopen.

These generous ceilings detect regressions and runaway behavior. They are not user-experience targets.

## Automated image-render benchmark

Run:

```sh
python3 tool/generate_image_heavy_fixture.py
cd apps/openpdf_studio
flutter test test/image_heavy_performance_test.dart
```

The fixture embeds a different deterministic 1600 x 2200 JPEG on each of 12
pages. Four sampled pages must each render in under 10 seconds in a Flutter
debug test, with less than 768 MB of resident-memory growth. These deliberately
broad CI limits catch decoding, painting, and disposal regressions; device
release-profile acceptance remains governed by the product targets below.

## Product targets

| Operation | Mobile target | Desktop target |
| --- | ---: | ---: |
| First visible normal page | 750 ms | 500 ms |
| Search first result, 100 pages | 2 s | 1 s |
| Ink input latency | under 20 ms | under 16 ms |
| Save a small incremental annotation | 1 s | 750 ms |
| Peak render cache | 128 MB | 512 MB |
| Open 1,000-page structural document | no crash | no crash |

## Required future benchmarks

- tiled first-page and deep-zoom rendering;
- continuous scroll with cancellation of stale render work;
- 500 MB image-heavy stress document (the smaller CI fixture is implemented);
- OCR on 10 scanned pages;
- search across CJK and RTL documents;
- true-redaction save and forensic verification;
- compare pure-Dart and PDFium adapters with identical inputs.

Do not compare engines using only blank pages. The real-world corpus must include transparency, unusual fonts, malformed objects, scans, annotations, forms, and signatures.
