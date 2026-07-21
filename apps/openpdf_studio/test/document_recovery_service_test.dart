import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/native_document_recovery_service.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';

void main() {
  late Directory directory;
  late NativeDocumentRecoveryService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qpdf-recovery-');
    service = NativeDocumentRecoveryService(
      directory,
      debounce: const Duration(days: 1),
    );
  });

  tearDown(() async {
    await service.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('stores an incremental suffix and reconstructs a valid PDF', () async {
    final baseBytes = PdfBlankDocument.create();
    final document = PdfDocument.open(baseBytes);
    final editor = PdfEditor(document)..setInfo(title: 'Recovered title');
    final revision = editor.save();
    final source = PdfDocumentSource(
      id: 'incremental.pdf',
      displayName: 'incremental.pdf',
      bytes: baseBytes,
    );

    service.schedule(source, revision);
    await service.flush();
    final candidate = await service.read(source);

    expect(candidate, isNotNull);
    expect(candidate!.incremental, isTrue);
    expect(candidate.payloadLength, revision.length - baseBytes.length);
    final reopened = PdfDocument.open(candidate.bytes);
    expect(reopened.info['Title'], 'Recovered title');
  });

  test('falls back to a full snapshot for a compact revision', () async {
    final source = PdfDocumentSource(
      id: 'compact.pdf',
      displayName: 'compact.pdf',
      bytes: PdfBlankDocument.create(),
    );
    final compact = PdfBlankDocument.create(pageCount: 2);

    service.schedule(source, compact);
    await service.flush();
    final candidate = await service.read(source);

    expect(candidate, isNotNull);
    expect(candidate!.incremental, isFalse);
    expect(candidate.payloadLength, compact.length);
    expect(PdfDocument.open(candidate.bytes).pageCount, 2);
  });

  test('ignores a journal when the source bytes changed externally', () async {
    final source = PdfDocumentSource(
      id: 'external-change.pdf',
      displayName: 'external-change.pdf',
      bytes: PdfBlankDocument.create(),
    );
    service.schedule(source, PdfBlankDocument.create(pageCount: 2));
    await service.flush();

    final changedSource = PdfDocumentSource(
      id: source.id,
      displayName: source.displayName,
      bytes: PdfBlankDocument.create(pageCount: 3),
    );
    expect(await service.read(changedSource), isNull);
  });

  test('clear removes pending and persisted recovery data', () async {
    final source = PdfDocumentSource(
      id: 'clear.pdf',
      displayName: 'clear.pdf',
      bytes: PdfBlankDocument.create(),
    );
    service.schedule(source, PdfBlankDocument.create(pageCount: 2));
    await service.flush();

    await service.clear(source);

    expect(await service.read(source), isNull);
    expect(directory.listSync(), isEmpty);
  });
}
