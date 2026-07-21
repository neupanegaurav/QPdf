import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_ocr_ondevice/pdf_ocr_ondevice.dart';

typedef OcrProgressCallback = void Function(String message, double? fraction);

bool get isOfflineOcrSupported => PdfOcrModelManager.isSupported;

Future<Uint8List> applyOfflineOcr(
  Uint8List bytes, {
  String password = '',
  OcrProgressCallback? onProgress,
}) async {
  if (!isOfflineOcrSupported) {
    throw UnsupportedError('Offline OCR is unavailable on this platform.');
  }
  final manager = PdfOcrModelManager();
  final model = PdfOcrModels.ppOcrV5Mobile;
  OnDeviceOcrEngine? engine;
  try {
    if (!await manager.isDownloaded(model)) {
      onProgress?.call('Downloading the verified OCR model…', null);
      await manager.download(
        model,
        onProgress: (progress) => onProgress?.call(
          'Downloading ${progress.fileName}',
          progress.fraction,
        ),
      );
    }
    onProgress?.call('Starting offline OCR…', null);
    engine = await OnDeviceOcrEngine.fromDownloadedModel(manager, model);
    final editor = PdfEditor(PdfDocument.open(bytes, password: password));
    for (var page = 0; page < editor.document.pageCount; page++) {
      onProgress?.call(
        'Recognizing page ${page + 1} of ${editor.document.pageCount}',
        page / editor.document.pageCount,
      );
      await editor.applyOcr(page, engine, pixelRatio: 2);
    }
    onProgress?.call('Finishing searchable PDF…', 1);
    return editor.save();
  } finally {
    await engine?.dispose();
    manager.close();
  }
}
