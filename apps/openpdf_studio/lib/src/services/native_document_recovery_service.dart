import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf_domain/pdf_domain.dart';

import 'document_recovery_service.dart';

final class NativeDocumentRecoveryService implements DocumentRecoveryService {
  NativeDocumentRecoveryService(
    this.root, {
    this.debounce = const Duration(seconds: 1),
  });

  static final Uint8List _magic = Uint8List.fromList(utf8.encode('QPDFREC1'));

  final Directory root;
  final Duration debounce;
  final Map<String, _PendingRecovery> _pending = {};
  final Map<String, Timer> _timers = {};

  @override
  void schedule(PdfDocumentSource source, Uint8List revision) {
    final key = _key(source.id);
    _pending[key] = _PendingRecovery(source, Uint8List.fromList(revision));
    _timers.remove(key)?.cancel();
    _timers[key] = Timer(debounce, () {
      _timers.remove(key);
      final pending = _pending.remove(key);
      if (pending != null) unawaited(_write(key, pending));
    });
  }

  @override
  Future<RecoveryCandidate?> read(PdfDocumentSource source) async {
    final file = _fileFor(source.id);
    if (!await file.exists()) return null;
    try {
      final data = await file.readAsBytes();
      if (data.length < _magic.length + 4) return null;
      for (var index = 0; index < _magic.length; index++) {
        if (data[index] != _magic[index]) return null;
      }

      final headerLength = ByteData.sublistView(
        data,
        _magic.length,
        _magic.length + 4,
      ).getUint32(0, Endian.big);
      final headerStart = _magic.length + 4;
      final payloadStart = headerStart + headerLength;
      if (headerLength <= 0 || payloadStart > data.length) return null;

      final header =
          jsonDecode(utf8.decode(data.sublist(headerStart, payloadStart)))
              as Map<String, Object?>;
      if (header['sourceId'] != source.id ||
          header['baseHash'] != _hash(source.bytes) ||
          header['baseLength'] != source.bytes.length) {
        return null;
      }

      final payload = Uint8List.sublistView(data, payloadStart);
      final incremental = header['mode'] == 'delta';
      final recovered = incremental
          ? Uint8List.fromList([...source.bytes, ...payload])
          : Uint8List.fromList(payload);
      if (_hash(recovered) != header['resultHash'] || !_isPdf(recovered)) {
        return null;
      }

      return RecoveryCandidate(
        bytes: recovered,
        updatedAt: DateTime.parse(header['updatedAt']! as String),
        payloadLength: payload.length,
        incremental: incremental,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> clear(PdfDocumentSource source) async {
    final key = _key(source.id);
    _timers.remove(key)?.cancel();
    _pending.remove(key);
    final file = _fileFor(source.id);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> flush() async {
    final keys = _pending.keys.toList(growable: false);
    for (final key in keys) {
      _timers.remove(key)?.cancel();
      final pending = _pending.remove(key);
      if (pending != null) await _write(key, pending);
    }
  }

  @override
  Future<void> dispose() async {
    await flush();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  Future<void> _write(String key, _PendingRecovery pending) async {
    if (!_isPdf(pending.revision)) return;
    await root.create(recursive: true);
    final source = pending.source;
    final isDelta = _startsWith(pending.revision, source.bytes);
    final payload = isDelta
        ? Uint8List.sublistView(pending.revision, source.bytes.length)
        : pending.revision;
    final header = utf8.encode(
      jsonEncode({
        'schema': 1,
        'sourceId': source.id,
        'baseHash': _hash(source.bytes),
        'baseLength': source.bytes.length,
        'resultHash': _hash(pending.revision),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'mode': isDelta ? 'delta' : 'full',
      }),
    );
    final headerSize = ByteData(4)..setUint32(0, header.length, Endian.big);
    final bytes = Uint8List.fromList([
      ..._magic,
      ...headerSize.buffer.asUint8List(),
      ...header,
      ...payload,
    ]);
    await _replaceFile(_fileForKey(key), bytes);
  }

  File _fileFor(String id) => _fileForKey(_key(id));
  File _fileForKey(String key) => File('${root.path}/$key.qpdf-recovery');
  String _key(String id) => sha256.convert(utf8.encode(id)).toString();
  String _hash(Uint8List bytes) => sha256.convert(bytes).toString();

  bool _startsWith(Uint8List value, Uint8List prefix) {
    if (value.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (value[index] != prefix[index]) return false;
    }
    return true;
  }

  bool _isPdf(Uint8List bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46 &&
      bytes[4] == 0x2d;

  Future<void> _replaceFile(File target, Uint8List bytes) async {
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${target.path}.$nonce.tmp');
    final backup = File('${target.path}.$nonce.backup');
    try {
      final sink = temporary.openWrite();
      sink.add(bytes);
      await sink.flush();
      await sink.close();
      try {
        await temporary.rename(target.path);
      } on FileSystemException {
        if (await target.exists()) await target.rename(backup.path);
        try {
          await temporary.rename(target.path);
          if (await backup.exists()) await backup.delete();
        } catch (_) {
          if (await backup.exists() && !await target.exists()) {
            await backup.rename(target.path);
          }
          rethrow;
        }
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

final class _PendingRecovery {
  const _PendingRecovery(this.source, this.revision);

  final PdfDocumentSource source;
  final Uint8List revision;
}
