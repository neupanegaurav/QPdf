import 'package:pdf_document/pdf_document.dart';

void addTextWatermark(
  PdfEditor editor,
  String text, {
  double size = 42,
  int color = 0xB0B7C3,
}) {
  final value = text.trim();
  if (value.isEmpty) {
    throw ArgumentError.value(text, 'text', 'must not be empty');
  }
  for (var page = 0; page < editor.document.pageCount; page++) {
    editor.stampPage(page, (stamp) {
      final box = stamp.page.cropBox;
      final width = stamp.measureText(value, size: size, bold: true);
      stamp.text(
        value,
        x: box.left + (box.width - width * 0.72) / 2,
        y: box.bottom + box.height / 2,
        size: size,
        color: color,
        bold: true,
        angleDegrees: 35,
      );
    });
  }
}

void addBatesNumbers(
  PdfEditor editor, {
  required String prefix,
  int start = 1,
  int digits = 6,
}) {
  if (start < 0) throw ArgumentError.value(start, 'start', 'must be positive');
  if (digits < 1 || digits > 12) {
    throw ArgumentError.value(digits, 'digits', 'must be from 1 to 12');
  }
  for (var page = 0; page < editor.document.pageCount; page++) {
    final label = '$prefix${(start + page).toString().padLeft(digits, '0')}';
    editor.stampPage(page, (stamp) {
      const size = 9.0;
      final box = stamp.page.cropBox;
      final width = stamp.measureText(label, size: size);
      stamp.text(
        label,
        x: box.right - 36 - width,
        y: box.bottom + 28,
        size: size,
      );
    });
  }
}
