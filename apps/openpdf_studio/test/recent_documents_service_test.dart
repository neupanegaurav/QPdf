import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/recent_documents_service.dart';
import 'package:pdf_domain/pdf_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('remembers local documents newest first without duplicates', () async {
    final service = PreferencesRecentDocumentsService();
    final first = _source('first', '/documents/first.pdf');
    final second = _source('second', '/documents/second.pdf');

    await service.remember(first);
    await service.remember(second);
    await service.remember(first);

    final items = await service.list();
    expect(items.map((item) => item.id), ['first', 'second']);
  });

  test('does not persist non-local picker results', () async {
    final service = PreferencesRecentDocumentsService();
    await service.remember(
      PdfDocumentSource(id: 'web', displayName: 'web.pdf', bytes: Uint8List(0)),
    );
    expect(await service.list(), isEmpty);
  });

  test(
    'caps history at twelve documents and removes missing entries',
    () async {
      final service = PreferencesRecentDocumentsService();
      for (var index = 0; index < 14; index++) {
        await service.remember(_source('doc-$index', '/documents/$index.pdf'));
      }
      expect(await service.list(), hasLength(12));
      await service.remove('doc-13');
      expect(
        (await service.list()).map((item) => item.id),
        isNot(contains('doc-13')),
      );
    },
  );
}

PdfDocumentSource _source(String id, String path) => PdfDocumentSource(
  id: id,
  displayName: '$id.pdf',
  bytes: Uint8List(0),
  localPath: path,
);
