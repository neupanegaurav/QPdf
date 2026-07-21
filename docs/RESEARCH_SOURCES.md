# Research Sources

Checked on 2026-07-20. Recheck versions, licenses, platform minimums, and distribution terms before implementation or release.

## Platform and integration

- Flutter supported platforms: https://docs.flutter.dev/reference/supported-platforms
- Flutter desktop support: https://docs.flutter.dev/platform-integration/desktop
- Flutter plugin and federated-plugin architecture: https://docs.flutter.dev/packages-and-plugins/developing-packages

## PDF engines and transformations

- PDFium source/build documentation: https://pdfium.googlesource.com/pdfium.git
- qpdf manual: https://qpdf.readthedocs.io/en/stable/
- qpdf source and license: https://github.com/qpdf/qpdf
- MuPDF releases and licensing notice: https://mupdf.com/releases
- PDF.js API: https://mozilla.github.io/pdf.js/api/

## Flutter candidates to evaluate, not yet approved

- `dart_pdf_editor`: https://pub.dev/packages/dart_pdf_editor
- `flutter_pdfium`: https://pub.dev/packages/flutter_pdfium
- `pdf_renderer`: https://pub.dev/packages/pdf_renderer

Package listings are claims from their publishers, not proof of compatibility, quality, security, or long-term maintenance. Acceptance requires the Phase 0 corpus and performance gates.

## Platform PDF APIs

- Apple PDFKit: https://developer.apple.com/documentation/pdfkit
- Apple PDFAnnotation: https://developer.apple.com/documentation/pdfkit/pdfannotation
- Android PdfRenderer: https://developer.android.com/reference/android/graphics/pdf/PdfRenderer
- Android PDF viewer guidance: https://developer.android.com/develop/ui/views/layout/pdf/pdf-viewer

## OCR and standards

- Tesseract documentation and Apache-2.0 license statement: https://tesseract-ocr.github.io/tessdoc/Installation.html
- Adobe-hosted PDF standards/reference material: https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/

## On-device form intelligence

- `lib_llama_cpp` package/runtime support: https://pub.dev/packages/lib_llama_cpp
- SmolLM2-135M official model card, limitations, and Apache-2.0 license: https://huggingface.co/HuggingFaceTB/SmolLM2-135M
- Pinned Q4_K_M GGUF conversion used by QPdf: https://huggingface.co/QuantFactory/SmolLM2-135M-Instruct-GGUF/tree/476854d00ede130660aba430d15f9347ad2e7d0e
- SmolLM2-360M-Instruct model card evaluated and rejected in Phase C3: https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct
- Pinned 360M Q4_K_M evaluation artifact (not shipped): https://huggingface.co/QuantFactory/SmolLM2-360M-Instruct-GGUF/tree/42821b2066379bb5a70951029cc79ac1be0b809d
