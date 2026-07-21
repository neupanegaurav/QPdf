import 'images_to_pdf_service.dart';

bool get isDocumentScannerSupported => false;

Future<List<PdfImageInput>> scanDocumentPages() =>
    throw UnsupportedError('Camera scanning is unavailable in this web build.');
