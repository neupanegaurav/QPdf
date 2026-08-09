import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart';

import 'images_to_pdf_service.dart';

bool get isDocumentScannerSupported => Platform.isAndroid || Platform.isIOS;

Future<List<PdfImageInput>> scanDocumentPages() async {
  if (!isDocumentScannerSupported) {
    throw UnsupportedError('Camera scanning is available on Android and iOS.');
  }
  final List<String>? paths;
  try {
    paths = await CunningDocumentScanner.getPictures(
      // camera-only keeps us on VNDocumentCameraViewController; the
      // cameraAndGallery path invokes DKImagePickerController, which is not
      // part of the iOS SDK and has repeatedly broken on major OS releases.
      scannerSource: ScannerSource.camera,
      noOfPages: 50,
      iosScannerOptions: const IosScannerOptions(
        imageFormat: IosImageFormat.jpg,
        jpgCompressionQuality: 0.88,
      ),
    );
  } on PlatformException catch (e) {
    // The scanner was dismissed without capturing pages — not an error state.
    final code = e.code.toLowerCase();
    if (code == 'cancelled' || code == 'camera_cancelled' || code == 'user_cancelled') {
      return const [];
    }
    rethrow;
  }
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
