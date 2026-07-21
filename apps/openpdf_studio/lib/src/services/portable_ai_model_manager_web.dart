import 'portable_ai_model_types.dart';

class PortableAIModelManager {
  PortableAIModelManager({
    PortableAIModelManifest? manifest,
    Object? rootDirectory,
    Object? client,
  }) : manifest = manifest ?? qpdfPortableFormModel;

  final PortableAIModelManifest manifest;
  static bool get isSupported => false;

  Future<PortableAIModelStatus> status() async => PortableAIModelStatus(
    state: PortableAIModelState.unavailable,
    manifest: manifest,
    message: 'Portable on-device AI is unavailable on web.',
  );

  Future<PortableAIModelStatus> download({
    PortableAIModelProgress? onProgress,
  }) => throw UnsupportedError('Portable on-device AI is unavailable on web.');

  Future<void> delete() async {}
  void close() {}
}
