import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/images_to_pdf_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  test('creates one valid PDF page per selected image', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGPkCrjDwMDAxAAGAA3gATp4/5EaAAAAAElFTkSuQmCC',
    );
    final bytes = await createPdfFromImages([
      PdfImageInput(name: 'one.png', bytes: png),
      PdfImageInput(name: 'two.png', bytes: png),
    ]);

    final document = PdfDocument.open(bytes);
    expect(document.pageCount, 2);
  });

  test('rejects an empty image selection', () async {
    await expectLater(createPdfFromImages(const []), throwsArgumentError);
  });
}
