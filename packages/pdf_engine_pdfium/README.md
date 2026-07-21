# pdf_engine_pdfium

Optional QPdf PDFium adapter used as a native compatibility oracle. The
shipping beta uses the pure-Dart engine; keeping PDFium isolated here allows
corpus comparisons without coupling the application UI to a native engine.

Native tests require a host supported by `flutter_pdfium`. This package is not
published independently.
