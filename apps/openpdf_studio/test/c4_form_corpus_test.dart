import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/smart_form_condition_service.dart';
import 'package:openpdf_studio/src/services/smart_form_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  final corpus = Directory(
    '${Directory.current.path}/../../output/pdf/c4-form-corpus',
  );

  test('independent C4 AcroForms match all expected Smart Fill metadata', () {
    final manifest =
        jsonDecode(File('${corpus.path}/manifest.json').readAsStringSync())
            as Map<String, Object?>;
    final forms = manifest['forms'] as List;
    var evaluatedFields = 0;

    for (final rawForm in forms) {
      final expectedForm = rawForm as Map<String, Object?>;
      final fileName = expectedForm['file'] as String;
      final document = PdfDocument.open(
        File('${corpus.path}/$fileName').readAsBytesSync(),
      );
      final questions = const SmartFormAnalyzer().analyze(
        PdfAcroForm.of(document),
      );
      final expectedFields = expectedForm['fields'] as List;
      evaluatedFields += expectedFields.length;
      expect(questions, hasLength(expectedFields.length), reason: fileName);
      final byName = {
        for (final question in questions) question.fieldName: question,
      };
      for (final rawField in expectedFields) {
        final expected = rawField as Map<String, Object?>;
        final name = expected['name'] as String;
        final question = byName[name];
        expect(question, isNotNull, reason: '$fileName: $name');
        expect(
          question!.kind.name,
          expected['kind'],
          reason: '$fileName: $name kind',
        );
        expect(
          question.required,
          expected['required'],
          reason: '$fileName: $name required',
        );
        expect(
          question.section,
          expected['expectedSection'],
          reason: '$fileName: $name section',
        );
      }
    }

    expect(forms, hasLength(10));
    expect(evaluatedFields, 83);
  });

  test('conditional corpus forms hide only explicitly inapplicable blanks', () {
    const analyzer = SmartFormAnalyzer();
    const conditions = SmartFormConditionService();

    List<SmartFormQuestion> questions(String fileName) => analyzer.analyze(
      PdfAcroForm.of(
        PdfDocument.open(File('${corpus.path}/$fileName').readAsBytesSync()),
      ),
    );

    final employment = questions('02-employment-application.pdf');
    final employmentVisible = conditions.visibleQuestions(
      employment,
      textValues: {for (final question in employment) question.fieldName: ''},
      checks: const {},
      choices: const {'employment_status': 'Unemployed'},
    );
    expect(employmentVisible.map((question) => question.fieldName), [
      'applicant_name',
      'employment_status',
    ]);

    final rental = questions('03-rental-application.pdf');
    final rentalVisible = conditions.visibleQuestions(
      rental,
      textValues: {for (final question in rental) question.fieldName: ''},
      checks: const {'different_mailing_address': false},
      choices: const {},
    );
    expect(rentalVisible.map((question) => question.fieldName), [
      'applicant_name',
      'number_of_occupants',
      'has_pets',
      'different_mailing_address',
    ]);

    final dependents = questions('06-dependent-benefits-multipage.pdf');
    final dependentsHidden = conditions.visibleQuestions(
      dependents,
      textValues: {for (final question in dependents) question.fieldName: ''},
      checks: const {},
      choices: const {'has_dependents': 'No'},
    );
    expect(dependentsHidden.map((question) => question.fieldName), [
      'applicant_name',
      'has_dependents',
      'email_address',
      'phone_number',
      'benefit_reference',
      'confirm_application',
    ]);

    final household = questions('08-household-support-five-page.pdf');
    final householdVisible = conditions.visibleQuestions(
      household,
      textValues: {
        for (final question in household) question.fieldName: '',
        'number_of_dependents': '2',
      },
      checks: const {},
      choices: const {
        'marital_status': 'Single',
        'employment_status': 'Unemployed',
      },
    );
    final visibleNames = householdVisible
        .map((question) => question.fieldName)
        .toSet();
    expect(visibleNames, isNot(contains('spouse_full_name')));
    expect(visibleNames, contains('dependent_2_full_name'));
    expect(visibleNames, isNot(contains('dependent_3_full_name')));
    expect(visibleNames, isNot(contains('employer_name')));
  });

  test('multi-page radio and Arabic metadata survive native parsing', () {
    final multiPage = PdfDocument.open(
      File(
        '${corpus.path}/06-dependent-benefits-multipage.pdf',
      ).readAsBytesSync(),
    );
    expect(multiPage.pageCount, 2);
    final radio = PdfAcroForm.of(multiPage)!.fieldNamed('has_dependents')!;
    expect(radio.type, PdfFieldType.radioGroup);
    expect(radio.value, 'No');
    expect(radio.onStates, containsAll(<String>['Yes', 'No']));

    final arabic = const SmartFormAnalyzer().analyze(
      PdfAcroForm.of(
        PdfDocument.open(
          File('${corpus.path}/07-arabic-contact.pdf').readAsBytesSync(),
        ),
      ),
    );
    expect(arabic, hasLength(5));
    expect(
      arabic.singleWhere((question) => question.fieldName == 'full_name').label,
      'الاسم الكامل',
    );
    expect(
      arabic
          .singleWhere((question) => question.fieldName == 'email_address')
          .label,
      'البريد الإلكتروني',
    );
  });

  test('five-page repeated form and complex-script labels parse exactly', () {
    final household = PdfDocument.open(
      File(
        '${corpus.path}/08-household-support-five-page.pdf',
      ).readAsBytesSync(),
    );
    expect(household.pageCount, 5);
    expect(PdfAcroForm.of(household)!.fields, hasLength(28));

    List<SmartFormQuestion> questions(String fileName) =>
        const SmartFormAnalyzer().analyze(
          PdfAcroForm.of(
            PdfDocument.open(
              File('${corpus.path}/$fileName').readAsBytesSync(),
            ),
          ),
        );
    final hindi = questions('09-hindi-contact.pdf');
    final japanese = questions('10-japanese-contact.pdf');
    expect(
      hindi.singleWhere((question) => question.fieldName == 'full_name').label,
      'पूरा नाम',
    );
    expect(
      japanese
          .singleWhere((question) => question.fieldName == 'email_address')
          .label,
      'メールアドレス',
    );
  });

  test('independent form values survive QPdf save and reopen', () {
    final source = File(
      '${corpus.path}/01-identity-application.pdf',
    ).readAsBytesSync();
    final editor = PdfEditor(PdfDocument.open(source));
    final name = editor.acroForm!.fieldNamed('full_name')!;
    final confirmation = editor.acroForm!.fieldNamed('confirm_details')!;
    editor.setTextValue(name, 'QPdf Synthetic Person');
    editor.setCheckBoxValue(confirmation, true);

    final reopened = PdfAcroForm.of(PdfDocument.open(editor.save()))!;
    expect(reopened.fieldNamed('full_name')!.value, 'QPdf Synthetic Person');
    expect(reopened.fieldNamed('confirm_details')!.isChecked, isTrue);
  });

  test('multi-page radio and dependent values survive save and reopen', () {
    final source = File(
      '${corpus.path}/06-dependent-benefits-multipage.pdf',
    ).readAsBytesSync();
    final editor = PdfEditor(PdfDocument.open(source));
    editor.setRadioValue(editor.acroForm!.fieldNamed('has_dependents')!, 'Yes');
    editor.setTextValue(
      editor.acroForm!.fieldNamed('dependent_full_name')!,
      'Synthetic Dependent',
    );

    final reopenedDocument = PdfDocument.open(editor.save());
    final reopened = PdfAcroForm.of(reopenedDocument)!;
    expect(reopenedDocument.pageCount, 2);
    expect(reopened.fieldNamed('has_dependents')!.value, 'Yes');
    expect(
      reopened.fieldNamed('dependent_full_name')!.value,
      'Synthetic Dependent',
    );
  });
}
