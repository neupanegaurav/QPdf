import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/pdf_merge_service.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';

void main() {
  test('merges every page in source order', () {
    final merged = mergePdfSources([
      _source('first', 2),
      _source('second', 3),
      _source('third', 1),
    ]);
    expect(PdfDocument.open(merged).pageCount, 6);
  });

  test('requires at least two source PDFs', () {
    expect(() => mergePdfSources([_source('one', 1)]), throwsArgumentError);
  });
}

PdfDocumentSource _source(String id, int pages) => PdfDocumentSource(
  id: id,
  displayName: '$id.pdf',
  bytes: PdfBlankDocument.create(pageCount: pages),
);
