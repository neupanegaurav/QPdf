import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/flat_form_detection_service.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_document/pdf_document.dart';

void main() {
  test(
    'detects labelled text lines and checkboxes in a native flat form',
    () async {
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          build: (_) => pw.Padding(
            padding: const pw.EdgeInsets.all(48),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Application form', style: pw.TextStyle(fontSize: 20)),
                pw.SizedBox(height: 32),
                pw.Row(
                  children: [
                    pw.Text('Full name:'),
                    pw.SizedBox(width: 12),
                    pw.Container(
                      width: 220,
                      height: 22,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 1)),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 28),
                pw.Row(
                  children: [
                    pw.Container(
                      width: 14,
                      height: 14,
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text('I agree to the terms'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final pdfDocument = PdfDocument.open(await document.save());
      final result = const FlatFormDetectionService().detect(pdfDocument);

      expect(result.imageOnlyPages, isEmpty);
      expect(result.fields, hasLength(2));
    expect(
      result.fields,
      contains(
          isA<FlatFormDetection>()
              .having((field) => field.label, 'label', 'Full name')
              .having((field) => field.kind, 'kind', FlatFormControlKind.text)
              .having(
                (field) => field.confidence,
                'confidence',
                greaterThanOrEqualTo(0.65),
            ),
      ),
      reason: result.fields
          .map((field) => '${field.label}|${field.kind}|${field.confidence}')
          .join(', '),
    );
      expect(
        result.fields,
        contains(
          isA<FlatFormDetection>()
              .having((field) => field.label, 'label', 'I agree to the terms')
              .having(
                (field) => field.kind,
                'kind',
                FlatFormControlKind.checkBox,
              ),
        ),
      );
    },
  );

  test('reports image-only pages for raster detection', () {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAGUlEQVR4nGP4z8DwHwgb'
      'WBgZ/jNyicr7AgA3BAUOTnqjAAAAAABJRU5ErkJggg==',
    );
    final document = PdfDocument.open(PdfImageDocument.fromImageBytes([png]));

    final result = const FlatFormDetectionService().detect(document);

    expect(result.fields, isEmpty);
    expect(result.imageOnlyPages, [0]);
  });
}
