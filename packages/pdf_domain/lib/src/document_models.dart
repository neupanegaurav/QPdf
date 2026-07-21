import 'dart:typed_data';

/// Bytes and user-facing identity for a document selected by the user.
final class PdfDocumentSource {
  PdfDocumentSource({
    required this.id,
    required this.displayName,
    required this.bytes,
    this.localPath,
  });

  final String id;
  final String displayName;
  final Uint8List bytes;

  /// Native writable path, when the platform file picker supplied one.
  /// Null on web and for providers that only expose document bytes.
  final String? localPath;
}

/// Engine-neutral metadata collected while opening a PDF.
final class PdfDocumentSummary {
  const PdfDocumentSummary({
    required this.pageCount,
    required this.pdfVersion,
    this.title,
    this.author,
  });

  final int pageCount;
  final String pdfVersion;
  final String? title;
  final String? author;
}

/// One safely recoverable byte revision of an open document.
final class PdfDocumentRevision {
  PdfDocumentRevision({
    required this.sequence,
    required this.bytes,
    required this.createdAt,
  });

  final int sequence;
  final Uint8List bytes;
  final DateTime createdAt;
}
