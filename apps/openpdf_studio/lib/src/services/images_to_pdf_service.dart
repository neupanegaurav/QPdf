import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final class PdfImageInput {
  const PdfImageInput({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<Uint8List> createPdfFromImages(List<PdfImageInput> images) async {
  if (images.isEmpty) throw ArgumentError.value(images, 'images', 'is empty');
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
