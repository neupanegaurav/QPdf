import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/open_documents_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists document order and active document', () async {
    final service = PreferencesOpenDocumentsSessionService();
    await service.write(
      const OpenDocumentsSession(
        documents: [
          OpenDocumentSessionEntry(
            id: 'one',
            displayName: 'One.pdf',
            localPath: '/documents/one.pdf',
          ),
          OpenDocumentSessionEntry(
            id: 'two',
            displayName: 'Two.pdf',
            localPath: '/documents/two.pdf',
          ),
        ],
        activeDocumentId: 'one',
      ),
    );

    final restored = await service.read();
    expect(restored.documents.map((item) => item.id), ['one', 'two']);
    expect(restored.activeDocumentId, 'one');
  });

  test('empty session clears persisted state', () async {
    final service = PreferencesOpenDocumentsSessionService();
    await service.write(
      const OpenDocumentsSession(
        documents: [
          OpenDocumentSessionEntry(
            id: 'one',
            displayName: 'One.pdf',
            localPath: '/documents/one.pdf',
          ),
        ],
        activeDocumentId: 'one',
      ),
    );
    await service.write(
      const OpenDocumentsSession(documents: [], activeDocumentId: null),
    );
    expect((await service.read()).documents, isEmpty);
  });
}
