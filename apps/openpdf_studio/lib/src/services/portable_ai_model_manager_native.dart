import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'portable_ai_model_types.dart';

class PortableAIModelManager {
  PortableAIModelManager({
    PortableAIModelManifest? manifest,
    this.rootDirectory,
    HttpClient? client,
  }) : manifest = manifest ?? qpdfPortableFormModel,
       _client = client ?? HttpClient();

  final PortableAIModelManifest manifest;
  final Directory? rootDirectory;
  final HttpClient _client;

  static bool get isSupported => true;

  Future<Directory> _directory() async {
    final base = rootDirectory ?? await getApplicationSupportDirectory();
    return Directory('${base.path}/qpdf/models');
  }

  Future<File> _modelFile() async =>
      File('${(await _directory()).path}/${manifest.fileName}');

  Future<PortableAIModelStatus> status() async {
    final model = await _modelFile();
    if (!await model.exists()) {
      return PortableAIModelStatus(
        state: PortableAIModelState.notDownloaded,
        manifest: manifest,
      );
    }
    final valid = await _verify(model);
    return PortableAIModelStatus(
      state: valid ? PortableAIModelState.ready : PortableAIModelState.invalid,
      manifest: manifest,
      path: model.path,
      message: valid ? null : 'The stored model failed integrity verification.',
    );
  }

  Future<PortableAIModelStatus> download({
    PortableAIModelProgress? onProgress,
  }) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final model = await _modelFile();
    if (await model.exists() && await _verify(model)) return status();
    final partial = File('${model.path}.download');
    if (await partial.exists()) await partial.delete();

    final request = await _client.getUrl(manifest.downloadUri);
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Model download failed with HTTP ${response.statusCode}.',
        uri: manifest.downloadUri,
      );
    }
    final sink = partial.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, manifest.sizeBytes);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    if (!await _verify(partial)) {
      await partial.delete();
      throw const FormatException(
        'Downloaded model failed size or SHA-256 verification.',
      );
    }
    if (await model.exists()) await model.delete();
    await partial.rename(model.path);
    return PortableAIModelStatus(
      state: PortableAIModelState.ready,
      manifest: manifest,
      path: model.path,
    );
  }

  Future<void> delete() async {
    final model = await _modelFile();
    final partial = File('${model.path}.download');
    if (await model.exists()) await model.delete();
    if (await partial.exists()) await partial.delete();
  }

  Future<bool> _verify(File file) async {
    if (await file.length() != manifest.sizeBytes) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == manifest.sha256;
  }

  void close() => _client.close(force: true);
}
