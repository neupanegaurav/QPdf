import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/portable_ai_model_manager.dart';

void main() {
  test('downloads, verifies, reports, and deletes a pinned model', () async {
    final bytes = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));
    final server = await _server(bytes);
    final root = await Directory.systemTemp.createTemp('qpdf-model-test-');
    final manager = PortableAIModelManager(
      manifest: _manifest(server, bytes),
      rootDirectory: root,
    );
    addTearDown(() async {
      manager.close();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    expect((await manager.status()).state, PortableAIModelState.notDownloaded);
    var progress = 0;
    final ready = await manager.download(
      onProgress: (received, total) => progress = received,
    );

    expect(ready.state, PortableAIModelState.ready);
    expect(progress, bytes.length);
    expect(await File(ready.path!).readAsBytes(), bytes);
    expect((await manager.status()).isReady, isTrue);

    await manager.delete();
    expect((await manager.status()).state, PortableAIModelState.notDownloaded);
  });

  test('rejects corrupt bytes and removes the partial download', () async {
    final served = Uint8List.fromList([1, 2, 3, 4]);
    final expected = Uint8List.fromList([4, 3, 2, 1]);
    final server = await _server(served);
    final root = await Directory.systemTemp.createTemp('qpdf-model-test-');
    final manager = PortableAIModelManager(
      manifest: _manifest(server, expected),
      rootDirectory: root,
    );
    addTearDown(() async {
      manager.close();
      await server.close(force: true);
      if (await root.exists()) await root.delete(recursive: true);
    });

    await expectLater(manager.download(), throwsA(isA<FormatException>()));
    expect((await manager.status()).state, PortableAIModelState.notDownloaded);
    expect(
      await root
          .list(recursive: true)
          .where((entity) => entity is File)
          .isEmpty,
      isTrue,
    );
  });
}

Future<HttpServer> _server(Uint8List bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..contentLength = bytes.length
      ..add(bytes);
    await request.response.close();
  });
  return server;
}

PortableAIModelManifest _manifest(HttpServer server, Uint8List bytes) =>
    PortableAIModelManifest(
      id: 'test-model',
      displayName: 'Test model',
      fileName: 'test.gguf',
      downloadUri: Uri.parse(
        'http://${server.address.address}:${server.port}/model.gguf',
      ),
      sha256: sha256.convert(bytes).toString(),
      sizeBytes: bytes.length,
      license: 'Apache-2.0',
      sourceUri: Uri.parse('https://example.invalid/model'),
    );
