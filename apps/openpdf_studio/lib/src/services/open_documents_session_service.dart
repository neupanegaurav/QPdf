import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

final class OpenDocumentSessionEntry {
  const OpenDocumentSessionEntry({
    required this.id,
    required this.displayName,
    required this.localPath,
  });

  final String id;
  final String displayName;
  final String localPath;

  Map<String, String> toJson() => {
    'id': id,
    'displayName': displayName,
    'localPath': localPath,
  };

  static OpenDocumentSessionEntry? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final id = value['id'];
    final displayName = value['displayName'];
    final localPath = value['localPath'];
    if (id is! String ||
        displayName is! String ||
        localPath is! String ||
        localPath.isEmpty) {
      return null;
    }
    return OpenDocumentSessionEntry(
      id: id,
      displayName: displayName,
      localPath: localPath,
    );
  }
}

final class OpenDocumentsSession {
  const OpenDocumentsSession({
    required this.documents,
    required this.activeDocumentId,
  });

  final List<OpenDocumentSessionEntry> documents;
  final String? activeDocumentId;
}

abstract interface class OpenDocumentsSessionService {
  Future<OpenDocumentsSession> read();
  Future<void> write(OpenDocumentsSession session);
  Future<void> clear();
}

final class PreferencesOpenDocumentsSessionService
    implements OpenDocumentsSessionService {
  static const _key = 'qpdf.openDocuments.v1';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<OpenDocumentsSession> read() async {
    final raw = (await _preferences).getString(_key);
    if (raw == null) {
      return const OpenDocumentsSession(documents: [], activeDocumentId: null);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return const OpenDocumentsSession(
          documents: [],
          activeDocumentId: null,
        );
      }
      final rawDocuments = decoded['documents'];
      final documents = rawDocuments is List<Object?>
          ? rawDocuments
                .map(OpenDocumentSessionEntry.fromJson)
                .whereType<OpenDocumentSessionEntry>()
                .take(8)
                .toList(growable: false)
          : const <OpenDocumentSessionEntry>[];
      final active = decoded['activeDocumentId'];
      return OpenDocumentsSession(
        documents: documents,
        activeDocumentId: active is String ? active : null,
      );
    } on FormatException {
      return const OpenDocumentsSession(documents: [], activeDocumentId: null);
    }
  }

  @override
  Future<void> write(OpenDocumentsSession session) async {
    if (session.documents.isEmpty) return clear();
    await (await _preferences).setString(
      _key,
      jsonEncode({
        'documents': session.documents.map((item) => item.toJson()).toList(),
        'activeDocumentId': session.activeDocumentId,
      }),
    );
  }

  @override
  Future<void> clear() async => (await _preferences).remove(_key);
}

final class NoopOpenDocumentsSessionService
    implements OpenDocumentsSessionService {
  const NoopOpenDocumentsSessionService();

  @override
  Future<void> clear() async {}

  @override
  Future<OpenDocumentsSession> read() async =>
      const OpenDocumentsSession(documents: [], activeDocumentId: null);

  @override
  Future<void> write(OpenDocumentsSession session) async {}
}
