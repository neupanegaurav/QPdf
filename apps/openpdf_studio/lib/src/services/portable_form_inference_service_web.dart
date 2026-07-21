class PortableFormInferenceService {
  const PortableFormInferenceService({
    Object? engine,
    this.includeDebugOutput = false,
  });

  final bool includeDebugOutput;

  Future<Object?> analyze(
    List<Map<String, Object?>> fields, {
    required String modelPath,
  }) async => {
    'status': 'unavailable',
    'reason': 'Portable on-device AI is unavailable on web.',
  };
}
