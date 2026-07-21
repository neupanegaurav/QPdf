import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final class PdfImageInput {
  const PdfImageInput({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Builds a single PDF containing one page per image.
///
/// The image decode and PDF encode run on a background isolate so a large
/// scan or import never blocks the UI thread.
Future<Uint8List> createPdfFromImages(List<PdfImageInput> images) async {
  if (images.isEmpty) throw ArgumentError.value(images, 'images', 'is empty');
  return compute(_buildInBackground, images);
}

Future<Uint8List> _buildInBackground(List<PdfImageInput> images) async {
  final document = pw.Document(
    title: 'QPdf image document',
    author: 'QPdf',
    creator: 'QPdf',
  );
  for (final input in images) {
    final image = pw.MemoryImage(input.bytes);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  return document.save();
}
