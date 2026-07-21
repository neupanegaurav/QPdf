import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List> readPickedFileBytes(PlatformFile file) async {
  final bytes = file.bytes;
  if (bytes == null) {
    throw StateError('The selected PDF could not be read.');
  }
  return bytes;
}
