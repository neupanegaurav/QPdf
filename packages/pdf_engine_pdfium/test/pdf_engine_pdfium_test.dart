import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_engine_api/pdf_engine_api.dart';
import 'package:pdf_engine_pdfium/pdf_engine_pdfium.dart';

void main() {
  test(
    'declares only the native comparison capabilities currently exposed',
    () {
      final descriptor = PdfiumEngine().descriptor;

      expect(descriptor.id, 'pdfium-native');
      expect(descriptor.experimental, isTrue);
      expect(descriptor.capabilities, contains(PdfEngineCapability.render));
      expect(
        descriptor.capabilities,
        isNot(contains(PdfEngineCapability.pageEditing)),
      );
    },
  );
}
