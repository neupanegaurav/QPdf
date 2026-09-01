import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/advanced_print_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  test('resolves ranges, duplicates, and odd/even subsets', () {
    expect(
      resolvePrintPages(
        pageCount: 10,
        selection: const PdfPrintSelection(
          range: '1-4, 4, 8-10',
          subset: PdfPrintSubset.even,
        ),
      ),
      [1, 3, 7, 9],
    );
  });

  test('rejects invalid and empty ranges', () {
    expect(
      () => resolvePrintPages(
        pageCount: 3,
        selection: const PdfPrintSelection(range: '2-5'),
      ),
      throwsFormatException,
    );
    expect(
      () => resolvePrintPages(
        pageCount: 1,
        selection: const PdfPrintSelection(subset: PdfPrintSubset.even),
      ),
      throwsFormatException,
    );
  });

  test('builds a standalone PDF containing only selected pages', () {
    final source = PdfBlankDocument.create(pageCount: 5);
    final result = buildPrintSelection(
      source,
      const PdfPrintSelection(range: '2-4', subset: PdfPrintSubset.odd),
    );
    expect(PdfDocument.open(result).pageCount, 1);
  });
}
