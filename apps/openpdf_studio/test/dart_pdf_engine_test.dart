import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/engine/dart_pdf_engine.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';
import 'package:pdf_engine_api/pdf_engine_api.dart';

void main() {
  test('opens a generated multi-page PDF', () async {
    final bytes = PdfBlankDocument.create(pageCount: 3);
    final source = PdfDocumentSource(
      id: 'generated',
      displayName: 'generated.pdf',
      bytes: bytes,
    );

    final opened = await DartPdfEngine().open(source);

    expect(opened.summary.pageCount, 3);
    expect(opened.summary.pdfVersion, isNotEmpty);
    expect(opened.engine.experimental, isTrue);
  });

  test('maps parser failures to the engine-neutral exception', () async {
    final source = PdfDocumentSource(
      id: 'invalid',
      displayName: 'invalid.pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(
      () => DartPdfEngine().open(source),
      throwsA(isA<PdfInvalidDocumentException>()),
    );
  });
}
