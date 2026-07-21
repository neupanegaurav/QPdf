import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/portable_ai_self_test_service.dart';

void main() {
  test(
    'passes a complete response without weakening authoritative metadata',
    () async {
      final result = await PortableAISelfTestService(
        backend: (fields, path) async {
          expect(path, '/verified/model.gguf');
          return {
            'status': 'available',
            'suggestions': [
              for (final field in fields)
                {
                  'fieldName': field['fieldName'],
                  'label': field['label'],
                  'kind': 'text',
                },
            ],
          };
        },
      ).run(modelPath: '/verified/model.gguf');

      expect(result.passed, isTrue);
      expect(result.message, contains('passed'));
    },
  );

  test('reports invalid field identity as a failed self-test', () async {
    final result = await PortableAISelfTestService(
      backend: (_, _) async => {
        'status': 'available',
        'suggestions': [
          {'fieldName': 'invented', 'label': 'Unsafe', 'kind': 'text'},
        ],
      },
    ).run(modelPath: '/verified/model.gguf');

    expect(result.passed, isFalse);
    expect(result.message, contains('incomplete'));
  });

  test('reports a model timeout without throwing', () async {
    final result = await PortableAISelfTestService(
      timeout: const Duration(milliseconds: 5),
      backend: (_, _) => Completer<Object?>().future,
    ).run(modelPath: '/verified/model.gguf');

    expect(result.passed, isFalse);
    expect(result.message, contains('timed out'));
  });
}
