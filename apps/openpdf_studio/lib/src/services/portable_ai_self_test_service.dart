import 'portable_form_inference_service.dart';
import 'smart_form_semantic_service.dart';
import 'smart_form_service.dart';

typedef PortableAISelfTestBackend =
    Future<Object?> Function(
      List<Map<String, Object?>> fields,
      String modelPath,
    );

class PortableAISelfTestResult {
  const PortableAISelfTestResult({
    required this.passed,
    required this.elapsed,
    required this.message,
  });

  final bool passed;
  final Duration elapsed;
  final String message;
}

/// Runs a small end-to-end inference through the same strict boundary used by
/// Smart Fill. It tests runtime loading, structured field identity, and the
/// rule that model output cannot downgrade authoritative PDF metadata.
class PortableAISelfTestService {
  const PortableAISelfTestService({
    this.backend,
    this.timeout = const Duration(seconds: 60),
  });

  final PortableAISelfTestBackend? backend;
  final Duration timeout;

  Future<PortableAISelfTestResult> run({required String modelPath}) async {
    final stopwatch = Stopwatch()..start();
    const portable = PortableFormInferenceService();
    final semantic = await SmartFormSemanticService(
      timeout: timeout,
      modelSource: SmartFormSemanticSource.portableModel,
      backend: (fields) => backend != null
          ? backend!(fields, modelPath)
          : portable.analyze(fields, modelPath: modelPath),
    ).analyze(_probeQuestions);
    stopwatch.stop();

    if (!semantic.usedModel) {
      return PortableAISelfTestResult(
        passed: false,
        elapsed: stopwatch.elapsed,
        message:
            semantic.unavailableReason ?? 'Private inference did not complete.',
      );
    }
    final questions = semantic.questions;
    final passed =
        questions.length == _probeQuestions.length &&
        questions[0].fieldName == 'applicant_dob' &&
        questions[0].kind == SmartFormInputKind.date &&
        questions[0].section == 'Personal details' &&
        questions[1].fieldName == 'mailing_postcode' &&
        questions[1].section == 'Address' &&
        questions.every(
          (question) =>
              question.semanticSource == SmartFormSemanticSource.portableModel,
        );
    return PortableAISelfTestResult(
      passed: passed,
      elapsed: stopwatch.elapsed,
      message: passed
          ? 'Private inference and safety validation passed.'
          : 'The model response failed QPdf safety validation.',
    );
  }
}

const _probeQuestions = [
  SmartFormQuestion(
    fieldName: 'applicant_dob',
    label: 'DOB',
    kind: SmartFormInputKind.date,
    required: true,
    currentValue: '',
    section: 'Personal details',
  ),
  SmartFormQuestion(
    fieldName: 'mailing_postcode',
    label: 'Post code',
    kind: SmartFormInputKind.text,
    required: false,
    currentValue: '',
    section: 'Address',
  ),
];
