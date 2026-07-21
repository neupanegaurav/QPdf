# QPdf third-party notices

Updated: 2026-07-20

QPdf displays the complete license text registered by Flutter packages through
**About QPdf → View licenses**. Release builds must retain that screen.

The principal direct dependencies are:

| Component | Purpose | License |
| --- | --- | --- |
| Flutter and Dart | Cross-platform application runtime | BSD 3-Clause |
| dart_pdf_editor, pdf_document, pdf_cos | PDF editor, renderer, and object model | Apache-2.0 |
| pdf_manipulator / pdf_oxide | Password protection, optimization, metadata scrubbing, and PDF/A conversion | MIT / MIT or Apache-2.0 |
| pdf_ocr_ondevice and its packaged model workflow | Private on-device OCR | Apache-2.0 |
| cunning_document_scanner | Android/iOS document scanning | MIT |
| printing | Platform printing and sharing | Apache-2.0 |
| file_picker | Native file selection | MIT |
| file_saver | Native/web save integration | BSD 3-Clause |
| shared_preferences, path_provider, crypto, pdf | Supporting Flutter/Dart libraries | Their bundled licenses |
| flutter_pdfium and PDFium | Optional test oracle; not linked into the shipping app | Package/upstream terms |

Before each store submission, regenerate the dependency graph with
`flutter pub deps`, inspect every bundled `LICENSE` file, and update this table
if a dependency or license changes. The OCR model URL, byte count, and checksum
must remain pinned, and its upstream notices must be retained with the
distributed or downloaded model.
