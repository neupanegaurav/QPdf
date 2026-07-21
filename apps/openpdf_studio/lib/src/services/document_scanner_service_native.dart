import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';

import 'images_to_pdf_service.dart';

bool get isDocumentScannerSupported => Platform.isAndroid || Platform.isIOS;

Future<List<PdfImageInput>> scanDocumentPages() async {
  if (!isDocumentScannerSupported) {
    throw UnsupportedError('Camera scanning is available on Android and iOS.');
  }
  final paths = await CunningDocumentScanner.getPictures(
    scannerSource: ScannerSource.cameraAndGallery,
    noOfPages: 50,
    iosScannerOptions: const IosScannerOptions(
      imageFormat: IosImageFormat.jpg,
      jpgCompressionQuality: 0.88,
    ),
  );
  if (paths == null) return const [];
  return Future.wait(
    paths.asMap().entries.map(
      (entry) async => PdfImageInput(
        name: 'scan-${entry.key + 1}.jpg',
        bytes: await File(entry.value).readAsBytes(),
      ),
    ),
  );
}
