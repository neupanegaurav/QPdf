import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/pdf_external_modification_exception.dart';
import 'package:openpdf_studio/src/services/write_pdf_atomically_io.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  test('atomically replaces an existing PDF', () async {
    final directory = await Directory.systemTemp.createTemp('openpdf-save-');
    addTearDown(() => directory.delete(recursive: true));
    final target = File('${directory.path}/document.pdf');
    await target.writeAsBytes(PdfBlankDocument.create());
    final replacement = PdfBlankDocument.create(pageCount: 3);

    expect(await writePdfAtomically(target.path, replacement), isTrue);
    final reopened = PdfDocument.open(await target.readAsBytes());
    expect(reopened.pageCount, 3);
    expect(directory.listSync().whereType<File>().map((file) => file.path), [
      target.path,
    ]);
  });

  test('rejects non-PDF bytes without touching the source', () async {
    final directory = await Directory.systemTemp.createTemp('openpdf-save-');
    addTearDown(() => directory.delete(recursive: true));
    final target = File('${directory.path}/document.pdf');
    final original = PdfBlankDocument.create();
    await target.writeAsBytes(original);

    await expectLater(
      writePdfAtomically(target.path, Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(await target.readAsBytes(), original);
  });

  test('refuses to overwrite a PDF changed by another application', () async {
    final directory = await Directory.systemTemp.createTemp('openpdf-save-');
    addTearDown(() => directory.delete(recursive: true));
    final target = File('${directory.path}/document.pdf');
    final openedRevision = PdfBlankDocument.create();
    final externalRevision = PdfBlankDocument.create(pageCount: 2);
    final qpdfRevision = PdfBlankDocument.create(pageCount: 3);
    await target.writeAsBytes(externalRevision);

    await expectLater(
      writePdfAtomically(
        target.path,
        qpdfRevision,
        expectedOriginalBytes: openedRevision,
      ),
      throwsA(isA<PdfExternalModificationException>()),
    );
    expect(await target.readAsBytes(), externalRevision);
    expect(directory.listSync().whereType<File>().map((file) => file.path), [
      target.path,
    ]);
  });
}
