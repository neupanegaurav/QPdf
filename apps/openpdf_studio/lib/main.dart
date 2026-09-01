import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/engine/dart_pdf_engine.dart';
import 'src/services/create_document_recovery_service.dart';
import 'src/services/document_file_service.dart';
import 'src/services/initial_document_service.dart';
import 'src/services/open_documents_session_service.dart';
import 'src/services/recent_documents_service.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final recoveryService = await createDocumentRecoveryService();
  final initialDocument = await loadInitialDocument(arguments);
  runApp(
    QPdfApp(
      engine: DartPdfEngine(),
      fileService: PlatformDocumentFileService(),
      recoveryService: recoveryService,
      recentDocumentsService: PreferencesRecentDocumentsService(),
      openDocumentsSessionService: PreferencesOpenDocumentsSessionService(),
      initialDocument: initialDocument,
      incomingDocuments: incomingDocuments,
    ),
  );
}
