import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/flat_form_detection_service.dart';
import 'package:openpdf_studio/src/services/raster_form_detection_service.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

void main() {
  testWidgets('detects controls in an OCR-labelled scanned form', (
    tester,
  ) async {
    final fixture = await _scannedForm(includeOcr: true);

    final result = (await tester.runAsync(
      () => RasterFormDetectionService(
        rasterizer: _FixtureRasterizer(fixture.image),
      ).detect(fixture.document, pages: const [0]),
    ))!;

    expect(result.pagesNeedingOcr, isEmpty);
    expect(
      result.fields,
      contains(
        isA<FlatFormDetection>()
            .having((field) => field.label, 'label', contains('Full name'))
            .having((field) => field.kind, 'kind', FlatFormControlKind.text),
      ),
      reason: _describe(result.fields),
    );
    expect(
      result.fields,
      contains(
        isA<FlatFormDetection>()
            .having(
              (field) => field.label,
              'label',
              contains('I agree to the terms'),
            )
            .having(
              (field) => field.kind,
              'kind',
              FlatFormControlKind.checkBox,
            ),
      ),
      reason: _describe(result.fields),
    );
  });

  testWidgets('requests OCR instead of guessing labels on a scan', (
    tester,
  ) async {
    final fixture = await _scannedForm(includeOcr: false);

    final result = (await tester.runAsync(
      () => RasterFormDetectionService(
        rasterizer: _FixtureRasterizer(fixture.image),
      ).detect(fixture.document, pages: const [0]),
    ))!;
    fixture.image.dispose();

    expect(result.fields, isEmpty);
    expect(result.pagesNeedingOcr, [0]);
  });
}

Future<({PdfDocument document, ui.Image image})> _scannedForm({
  required bool includeOcr,
}) async {
  final source = pw.Document();
  source.addPage(
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
  final native = PdfDocument.open(await source.save());
  final nativeText = PdfTextExtractor.extract(native, 0).runs;
  final page = native.page(0);
  final image = await PdfPageRenderer.renderImage(page, pixelRatio: 1.5);
  final box = page.cropBox;
  final scanned = PdfDocument.open(
    PdfImageDocument.fromImageBytes(
      [
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAGUlEQVR4nGP4z8DwHwgb'
          'WBgZ/jNyicr7AgA3BAUOTnqjAAAAAABJRU5ErkJggg==',
        ),
      ],
      pageSize: PdfPageSize(box.width.abs(), box.height.abs()),
      fit: PdfImageFit.fill,
    ),
  );
  if (includeOcr) {
    PdfEditor(scanned).injectTextLayer(0, [
      for (final run in nativeText)
        if (run.text.trim().isNotEmpty)
          PdfOcrSpan(text: run.text, bounds: run.bounds),
    ]);
  }
  return (document: scanned, image: image);
}

class _FixtureRasterizer extends PdfOcrRasterizer {
  const _FixtureRasterizer(this.image);

  final ui.Image image;

  @override
  Future<PdfOcrPageImage> rasterize(
    PdfPage page, {
    required int pageIndex,
    required double pixelRatio,
  }) async => PdfOcrPageImage(
    image: image,
    page: page,
    pageIndex: pageIndex,
    pixelRatio: pixelRatio,
  );
}

String _describe(List<FlatFormDetection> fields) => fields
    .map(
      (field) =>
          '${field.label}|${field.kind.name}|${field.confidence.toStringAsFixed(2)}',
    )
    .join(', ');
