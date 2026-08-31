import 'dart:async';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/app.dart';
import 'package:openpdf_studio/src/services/document_file_service.dart';
import 'package:openpdf_studio/src/services/document_recovery_service.dart';
import 'package:openpdf_studio/src/services/images_to_pdf_service.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';
import 'package:pdf_engine_api/pdf_engine_api.dart';

void main() {
  testWidgets('empty state explains the local-first workflow', (tester) async {
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(),
        fileService: _FakeFileService(),
        recoveryService: const NoopDocumentRecoveryService(),
      ),
    );

    expect(find.text('QPdf'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('Your documents stay with you'), findsOneWidget);
    expect(find.text('Open PDF'), findsOneWidget);
  });

  testWidgets('canceling the picker keeps the empty state', (tester) async {
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(),
        fileService: _FakeFileService(),
        recoveryService: const NoopDocumentRecoveryService(),
      ),
    );

    await tester.tap(find.text('Open PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('home dashboard has no overflow on phone, tablet, or desktop', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in const [
      Size(390, 844),
      Size(1024, 1366),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        QPdfApp(
          engine: _FakeEngine(),
          fileService: _FakeFileService(),
          recoveryService: const NoopDocumentRecoveryService(),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'viewport $size');
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Fill & Sign'), findsOneWidget);
      expect(find.text('Recent documents'), findsOneWidget);
    }
  });

  testWidgets('opens a selected PDF in the editor shell', (tester) async {
    final source = PdfDocumentSource(
      id: 'two-pages',
      displayName: 'sample.pdf',
      bytes: PdfBlankDocument.create(pageCount: 2),
    );
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(pageCount: 2),
        fileService: _FakeFileService(source),
        recoveryService: const NoopDocumentRecoveryService(),
      ),
    );

    await tester.tap(find.text('Open PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('sample.pdf'), findsOneWidget);
    expect(find.text('2 pages  •  PDF 1.7'), findsOneWidget);
  });

  testWidgets('All tools is searchable and grouped by workflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = PdfDocumentSource(
      id: 'tools-document',
      displayName: 'Tools.pdf',
      bytes: PdfBlankDocument.create(),
    );
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(),
        fileService: _FakeFileService(source),
        recoveryService: const NoopDocumentRecoveryService(),
      ),
    );

    await tester.tap(find.text('Open PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('document-tools-button')));
    await tester.pumpAndSettle();

    expect(find.text('All tools'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
    expect(find.text('Protect'), findsOneWidget);
    expect(find.text('Make text searchable (OCR)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('document-tools-search')),
      'accessibility',
    );
    await tester.pump();

    expect(find.text('Standards audit'), findsOneWidget);
    expect(find.text('Optimize PDF'), findsNothing);
  });

  testWidgets('desktop tabs keep independent document controllers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = PdfDocumentSource(
      id: 'first-tab',
      displayName: 'First.pdf',
      bytes: PdfBlankDocument.create(),
    );
    final second = PdfDocumentSource(
      id: 'second-tab',
      displayName: 'Second.pdf',
      bytes: PdfBlankDocument.create(pageCount: 2),
    );
    final files = _FakeFileService(first);
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(),
        fileService: files,
        recoveryService: const NoopDocumentRecoveryService(),
      ),
    );

    await tester.tap(find.text('Open PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final firstController = tester
        .widget<PdfEditorView>(find.byType(PdfEditorView))
        .controller;

    files.source = second;
    await tester.tap(find.byKey(const Key('open-pdf-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('document-tab-strip')), findsOneWidget);
    expect(find.byKey(const Key('document-tab-0')), findsOneWidget);
    expect(find.byKey(const Key('document-tab-1')), findsOneWidget);
    expect(
      tester.widget<PdfEditorView>(find.byType(PdfEditorView)).controller,
      isNot(same(firstController)),
    );

    await tester.tap(find.byKey(const Key('document-tab-0')));
    await tester.pump();
    expect(
      tester.widget<PdfEditorView>(find.byType(PdfEditorView)).controller,
      same(firstController),
    );

    await tester.tap(find.byKey(const Key('close-document-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-tab-strip')), findsNothing);
    expect(find.text('First.pdf'), findsOneWidget);
  });

  testWidgets('Fill & Sign is prominent from home and inside the editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final formEditor = PdfEditor(PdfDocument.open(PdfBlankDocument.create()));
    formEditor.addTextField(
      0,
      'Applicant name',
      const PdfRect(72, 680, 320, 716),
    );
    formEditor.addCheckBoxField(0, 'Approved', const PdfRect(72, 620, 96, 644));
    final source = PdfDocumentSource(
      id: 'form-workflow',
      displayName: 'Application Form.pdf',
      bytes: formEditor.save(),
    );
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(),
        fileService: _FakeFileService(source, '/tmp/Application Form.pdf'),
        recoveryService: const NoopDocumentRecoveryService(),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Recent documents'), findsOneWidget);
    expect(find.byKey(const Key('fill-and-sign-home-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fill-and-sign-home-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Application Form.pdf'), findsOneWidget);
    expect(
      tester.widget<PdfViewer>(find.byType(PdfViewer)).editing?.tool,
      PdfEditTool.select,
    );
    expect(
      find.byKey(const Key('fill-and-sign-toolbar-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('fill-and-sign-toolbar-button')));
    await tester.pumpAndSettle();
    expect(find.text('Smart Fill'), findsNothing);
    expect(find.text('Fill form fields'), findsOneWidget);
    expect(find.text('Type on page'), findsOneWidget);
    expect(find.text('Add handwritten signature'), findsOneWidget);
    expect(find.text('Add digital signature'), findsOneWidget);

    await tester.tap(find.text('Fill form fields'));
    await tester.pumpAndSettle();
    expect(find.text('Form fields'), findsOneWidget);
    expect(find.text('Applicant name'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(
      tester.widget<PdfViewer>(find.byType(PdfViewer)).editing?.tool,
      PdfEditTool.select,
    );

    await tester.tap(find.text('Applicant name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Jordan Example');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PdfEditorView>(find.byType(PdfEditorView))
          .controller
          ?.acroForm
          ?.fieldNamed('Applicant name')
          ?.value,
      'Jordan Example',
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('secure redaction blocks unsafe save and replaces the session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = PdfDocumentSource(
      id: 'redaction-workflow',
      displayName: 'Redaction.pdf',
      bytes: PdfBlankDocument.create(),
    );
    final files = _FakeFileService(source, '/tmp/Redaction.pdf');
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(),
        fileService: files,
        recoveryService: const NoopDocumentRecoveryService(),
      ),
    );

    await tester.tap(find.text('Open PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('secure-redaction-tool-button')),
      findsOneWidget,
    );

    final before = tester
        .widget<PdfEditorView>(find.byType(PdfEditorView))
        .controller!;
    before.addRedaction(0, const PdfRect(72, 500, 220, 560));
    await tester.pump();
    expect(
      find.byKey(const Key('secure-redaction-apply-button')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    expect(find.textContaining('not yet a secure redaction'), findsOneWidget);
    expect(files.saveCalls, 0);
    ScaffoldMessenger.of(
      tester.element(find.byType(PdfEditorView)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('secure-redaction-apply-button')));
    await tester.pumpAndSettle();
    expect(find.text('Apply secure redactions?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('secure-redaction-confirm-apply')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    final after = tester
        .widget<PdfEditorView>(find.byType(PdfEditorView))
        .controller!;
    expect(after, isNot(same(before)));
    expect(after.hasRedactionMarks, isFalse);
    ScaffoldMessenger.of(
      tester.element(find.byType(PdfEditorView)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(files.saveCalls, 1);
  });

  testWidgets('opens a PDF supplied at application launch', (tester) async {
    final source = PdfDocumentSource(
      id: 'launch-document',
      displayName: 'From Files.pdf',
      bytes: PdfBlankDocument.create(pageCount: 3),
    );
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(pageCount: 3),
        fileService: _FakeFileService(),
        recoveryService: const NoopDocumentRecoveryService(),
        initialDocument: source,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('From Files.pdf'), findsOneWidget);
    expect(find.text('3 pages  •  PDF 1.7'), findsOneWidget);
  });

  testWidgets('opens a PDF sent to an already running application', (
    tester,
  ) async {
    final incoming = StreamController<PdfDocumentSource>();
    addTearDown(incoming.close);
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(pageCount: 4),
        fileService: _FakeFileService(),
        recoveryService: const NoopDocumentRecoveryService(),
        incomingDocuments: incoming.stream,
      ),
    );

    incoming.add(
      PdfDocumentSource(
        id: 'warm-document',
        displayName: 'Shared.pdf',
        bytes: PdfBlankDocument.create(pageCount: 4),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Shared.pdf'), findsOneWidget);
    expect(find.text('4 pages  •  PDF 1.7'), findsOneWidget);
  });

  testWidgets('offers and restores compatible recovery data', (tester) async {
    final source = PdfDocumentSource(
      id: 'recoverable',
      displayName: 'recoverable.pdf',
      bytes: PdfBlankDocument.create(),
    );
    final recovered = PdfBlankDocument.create(pageCount: 2);
    final recovery = _FakeRecoveryService(
      RecoveryCandidate(
        bytes: recovered,
        updatedAt: DateTime.utc(2026, 7, 19, 10, 30),
        payloadLength: recovered.length,
        incremental: false,
      ),
    );
    await tester.pumpWidget(
      QPdfApp(
        engine: _FakeEngine(),
        fileService: _FakeFileService(source),
        recoveryService: recovery,
      ),
    );

    await tester.tap(find.text('Open PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Recover unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2 pages  •  PDF 1.7'), findsOneWidget);
  });
}

final class _FakeEngine implements PdfEngine {
  _FakeEngine({this.pageCount});

  final int? pageCount;

  @override
  PdfEngineDescriptor get descriptor => const PdfEngineDescriptor(
    id: 'fake',
    label: 'Fake',
    capabilities: {PdfEngineCapability.render},
  );

  @override
  Future<PdfOpenedDocument> open(
    PdfDocumentSource source, {
    String password = '',
  }) async {
    return PdfOpenedDocument(
      source: source,
      engine: descriptor,
      summary: PdfDocumentSummary(
        pageCount: pageCount ?? PdfDocument.open(source.bytes).pageCount,
        pdfVersion: '1.7',
      ),
    );
  }
}

final class _FakeRecoveryService implements DocumentRecoveryService {
  _FakeRecoveryService(this.candidate);

  final RecoveryCandidate? candidate;

  @override
  Future<void> clear(PdfDocumentSource source) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> flush() async {}

  @override
  Future<RecoveryCandidate?> read(PdfDocumentSource source) async => candidate;

  @override
  void schedule(PdfDocumentSource source, Uint8List revision) {}
}

final class _FakeFileService implements DocumentFileService {
  _FakeFileService([this.source, this.savePath]);

  PdfDocumentSource? source;
  final String? savePath;
  int saveCalls = 0;

  @override
  Future<List<PdfImageInput>> pickImages() async => const [];

  @override
  Future<List<PdfDocumentSource>> pickPdfs() async => const [];

  @override
  Future<PdfDocumentSource?> openRecent({
    required String id,
    required String displayName,
    required String localPath,
  }) async => source;

  @override
  Future<PdfDocumentSource?> pickPdf() async => source;

  @override
  Future<String?> savePdf(
    PdfDocumentSource source,
    Uint8List bytes, {
    Uint8List? expectedSourceBytes,
  }) async {
    saveCalls++;
    return savePath;
  }

  @override
  Future<String?> savePdfAs(String suggestedName, Uint8List bytes) async =>
      null;
}
