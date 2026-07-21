import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readLocalPdf(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}
