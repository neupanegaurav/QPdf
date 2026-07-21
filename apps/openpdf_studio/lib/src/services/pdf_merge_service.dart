import 'dart:typed_data';

import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';

Uint8List mergePdfSources(List<PdfDocumentSource> sources) {
  if (sources.length < 2) {
    throw ArgumentError.value(sources, 'sources', 'needs at least two PDFs');
  }
  final base = PdfDocument.open(sources.first.bytes);
  final editor = PdfEditor(base);
  for (final source in sources.skip(1)) {
    editor.appendPagesFrom(PdfDocument.open(source.bytes));
  }
  return editor.save();
}
