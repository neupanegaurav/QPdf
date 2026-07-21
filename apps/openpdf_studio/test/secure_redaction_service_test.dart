import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/secure_redaction_service.dart';
import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  testWidgets(
    'secure flatten removes recoverable text and the source object graph',
    (tester) async {
      final textBytes = File(
        '../../test_corpus/generated/case-001-a4-r0-text.pdf',
      ).readAsBytesSync();
      final editing = PdfEditingController(textBytes);
      addTearDown(editing.dispose);
      for (var page = 0; page < editing.document.pageCount; page++) {
        editing.addRedaction(page, const PdfRect(20, 710, 220, 755));
      }
      expect(editing.applyRedactions(), isTrue);

      late Uint8List flattened;
      await tester.runAsync(() async {
        flattened = await securelyFlattenRedactedPdf(
          editing.document,
          pixelRatio: 1,
        );
      });

      final reopened = PdfDocument.open(flattened);
      expect(reopened.pageCount, 2);
      expect(
        flattened,
        isNot(containsAllInOrder('OPENPDF-CORPUS-TEXT'.codeUnits)),
      );
      expect(reopened.catalog['AcroForm'], isNull);
      expect(reopened.catalog['Metadata'], isNull);
      expect(reopened.catalog['Outlines'], isNull);
      for (var page = 0; page < reopened.pageCount; page++) {
        expect(reopened.page(page).annotations, isEmpty);
      }
    },
  );

  testWidgets('secure flatten replaces a partially redacted source image', (
    tester,
  ) async {
    final source = PdfDocument.open(
      File('../../test_corpus/generated/image-heavy.pdf').readAsBytesSync(),
    ).extractPages(const [0]);
    final editing = PdfEditingController(source);
    addTearDown(editing.dispose);
    final originalImageHash = _imageHashes(editing.document).single;

    editing.addRedaction(0, const PdfRect(100, 300, 300, 500));
    expect(editing.applyRedactions(), isTrue);
    expect(
      _imageHashes(editing.document),
      contains(originalImageHash),
      reason: 'the surgical editor retains a partially covered XObject',
    );

    late Uint8List flattened;
    await tester.runAsync(() async {
      flattened = await securelyFlattenRedactedPdf(
        editing.document,
        pixelRatio: 0.5,
      );
    });

    final reopened = PdfDocument.open(flattened);
    expect(reopened.pageCount, 1);
    expect(_imageHashes(reopened), isNot(contains(originalImageHash)));
    expect(reopened.page(0).annotations, isEmpty);
    expect(flattened.length, lessThan(source.length));
  });
}

Set<Digest> _imageHashes(PdfDocument document) {
  final hashes = <Digest>{};
  for (var pageIndex = 0; pageIndex < document.pageCount; pageIndex++) {
    final page = document.page(pageIndex);
    final xObjects = document.cos.resolve(page.resources['XObject']);
    if (xObjects is! CosDictionary) continue;
    for (final value in xObjects.entries.values) {
      final stream = document.cos.resolve(value);
      if (stream is! CosStream) continue;
      final subtype = document.cos.resolve(stream.dictionary['Subtype']);
      if (subtype is CosName && subtype.value == 'Image') {
        hashes.add(sha256.convert(stream.rawBytes));
      }
    }
  }
  return hashes;
}
