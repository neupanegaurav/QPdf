import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openpdf_studio/src/services/portable_ai_self_test_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('portable AI self-test passes end to end', (tester) async {
    const modelPath = String.fromEnvironment('QPDF_PORTABLE_MODEL');
    expect(modelPath, isNotEmpty, reason: 'Pass QPDF_PORTABLE_MODEL.');
    final result = await const PortableAISelfTestService().run(
      modelPath: modelPath,
    );
    // Kept in the integration log as reproducible benchmark evidence.
    // ignore: avoid_print
    print(
      'QPDF_PORTABLE_AI_SELF_TEST_MS=${result.elapsed.inMilliseconds} '
      'PASSED=${result.passed} MESSAGE=${result.message}',
    );
    expect(result.passed, isTrue, reason: result.message);
  });
}
