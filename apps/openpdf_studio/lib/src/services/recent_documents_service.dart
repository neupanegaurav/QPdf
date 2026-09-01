import 'dart:convert';

import 'package:pdf_domain/pdf_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class RecentDocument {
  const RecentDocument({
    required this.id,
    required this.displayName,
    required this.localPath,
    required this.openedAt,
    this.pinned = false,
  });

  final String id;
  final String displayName;
  final String localPath;
  final DateTime openedAt;
  final bool pinned;

  Map<String, Object> toJson() => {
    'id': id,
    'displayName': displayName,
    'localPath': localPath,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'pinned': pinned,
  };

  static RecentDocument? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final id = value['id'];
    final name = value['displayName'];
    final path = value['localPath'];
    final openedAt = DateTime.tryParse(value['openedAt'] as String? ?? '');
    if (id is! String ||
        name is! String ||
        path is! String ||
        openedAt == null) {
      return null;
    }
    return RecentDocument(
      id: id,
      displayName: name,
      localPath: path,
      openedAt: openedAt,
      pinned: value['pinned'] == true,
    );
  }
}

abstract interface class RecentDocumentsService {
  Future<List<RecentDocument>> list();
  Future<void> remember(PdfDocumentSource source);
  Future<void> remove(String id);
  Future<void> setPinned(String id, bool pinned);
  Future<void> clear();
}

final class PreferencesRecentDocumentsService
    implements RecentDocumentsService {
  static const _key = 'qpdf.recentDocuments.v1';
  static const _maximumCount = 12;

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<List<RecentDocument>> list() async {
    final raw = (await _preferences).getString(_key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return const [];
      return decoded
          .map((item) => RecentDocument.fromJson(item))
          .whereType<RecentDocument>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> remember(PdfDocumentSource source) async {
    final path = source.localPath;
    if (path == null || path.isEmpty) return;
    final current = await list();
    final previous = current.where((item) => item.id == source.id).firstOrNull;
    final updated = <RecentDocument>[
      RecentDocument(
        id: source.id,
        displayName: source.displayName,
        localPath: path,
        openedAt: DateTime.now().toUtc(),
        pinned: previous?.pinned ?? false,
      ),
      ...current.where((item) => item.id != source.id),
    ]..sort(_compareRecentDocuments);
    await _write(updated.take(_maximumCount).toList(growable: false));
  }

  @override
  Future<void> remove(String id) async {
    await _write((await list()).where((item) => item.id != id).toList());
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    final updated = [
      for (final item in await list())
        RecentDocument(
          id: item.id,
          displayName: item.displayName,
          localPath: item.localPath,
          openedAt: item.openedAt,
          pinned: item.id == id ? pinned : item.pinned,
        ),
    ]..sort(_compareRecentDocuments);
    await _write(updated);
  }

  static int _compareRecentDocuments(RecentDocument a, RecentDocument b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.openedAt.compareTo(a.openedAt);
  }

  @override
  Future<void> clear() => _write(const []);

  Future<void> _write(List<RecentDocument> items) async {
    await (await _preferences).setString(
      _key,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}

final class NoopRecentDocumentsService implements RecentDocumentsService {
  const NoopRecentDocumentsService();

  @override
  Future<void> clear() async {}
  @override
  Future<List<RecentDocument>> list() async => const [];
  @override
  Future<void> remember(PdfDocumentSource source) async {}
  @override
  Future<void> remove(String id) async {}
  @override
  Future<void> setPinned(String id, bool pinned) async {}
}
