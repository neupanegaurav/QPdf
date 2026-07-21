import 'dart:io';

import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: dart run tool/inspect_c4_form_geometry.dart <pdf>');
    exitCode = 64;
    return;
  }
  final document = PdfDocument.open(File(arguments.first).readAsBytesSync());
  final form = PdfAcroForm.of(document);
  if (form == null) return;
  final runsByPage = <int, List<PdfExtractedRun>>{};
  for (final field in form.fields) {
    if (field.widgets.isEmpty) continue;
    final pageIndex = field.widgetPageIndex(0);
    final rect = field.widgetRect(0);
    if (pageIndex < 0 || rect == null) continue;
    final runs = runsByPage.putIfAbsent(
      pageIndex,
      () => PdfTextExtractor.extract(document, pageIndex).runs,
    );
    final nearby = [
      for (final run in runs)
        if (_near(rect, run.bounds))
          '${run.text.replaceAll(RegExp(r'\s+'), ' ').trim()} '
              '[${_rect(run.bounds)}]',
    ];
    stdout.writeln(
      '${field.name} p${pageIndex + 1} [${_rect(rect)}]\n'
      '  ${nearby.take(12).join('\n  ')}',
    );
  }
}

bool _near(PdfRect field, PdfRect text) {
  final horizontal =
      text.right >= field.left - 150 && text.left <= field.right + 150;
  final vertical =
      text.top >= field.bottom - 55 && text.bottom <= field.top + 55;
  return horizontal && vertical;
}

String _rect(PdfRect value) =>
    '${value.left.toStringAsFixed(1)},${value.bottom.toStringAsFixed(1)},'
    '${value.right.toStringAsFixed(1)},${value.top.toStringAsFixed(1)}';
