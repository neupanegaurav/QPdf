import 'document_recovery_service.dart';

Future<DocumentRecoveryService> createDocumentRecoveryService() async =>
    const NoopDocumentRecoveryService();
