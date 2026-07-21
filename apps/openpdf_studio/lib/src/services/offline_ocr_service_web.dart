import 'dart:typed_data';

typedef OcrProgressCallback = void Function(String message, double? fraction);

bool get isOfflineOcrSupported => false;

Future<Uint8List> applyOfflineOcr(
  Uint8List bytes, {
  String password = '',
  OcrProgressCallback? onProgress,
}) => throw UnsupportedError(
  'Offline OCR is unavailable on web because it requires a native runtime.',
);
