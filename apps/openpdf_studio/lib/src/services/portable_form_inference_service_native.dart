import 'dart:async';
import 'dart:convert';

import 'package:lib_llama_cpp/lib_llama_cpp.dart';

class PortableFormInferenceService {
  const PortableFormInferenceService({
    this.engine = const LibLlamaCpp(),
    this.includeDebugOutput = false,
  });

  final LlamaEngine engine;
  final bool includeDebugOutput;

  Future<Object?> analyze(
    List<Map<String, Object?>> fields, {
    required String modelPath,
  }) async {
    final safeFields = fields
        .take(40)
        .map((field) {
          // Existing PDF widget types are often generic (`text`) and can anchor a
          // small model to the wrong answer. Send only the clues needed to infer a
          // useful question type; fieldName remains the immutable join key.
          return <String, Object?>{
            if (field['fieldName'] case final String name) 'fieldName': name,
            if (field['label'] case final String label) 'label': label,
            if (field['required'] case final bool required)
              'required': required,
            if (field['options'] case final List options) 'options': options,
          };
        })
        .toList(growable: false);
    final prompt = _prompt(safeFields);
    final output = StringBuffer();
    final errors = <String>[];
    final commands = Stream<LlamaCommand>.fromIterable([
      LlamaLoadModelCommand(modelPath: modelPath, contextSize: 2048),
      LlamaGenerateCommand(
        prompt: prompt,
        // The model returns only a flat name-to-label map. Keeping the budget
        // proportional avoids long tail generation on tablet CPUs when a tiny
        // model does not emit its chat stop token.
        maxTokens: (24 + (safeFields.length * 24)).clamp(64, 768),
        temperature: 0,
        topP: 1,
        stop: const ['<|im_end|>', '<|im_start|>'],
      ),
      const LlamaDisposeCommand(),
    ]);
    await for (final response in engine.transform(commands)) {
      switch (response) {
        case LlamaTokenResponse(:final text):
          output.write(text);
        case LlamaErrorResponse(:final message):
          errors.add(message);
        default:
          break;
      }
    }
    if (errors.isNotEmpty) {
      return {'status': 'unavailable', 'reason': errors.join(' | ')};
    }
    final decoded = _decodeObject(output.toString());
    if (decoded == null) {
      return {
        'status': 'unavailable',
        'reason': 'The portable model returned invalid structured output.',
        if (includeDebugOutput) 'debugOutput': output.toString(),
      };
    }
    final structuredItems = switch (decoded) {
      {'suggestions': final List items} => items,
      // SmolLM2 sometimes faithfully returns the input under `fields`. Treat
      // that as a valid no-op enhancement; the strict semantic layer still
      // supplies authoritative type and section data.
      {'fields': final List items} => items,
      _ => null,
    };
    final suggestions = structuredItems != null
        ? structuredItems
              .whereType<Map>()
              .map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList(growable: false)
        : [
            for (final entry in decoded.entries)
              if (entry.value is String)
                <String, Object?>{'fieldName': entry.key, 'label': entry.value},
          ];
    final expectedNames = safeFields
        .map((field) => field['fieldName'])
        .whereType<String>()
        .toList(growable: false);
    final returnedNames = suggestions
        .map((item) => item['fieldName'])
        .whereType<String>()
        .toList(growable: false);
    if (suggestions.length != expectedNames.length ||
        returnedNames.length != expectedNames.length ||
        returnedNames.toSet().length != expectedNames.length ||
        !expectedNames.every(returnedNames.contains)) {
      return {
        'status': 'unavailable',
        'reason': 'The portable model did not preserve the input field names.',
        if (includeDebugOutput) 'debugOutput': output.toString(),
      };
    }
    return {'status': 'available', 'suggestions': suggestions};
  }

  String _prompt(List<Map<String, Object?>> fields) =>
      '''<|im_start|>system
You rewrite PDF field labels for people. Reply with one compact single-line JSON object only. Each key must be an exact fieldName and each value must be its short human label. Use every input field once. Never add answers, fields, or explanations.<|im_end|>
<|im_start|>user
Fields: ${jsonEncode(fields)}
JSON:<|im_end|>
<|im_start|>assistant
''';

  Map<String, Object?>? _decodeObject(String value) {
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(value.substring(start, end + 1));
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }
}
