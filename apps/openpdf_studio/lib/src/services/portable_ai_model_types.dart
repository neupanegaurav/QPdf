class PortableAIModelManifest {
  const PortableAIModelManifest({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.downloadUri,
    required this.sha256,
    required this.sizeBytes,
    required this.license,
    required this.sourceUri,
  });

  final String id;
  final String displayName;
  final String fileName;
  final Uri downloadUri;
  final String sha256;
  final int sizeBytes;
  final String license;
  final Uri sourceUri;

  double get sizeMegabytes => sizeBytes / (1024 * 1024);
}

final qpdfPortableFormModel = PortableAIModelManifest(
  id: 'smollm2-135m-instruct-q4-k-m-476854d',
  displayName: 'QPdf Portable Form Intelligence',
  fileName: 'SmolLM2-135M-Instruct.Q4_K_M.gguf',
  downloadUri: Uri.parse(
    'https://huggingface.co/QuantFactory/SmolLM2-135M-Instruct-GGUF/'
    'resolve/476854d00ede130660aba430d15f9347ad2e7d0e/'
    'SmolLM2-135M-Instruct.Q4_K_M.gguf?download=true',
  ),
  sha256: '8030f04528538d47bda434f6f0bdf3952c40a58123e4d5e755332f23731a8684',
  sizeBytes: 105454144,
  license: 'Apache-2.0',
  sourceUri: Uri.parse(
    'https://huggingface.co/QuantFactory/SmolLM2-135M-Instruct-GGUF/'
    'tree/476854d00ede130660aba430d15f9347ad2e7d0e',
  ),
);

enum PortableAIModelState { unavailable, notDownloaded, ready, invalid }

class PortableAIModelStatus {
  const PortableAIModelStatus({
    required this.state,
    required this.manifest,
    this.path,
    this.message,
  });

  final PortableAIModelState state;
  final PortableAIModelManifest manifest;
  final String? path;
  final String? message;

  bool get isReady => state == PortableAIModelState.ready;
}

typedef PortableAIModelProgress = void Function(int received, int total);
