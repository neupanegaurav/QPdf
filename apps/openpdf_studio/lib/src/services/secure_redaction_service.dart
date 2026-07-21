import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:pdf_document/pdf_document.dart';

/// Creates a new image-only PDF from the visible state of [document].
///
/// This is QPdf's conservative security boundary for applied redactions. The
/// returned file contains newly rendered pixels rather than the source object
/// graph, so covered text, partially covered image XObjects, form values,
/// attachments, metadata, revision history, and signatures cannot remain
/// recoverable in hidden PDF objects.
///
/// The tradeoff is deliberate: selectable/searchable text, links, forms,
/// comments, bookmarks, accessibility structure, and signatures are flattened.
Future<Uint8List> securelyFlattenRedactedPdf(
  PdfDocument document, {
  double pixelRatio = 2,
}) async {
  if (document.pageCount == 0) {
    throw StateError('Cannot flatten a PDF with no pages.');
  }
  if (pixelRatio <= 0) {
    throw ArgumentError.value(pixelRatio, 'pixelRatio', 'must be positive');
  }

  PdfDocument? combinedDocument;
  PdfEditor? combinedEditor;

  for (var pageIndex = 0; pageIndex < document.pageCount; pageIndex++) {
    final page = document.page(pageIndex);
    final displaySize = PdfPageRenderer.pageSize(page);
    final image = await PdfPageRenderer.renderImage(
      page,
      pixelRatio: pixelRatio,
      annotations: true,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Could not encode rendered page ${pageIndex + 1}.');
      }
      final pagePdf = PdfImageDocument.fromImageBytes(
        [data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)],
        pageSize: PdfPageSize(displaySize.width, displaySize.height),
        fit: PdfImageFit.fill,
      );
      final rasterPage = PdfDocument.open(pagePdf);
      if (combinedDocument == null) {
        combinedDocument = rasterPage;
        combinedEditor = PdfEditor(combinedDocument);
      } else {
        combinedEditor!.appendPagesFrom(rasterPage);
      }
    } finally {
      image.dispose();
    }
  }

  final saved = combinedEditor!.save();
  final reopened = PdfDocument.open(saved);
  return reopened.extractPages([
    for (var page = 0; page < reopened.pageCount; page++) page,
  ]);
}
