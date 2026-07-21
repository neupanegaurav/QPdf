import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf_domain/pdf_domain.dart';

import 'images_to_pdf_service.dart';
import 'read_picked_file_bytes.dart';
import 'read_local_pdf.dart';
import 'write_pdf_atomically.dart';

abstract interface class DocumentFileService {
  Future<PdfDocumentSource?> pickPdf();
  Future<List<PdfDocumentSource>> pickPdfs();
  Future<List<PdfImageInput>> pickImages();
  Future<PdfDocumentSource?> openRecent({
    required String id,
    required String displayName,
    required String localPath,
  });
  Future<String?> savePdf(
    PdfDocumentSource source,
    Uint8List bytes, {
    Uint8List? expectedSourceBytes,
  });
  Future<String?> savePdfAs(String suggestedName, Uint8List bytes);
}

final class PlatformDocumentFileService implements DocumentFileService {
  @override
  Future<List<PdfImageInput>> pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return const [];
    return Future.wait(
      result.files.map(
        (file) async => PdfImageInput(
          name: file.name,
          bytes: await readPickedFileBytes(file),
        ),
      ),
    );
  }

  @override
  Future<PdfDocumentSource?> openRecent({
    required String id,
    required String displayName,
    required String localPath,
  }) async {
    final bytes = await readLocalPdf(localPath);
    if (bytes == null) return null;
    return PdfDocumentSource(
      id: id,
      displayName: displayName,
      bytes: bytes,
      localPath: localPath,
    );
  }

  @override
  Future<PdfDocumentSource?> pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = await readPickedFileBytes(file);
    return PdfDocumentSource(
      id: file.path ?? '${file.name}:${file.size}',
      displayName: file.name,
      bytes: bytes,
      localPath: file.path,
    );
  }

  @override
  Future<List<PdfDocumentSource>> pickPdfs() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return const [];
    return Future.wait(
      result.files.map(
        (file) async => PdfDocumentSource(
          id: file.path ?? '${file.name}:${file.size}',
          displayName: file.name,
          bytes: await readPickedFileBytes(file),
          localPath: file.path,
        ),
      ),
    );
  }

  @override
  Future<String?> savePdf(
    PdfDocumentSource source,
    Uint8List bytes, {
    Uint8List? expectedSourceBytes,
  }) async {
    final path = source.localPath;
    if (path != null &&
        await writePdfAtomically(
          path,
          bytes,
          expectedOriginalBytes: expectedSourceBytes,
        )) {
      return path;
    }
    return savePdfAs(source.displayName, bytes);
  }

  @override
  Future<String?> savePdfAs(String suggestedName, Uint8List bytes) {
    final baseName = suggestedName.toLowerCase().endsWith('.pdf')
        ? suggestedName.substring(0, suggestedName.length - 4)
        : suggestedName;
    return FileSaver.instance.saveAs(
      name: baseName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
