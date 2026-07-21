import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';
import 'package:pdf_engine_api/pdf_engine_api.dart';

final class DartPdfEngine implements PdfEngine {
  static const _descriptor = PdfEngineDescriptor(
    id: 'dart-pdf-2',
    label: 'Dart PDF Engine 2.0',
    experimental: true,
    capabilities: {
      PdfEngineCapability.render,
      PdfEngineCapability.textSelection,
      PdfEngineCapability.search,
      PdfEngineCapability.annotations,
      PdfEngineCapability.forms,
      PdfEngineCapability.pageEditing,
      PdfEngineCapability.redaction,
      PdfEngineCapability.ocr,
      PdfEngineCapability.digitalSignatures,
    },
  );

  @override
  PdfEngineDescriptor get descriptor => _descriptor;

  @override
  Future<PdfOpenedDocument> open(
    PdfDocumentSource source, {
    String password = '',
  }) async {
    try {
      final document = PdfDocument.open(source.bytes, password: password);
      final info = document.info;
      return PdfOpenedDocument(
        source: source,
        engine: descriptor,
        summary: PdfDocumentSummary(
          pageCount: document.pageCount,
          pdfVersion: document.version,
          title: info['Title'],
          author: info['Author'],
        ),
      );
    } on CosPasswordException {
      throw const PdfPasswordRequiredException();
    } on CosParseException catch (error) {
      throw PdfInvalidDocumentException(error.message);
    } on FormatException catch (error) {
      throw PdfInvalidDocumentException(error.message);
    }
  }
}
