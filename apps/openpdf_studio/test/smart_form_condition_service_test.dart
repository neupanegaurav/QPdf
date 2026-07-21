import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/smart_form_condition_service.dart';
import 'package:openpdf_studio/src/services/smart_form_service.dart';

void main() {
  const service = SmartFormConditionService();

  test('hides spouse fields only after an explicit unmarried answer', () {
    final questions = [
      _question('marital_status', kind: SmartFormInputKind.choice),
      _question('spouse_full_name'),
      _question('applicant_name'),
    ];

    expect(
      service.visibleQuestions(
        questions,
        textValues: const {},
        checks: const {},
        choices: const {'marital_status': null},
      ),
      hasLength(3),
    );
    expect(
      service
          .visibleQuestions(
            questions,
            textValues: const {},
            checks: const {},
            choices: const {'marital_status': 'Single'},
          )
          .map((question) => question.fieldName),
      ['marital_status', 'applicant_name'],
    );
  });

  test('shows employer fields when employment changes to yes', () {
    final questions = [
      _question('currently_employed', kind: SmartFormInputKind.checkBox),
      _question('employer_name'),
    ];
    expect(
      service.visibleQuestions(
        questions,
        textValues: const {},
        checks: const {'currently_employed': false},
        choices: const {},
      ),
      hasLength(1),
    );
    expect(
      service.visibleQuestions(
        questions,
        textValues: const {},
        checks: const {'currently_employed': true},
        choices: const {},
      ),
      hasLength(2),
    );
  });

  test('never hides a pre-filled conditional child', () {
    final questions = [
      _question('has_spouse', kind: SmartFormInputKind.checkBox),
      _question('spouse_full_name', currentValue: 'Existing Person'),
    ];
    expect(
      service.visibleQuestions(
        questions,
        textValues: const {},
        checks: const {'has_spouse': false},
        choices: const {},
      ),
      hasLength(2),
    );
  });

  test('same-address checkbox inversely controls mailing fields', () {
    final questions = [
      _question(
        'same_as_residential_address',
        kind: SmartFormInputKind.checkBox,
      ),
      _question('mailing_postcode'),
    ];
    expect(
      service.visibleQuestions(
        questions,
        textValues: const {},
        checks: const {'same_as_residential_address': true},
        choices: const {},
      ),
      hasLength(1),
    );
  });

  test('radio answer hides and restores dependent fields', () {
    final questions = [
      _question('has_dependents', kind: SmartFormInputKind.choice),
      _question('dependent_full_name'),
      _question('dependent_date_of_birth'),
      _question('applicant_name'),
    ];

    expect(
      service
          .visibleQuestions(
            questions,
            textValues: const {},
            checks: const {},
            choices: const {'has_dependents': 'No'},
          )
          .map((question) => question.fieldName),
      ['has_dependents', 'applicant_name'],
    );
    expect(
      service.visibleQuestions(
        questions,
        textValues: const {},
        checks: const {},
        choices: const {'has_dependents': 'Yes'},
      ),
      hasLength(4),
    );
  });

  test(
    'numeric dependent controller treats zero as no and positive as yes',
    () {
      final questions = [
        _question('number_of_dependents', kind: SmartFormInputKind.number),
        _question('dependent_full_name'),
      ];

      expect(
        service.visibleQuestions(
          questions,
          textValues: const {'number_of_dependents': '0'},
          checks: const {},
          choices: const {},
        ),
        hasLength(1),
      );
      expect(
        service.visibleQuestions(
          questions,
          textValues: const {'number_of_dependents': '2'},
          checks: const {},
          choices: const {},
        ),
        hasLength(2),
      );
    },
  );

  test('numeric dependent count limits numbered repeated rows', () {
    final questions = [
      _question('number_of_dependents', kind: SmartFormInputKind.number),
      _question('dependent_1_full_name'),
      _question('dependent_1_date_of_birth'),
      _question('dependent_2_full_name'),
      _question('dependent_3_full_name'),
      _question('applicant_name'),
    ];

    expect(
      service
          .visibleQuestions(
            questions,
            textValues: const {'number_of_dependents': '2'},
            checks: const {},
            choices: const {},
          )
          .map((question) => question.fieldName),
      [
        'number_of_dependents',
        'dependent_1_full_name',
        'dependent_1_date_of_birth',
        'dependent_2_full_name',
        'applicant_name',
      ],
    );
  });

  test('pre-filled repeated row stays visible above the dependent count', () {
    final questions = [
      _question('number_of_dependents', kind: SmartFormInputKind.number),
      _question('dependent_1_full_name'),
      _question('dependent_2_full_name', currentValue: 'Existing Dependent'),
    ];

    expect(
      service.visibleQuestions(
        questions,
        textValues: const {'number_of_dependents': '1'},
        checks: const {},
        choices: const {},
      ),
      hasLength(3),
    );
  });
}

SmartFormQuestion _question(
  String fieldName, {
  SmartFormInputKind kind = SmartFormInputKind.text,
  String currentValue = '',
}) => SmartFormQuestion(
  fieldName: fieldName,
  label: fieldName.replaceAll('_', ' '),
  kind: kind,
  required: false,
  currentValue: currentValue,
);
