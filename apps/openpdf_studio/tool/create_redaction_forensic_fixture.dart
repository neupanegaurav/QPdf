import 'dart:io';

import 'package:pdf_document/pdf_document.dart';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/create_redaction_forensic_fixture.dart '
      '<source.pdf> <redacted.pdf>',
    );
    exitCode = 64;
    return;
  }

  final source = File(arguments[0]);
  if (!source.existsSync()) {
    stderr.writeln('Source PDF does not exist: ${source.path}');
    exitCode = 66;
    return;
  }

  final document = PdfDocument.open(source.readAsBytesSync());
  final editor = PdfEditor(document);

  // The deterministic corpus places OPENPDF-CORPUS-TEXT at x=28..201 and
  // y=727..740 in PDF coordinates. Keep this rectangle deliberately wider so
  // the independent verifier catches coordinate or partial-glyph regressions.
  for (var page = 0; page < document.pageCount; page++) {
    editor.addRedaction(page, const [PdfRect(20, 710, 220, 755)]);
  }
  final redacted = editor.applyRedactions();

  final reopened = PdfDocument.open(redacted);
  if (reopened.pageCount != document.pageCount) {
    throw StateError('Redaction changed the document page count.');
  }
  if (reopened.page(0).annotations.any((item) => item.subtype == 'Redact')) {
    throw StateError('Applied /Redact annotations remain in the saved PDF.');
  }

  File(arguments[1])
    ..createSync(recursive: true)
    ..writeAsBytesSync(redacted, flush: true);
}
