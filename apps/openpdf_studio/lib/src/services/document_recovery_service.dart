import 'dart:typed_data';

import 'package:pdf_domain/pdf_domain.dart';

final class RecoveryCandidate {
  const RecoveryCandidate({
    required this.bytes,
    required this.updatedAt,
    required this.payloadLength,
    required this.incremental,
  });

  final Uint8List bytes;
  final DateTime updatedAt;
  final int payloadLength;
  final bool incremental;
}

abstract interface class DocumentRecoveryService {
  Future<RecoveryCandidate?> read(PdfDocumentSource source);
  void schedule(PdfDocumentSource source, Uint8List revision);
  Future<void> clear(PdfDocumentSource source);
  Future<void> flush();
  Future<void> dispose();
}

final class NoopDocumentRecoveryService implements DocumentRecoveryService {
  const NoopDocumentRecoveryService();

  @override
  Future<void> clear(PdfDocumentSource source) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> flush() async {}

  @override
  Future<RecoveryCandidate?> read(PdfDocumentSource source) async => null;

  @override
  void schedule(PdfDocumentSource source, Uint8List revision) {}
}
