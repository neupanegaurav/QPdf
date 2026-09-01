import 'dart:typed_data';

import 'package:pdf_document/pdf_document.dart';

enum PdfPrintSubset { all, odd, even }

final class PdfPrintSelection {
  const PdfPrintSelection({this.range = '', this.subset = PdfPrintSubset.all});

  final String range;
  final PdfPrintSubset subset;
}

List<int> resolvePrintPages({
  required int pageCount,
  required PdfPrintSelection selection,
}) {
  if (pageCount < 1) throw ArgumentError.value(pageCount, 'pageCount');
  final requested = <int>{};
  final raw = selection.range.trim();
  if (raw.isEmpty) {
    requested.addAll(List<int>.generate(pageCount, (index) => index));
  } else {
    for (final part in raw.split(',')) {
      final token = part.trim();
      if (token.isEmpty) continue;
      final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(token);
      if (range != null) {
        final start = int.parse(range.group(1)!);
        final end = int.parse(range.group(2)!);
        if (start < 1 || end < start || end > pageCount) {
          throw FormatException('Page range "$token" is outside 1-$pageCount.');
        }
        for (var page = start; page <= end; page++) {
          requested.add(page - 1);
        }
        continue;
      }
      final page = int.tryParse(token);
      if (page == null || page < 1 || page > pageCount) {
        throw FormatException('Page "$token" is outside 1-$pageCount.');
      }
      requested.add(page - 1);
    }
  }
  final ordered = requested.toList()..sort();
  final filtered = ordered
      .where((index) {
        final physicalPage = index + 1;
        return switch (selection.subset) {
          PdfPrintSubset.all => true,
          PdfPrintSubset.odd => physicalPage.isOdd,
          PdfPrintSubset.even => physicalPage.isEven,
        };
      })
      .toList(growable: false);
  if (filtered.isEmpty) {
    throw const FormatException(
      'The selected range contains no printable pages.',
    );
  }
  return filtered;
}

Uint8List buildPrintSelection(Uint8List source, PdfPrintSelection selection) {
  final document = PdfDocument.open(source);
  final pages = resolvePrintPages(
    pageCount: document.pageCount,
    selection: selection,
  );
  if (pages.length == document.pageCount &&
      pages.indexed.every((entry) => entry.$1 == entry.$2)) {
    return source;
  }
  return document.extractPages(pages);
}
