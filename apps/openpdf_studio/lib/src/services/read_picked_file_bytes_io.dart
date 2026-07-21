import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List> readPickedFileBytes(PlatformFile file) async {
  if (file.bytes case final bytes?) return bytes;
  if (file.path case final path?) return File(path).readAsBytes();
  throw StateError('The selected PDF could not be read.');
}
