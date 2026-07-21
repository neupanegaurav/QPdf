import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'document_recovery_service.dart';
import 'native_document_recovery_service.dart';

Future<DocumentRecoveryService> createDocumentRecoveryService() async {
  final support = await getApplicationSupportDirectory();
  return NativeDocumentRecoveryService(
    Directory('${support.path}/QPdf/recovery'),
  );
}
