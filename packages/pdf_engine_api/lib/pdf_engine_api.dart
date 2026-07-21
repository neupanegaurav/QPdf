library;

import 'package:pdf_domain/pdf_domain.dart';

enum PdfEngineCapability {
  render,
  textSelection,
  search,
  annotations,
  forms,
  pageEditing,
  redaction,
  ocr,
  digitalSignatures,
}

final class PdfEngineDescriptor {
  const PdfEngineDescriptor({
    required this.id,
    required this.label,
    required this.capabilities,
    this.experimental = false,
  });

  final String id;
  final String label;
  final Set<PdfEngineCapability> capabilities;
  final bool experimental;
}

final class PdfOpenedDocument {
  const PdfOpenedDocument({
    required this.source,
    required this.summary,
    required this.engine,
  });

  final PdfDocumentSource source;
  final PdfDocumentSummary summary;
  final PdfEngineDescriptor engine;
}

abstract interface class PdfEngine {
  PdfEngineDescriptor get descriptor;

  Future<PdfOpenedDocument> open(
    PdfDocumentSource source, {
    String password = '',
  });
}

sealed class PdfOpenException implements Exception {
  const PdfOpenException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class PdfPasswordRequiredException extends PdfOpenException {
  const PdfPasswordRequiredException()
    : super('This PDF requires a password or the password is incorrect.');
}

final class PdfInvalidDocumentException extends PdfOpenException {
  const PdfInvalidDocumentException([
    super.message = 'The file is not a valid PDF.',
  ]);
}
