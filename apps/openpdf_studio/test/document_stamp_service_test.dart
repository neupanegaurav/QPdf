import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/document_stamp_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  test('watermark is written on every page', () {
    final editor = PdfEditor(
      PdfDocument.open(PdfBlankDocument.create(pageCount: 2)),
    );
    addTextWatermark(editor, 'DRAFT');
    final reopened = PdfDocument.open(editor.save());

    expect(latin1.decode(reopened.page(0).contentBytes()), contains('DRAFT'));
    expect(latin1.decode(reopened.page(1).contentBytes()), contains('DRAFT'));
  });

  test('Bates labels increment and are zero padded', () {
    final editor = PdfEditor(
      PdfDocument.open(PdfBlankDocument.create(pageCount: 2)),
    );
    addBatesNumbers(editor, prefix: 'CASE-', start: 41, digits: 4);
    final reopened = PdfDocument.open(editor.save());

    expect(
      latin1.decode(reopened.page(0).contentBytes()),
      contains('CASE-0041'),
    );
    expect(
      latin1.decode(reopened.page(1).contentBytes()),
      contains('CASE-0042'),
    );
  });
}
