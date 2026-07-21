import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/pdf_rewrite_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  test('optimization returns a valid document', () async {
    final result = await optimizePdf(_documentWithMetadata());
    final reopened = PdfDocument.open(result.bytes);

    expect(reopened.pageCount, 1);
    expect(result.images, 0);
  });

  test('metadata scrub removes document information', () async {
    final scrubbed = await scrubPdfMetadata(_documentWithMetadata());
    final reopened = PdfDocument.open(scrubbed);

    expect(reopened.info['Title'], isNull);
    expect(reopened.info['Author'], isNull);
  });

  test('PDF/A conversion adds archival structures', () async {
    final converted = await convertPdfToPdfA(_documentWithMetadata());
    final reopened = PdfDocument.open(converted);

    expect(reopened.pageCount, 1);
    expect(reopened.cos.encryption, isNull);
    expect(reopened.catalog['Metadata'], isNotNull);
    expect(reopened.catalog['OutputIntents'], isNotNull);
  });
}

Uint8List _documentWithMetadata() {
  final document = PdfDocument.open(_onePagePdf());
  final editor = PdfEditor(document)
    ..setInfo(title: 'Private title', author: 'Private author');
  return editor.save();
}

Uint8List _onePagePdf() => Uint8List.fromList(
  latin1.encode(
    '%PDF-1.4\n'
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n'
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n'
    'xref\n0 4\n'
    '0000000000 65535 f \n'
    '0000000009 00000 n \n'
    '0000000058 00000 n \n'
    '0000000115 00000 n \n'
    'trailer\n<< /Size 4 /Root 1 0 R >>\n'
    'startxref\n186\n%%EOF\n',
  ),
);
