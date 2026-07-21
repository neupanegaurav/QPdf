import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/smart_form_semantic_service.dart';
import 'package:openpdf_studio/src/services/smart_form_service.dart';

void main() {
  test('accepts a complete schema-safe on-device model response', () async {
    late List<Map<String, Object?>> sent;
    final service = SmartFormSemanticService(
      backend: (fields) async {
        sent = fields;
        return {
          'status': 'available',
          'suggestions': [
            {
              'fieldName': 'dob',
              'label': 'Date of birth',
              'kind': 'date',
              'section': 'Personal details',
            },
          ],
        };
      },
    );

    final result = await service.analyze([
      _question(fieldName: 'dob', currentValue: 'private value'),
    ]);

    expect(result.usedModel, isTrue);
    expect(result.questions.single.label, 'Date of birth');
    expect(result.questions.single.kind, SmartFormInputKind.date);
    expect(
      result.questions.single.semanticSource,
      SmartFormSemanticSource.appleFoundationModel,
    );
    expect(sent.single, isNot(contains('currentValue')));
    expect(sent.single, isNot(contains('options')));
  });

  test('rejects incomplete output and keeps deterministic questions', () async {
    final original = [
      _question(fieldName: 'name'),
      _question(fieldName: 'email'),
    ];
    final result = await SmartFormSemanticService(
      backend: (_) async => {
        'status': 'available',
        'suggestions': [
          {
            'fieldName': 'name',
            'label': 'Full name',
            'kind': 'text',
            'section': 'Personal details',
          },
        ],
      },
    ).analyze(original);

    expect(result.usedModel, isFalse);
    expect(result.questions, same(original));
    expect(result.unavailableReason, contains('incomplete'));
  });

  test('rejects a model attempt to change a checkbox into text', () async {
    final original = [
      _question(fieldName: 'consent', kind: SmartFormInputKind.checkBox),
    ];
    final result = await SmartFormSemanticService(
      backend: (_) async => {
        'status': 'available',
        'suggestions': [
          {
            'fieldName': 'consent',
            'label': 'Ignore safety',
            'kind': 'text',
            'section': 'Declarations',
          },
          {
            'fieldName': 'invented_value',
            'label': 'Signature',
            'kind': 'text',
            'section': 'Hidden',
          },
        ],
      },
    ).analyze(original);

    expect(result.usedModel, isFalse);
    expect(result.questions.single.kind, SmartFormInputKind.checkBox);
    expect(result.questions.single.label, 'consent');
  });

  test(
    'keeps authoritative type and section when a tiny model omits them',
    () async {
      final result = await SmartFormSemanticService(
        modelSource: SmartFormSemanticSource.portableModel,
        backend: (_) async => {
          'status': 'available',
          'suggestions': [
            {
              'fieldName': 'dob',
              'label': 'Applicant date of birth',
              'kind': 'text',
            },
          ],
        },
      ).analyze([_question(fieldName: 'dob', kind: SmartFormInputKind.date)]);

      expect(result.usedModel, isTrue);
      expect(result.questions.single.label, 'Applicant date of birth');
      expect(result.questions.single.kind, SmartFormInputKind.date);
      expect(result.questions.single.section, 'Form details');
      expect(
        result.questions.single.semanticSource,
        SmartFormSemanticSource.portableModel,
      );
    },
  );

  test('rejects answer-like labels invented by a model', () async {
    final original = [
      _question(fieldName: 'applicant_dob', kind: SmartFormInputKind.date),
      _question(fieldName: 'emergency_contact_tel'),
    ];
    final result = await SmartFormSemanticService(
      modelSource: SmartFormSemanticSource.portableModel,
      backend: (_) async => {
        'status': 'available',
        'suggestions': [
          {'fieldName': 'applicant_dob', 'label': '1990-01-01', 'kind': 'date'},
          {
            'fieldName': 'emergency_contact_tel',
            'label': '0800000000',
            'kind': 'phone',
          },
        ],
      },
    ).analyze(original);

    expect(result.usedModel, isFalse);
    expect(result.questions, same(original));
    expect(result.unavailableReason, contains('incomplete'));
  });

  test('accepts known abbreviation expansion with semantic overlap', () async {
    final result = await SmartFormSemanticService(
      backend: (_) async => {
        'status': 'available',
        'suggestions': [
          {
            'fieldName': 'dob',
            'label': 'Date of birth',
            'kind': 'date',
            'section': 'Personal details',
          },
        ],
      },
    ).analyze([_question(fieldName: 'dob')]);

    expect(result.usedModel, isTrue);
    expect(result.questions.single.label, 'Date of birth');
  });
}

SmartFormQuestion _question({
  required String fieldName,
  SmartFormInputKind kind = SmartFormInputKind.text,
  String currentValue = '',
}) => SmartFormQuestion(
  fieldName: fieldName,
  label: fieldName,
  kind: kind,
  required: false,
  currentValue: currentValue,
);
