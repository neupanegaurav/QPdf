# PDF compatibility corpus

The corpus is generated locally so every fixture is legally distributable and reproducible. Generated PDFs and render outputs are ignored by Git.

Using the bundled Codex PDF runtime:

```sh
PYTHON=/Volumes/1tbMacSSD/GauravStudios/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
"$PYTHON" tool/generate_pdf_corpus.py
"$PYTHON" tool/verify_pdf_corpus.py
cd apps/openpdf_studio
dart run tool/verify_dart_engine_corpus.dart ../../test_corpus/generated
```

The generator creates 120 documents across six page geometries, four rotations, five content categories, one-to-three page counts, AcroForms, link/note annotations, vector transparency, and AES-256 password encryption.

The verifier checks parsing, page counts, expected text extraction, `pdfinfo`, first-page Poppler rendering, render dimensions/digests, structural rewrite, and reopen.

The Dart harness separately opens every fixture through the application engine, makes an incremental metadata edit, saves, and reopens the result with the same engine.

This generated corpus is a baseline, not sufficient evidence for production compatibility. Add licensed real-world, malformed, signed, accessibility-tagged, CJK, RTL, scanned, and very large PDFs separately.
