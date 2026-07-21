import 'package:flutter_test/flutter_test.dart';
import 'package:lib_llama_cpp/lib_llama_cpp.dart';
import 'package:lib_llama_cpp_platform_interface/lib_llama_cpp_platform_interface.dart';
import 'package:openpdf_studio/src/services/portable_form_inference_service.dart';

void main() {
  test('parses JSON-only portable model output', () async {
    final service = PortableFormInferenceService(
      engine: _FakeEngine([
        const LlamaTokenResponse(text: '```json\n', index: 0),
        const LlamaTokenResponse(
          text:
              '{"suggestions":[{"fieldName":"dob","label":"Date of birth","kind":"date","section":"Personal details"}]}',
          index: 1,
        ),
        const LlamaTokenResponse(text: '\n```', index: 2),
        const LlamaDoneResponse(),
      ]),
    );

    final result = await service.analyze([
      {'fieldName': 'dob', 'label': 'DOB', 'kind': 'text'},
    ], modelPath: '/verified/model.gguf');

    expect(result, isA<Map>());
    expect((result as Map)['status'], 'available');
    expect((result['suggestions'] as List), hasLength(1));
  });

  test('converts runtime errors into an unavailable result', () async {
    final result = await PortableFormInferenceService(
      engine: _FakeEngine([
        const LlamaErrorResponse(message: 'model load failed'),
      ]),
    ).analyze(const [], modelPath: '/missing.gguf');

    expect((result as Map)['status'], 'unavailable');
    expect(result['reason'], contains('model load failed'));
  });
}

class _FakeEngine implements LlamaEngine {
  const _FakeEngine(this.responses);

  final List<LlamaResponse> responses;

  @override
  Stream<LlamaResponse> transform(
    Stream<LlamaCommand> commands, {
    LlamaState initialState = const LlamaState.empty(),
    LlamaCppLibraryRequest libraryRequest = const LlamaCppLibraryRequest(),
  }) async* {
    await commands.toList();
    yield* Stream.fromIterable(responses);
  }
}
