import 'dart:io';
import 'dart:typed_data';

import 'pdf_external_modification_exception.dart';

Future<bool> writePdfAtomically(
  String targetPath,
  Uint8List bytes, {
  Uint8List? expectedOriginalBytes,
}) async {
  _validatePdfBytes(bytes);

  final target = File(targetPath).absolute;
  if (!await target.exists()) {
    throw FileSystemException(
      'The original PDF no longer exists.',
      target.path,
    );
  }
  if (expectedOriginalBytes != null) {
    await _assertFileMatches(target, expectedOriginalBytes);
  }

  final nonce = DateTime.now().microsecondsSinceEpoch;
  final temporary = File('${target.path}.openpdf-$nonce.tmp');
  final backup = File('${target.path}.openpdf-$nonce.backup');

  try {
    final sink = temporary.openWrite(mode: FileMode.writeOnly);
    sink.add(bytes);
    await sink.flush();
    await sink.close();

    if (await temporary.length() != bytes.length) {
      throw const FileSystemException(
        'The temporary PDF was not fully written.',
      );
    }
    // Check again after the potentially slow write so a concurrent external
    // save cannot be silently replaced during QPdf's save window.
    if (expectedOriginalBytes != null) {
      await _assertFileMatches(target, expectedOriginalBytes);
    }

    try {
      await temporary.rename(target.path);
    } on FileSystemException {
      // Windows does not replace an existing destination with rename. Keep a
      // sibling backup until the replacement succeeds, and restore on error.
      await target.rename(backup.path);
      try {
        await temporary.rename(target.path);
        await backup.delete();
      } catch (_) {
        if (await backup.exists() && !await target.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
    }
    return true;
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

Future<void> _assertFileMatches(File file, Uint8List expected) async {
  if (!await file.exists() || await file.length() != expected.length) {
    throw PdfExternalModificationException(file.path);
  }
  final input = await file.open();
  try {
    const chunkSize = 64 * 1024;
    var offset = 0;
    while (offset < expected.length) {
      final count = (expected.length - offset).clamp(0, chunkSize);
      final actual = await input.read(count);
      if (actual.length != count) {
        throw PdfExternalModificationException(file.path);
      }
      for (var index = 0; index < count; index++) {
        if (actual[index] != expected[offset + index]) {
          throw PdfExternalModificationException(file.path);
        }
      }
      offset += count;
    }
  } finally {
    await input.close();
  }
}

void _validatePdfBytes(Uint8List bytes) {
  if (bytes.length < 8 ||
      bytes[0] != 0x25 ||
      bytes[1] != 0x50 ||
      bytes[2] != 0x44 ||
      bytes[3] != 0x46 ||
      bytes[4] != 0x2d) {
    throw const FormatException('Refusing to save bytes without a PDF header.');
  }
}
