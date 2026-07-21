import 'dart:io';

import 'package:openpdf_studio/src/services/flat_form_detection_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/verify_flat_form_fixture.dart FILE');
    exitCode = 64;
    return;
  }
  final document = PdfDocument.open(File(arguments.single).readAsBytesSync());
  final result = const FlatFormDetectionService().detect(document);
  for (final field in result.fields) {
    stdout.writeln(
      'p${field.pageIndex + 1} ${field.kind.name} '
      '${(field.confidence * 100).round()}% ${field.label} ${field.rect}',
    );
  }
  if (result.fields.length != 8 || result.imageOnlyPages.isNotEmpty) {
    stderr.writeln(
      'Expected 8 native flat-form fields and no image-only pages; '
      'found ${result.fields.length} and ${result.imageOnlyPages.length}.',
    );
    exitCode = 1;
  }
}
