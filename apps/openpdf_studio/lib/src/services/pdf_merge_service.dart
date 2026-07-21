import 'package:flutter/foundation.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';

/// Merges [sources] in order and returns the combined PDF bytes.
///
/// The parse-and-rewrite work runs on a background isolate so merging large
/// documents never blocks the UI thread.
Future<Uint8List> mergePdfSources(List<PdfDocumentSource> sources) async {
  if (sources.length < 2) {
    throw ArgumentError.value(sources, 'sources', 'needs at least two PDFs');
  }
  return compute(_mergeInBackground, sources);
}

Uint8List _mergeInBackground(List<PdfDocumentSource> sources) {
  final editor = PdfEditor(PdfDocument.open(sources.first.bytes));
  for (final source in sources.skip(1)) {
    editor.appendPagesFrom(PdfDocument.open(source.bytes));
  }
  return editor.save();
}
