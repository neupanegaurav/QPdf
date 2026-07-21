import 'dart:convert';
import 'dart:io';

import 'package:openpdf_studio/src/services/smart_form_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  final corpus = Directory(
    '${Directory.current.path}/../../output/pdf/c4-form-corpus',
  );
  final manifest =
      jsonDecode(File('${corpus.path}/manifest.json').readAsStringSync())
          as Map<String, Object?>;
  final forms = manifest['forms'] as List;
  var fields = 0;
  var exactMatches = 0;
  for (final rawForm in forms) {
    final expectedForm = rawForm as Map<String, Object?>;
    final fileName = expectedForm['file'] as String;
    final document = PdfDocument.open(
      File('${corpus.path}/$fileName').readAsBytesSync(),
    );
    final questions = const SmartFormAnalyzer().analyze(
      PdfAcroForm.of(document),
    );
    final byName = {
      for (final question in questions) question.fieldName: question,
    };
    for (final rawField in expectedForm['fields'] as List) {
      fields++;
      final expected = rawField as Map<String, Object?>;
      final question = byName[expected['name']];
      if (question != null &&
          question.kind.name == expected['kind'] &&
          question.required == expected['required'] &&
          question.section == expected['expectedSection']) {
        exactMatches++;
      }
    }
  }

  final source = File(
    '${corpus.path}/01-identity-application.pdf',
  ).readAsBytesSync();
  final editor = PdfEditor(PdfDocument.open(source));
  editor.setTextValue(
    editor.acroForm!.fieldNamed('full_name')!,
    'QPdf Synthetic Person',
  );
  editor.setTextValue(
    editor.acroForm!.fieldNamed('date_of_birth')!,
    '2000-01-01',
  );
  editor.setTextValue(
    editor.acroForm!.fieldNamed('email_address')!,
    'synthetic@example.invalid',
  );
  editor.setCheckBoxValue(
    editor.acroForm!.fieldNamed('confirm_details')!,
    true,
  );
  final filledFile = File('${corpus.path}/verified-filled-identity.pdf');
  filledFile.writeAsBytesSync(editor.save(), flush: true);
  final reopened = PdfAcroForm.of(
    PdfDocument.open(filledFile.readAsBytesSync()),
  )!;
  final saveReopenPassed =
      reopened.fieldNamed('full_name')!.value == 'QPdf Synthetic Person' &&
      reopened.fieldNamed('date_of_birth')!.value == '2000-01-01' &&
      reopened.fieldNamed('email_address')!.value ==
          'synthetic@example.invalid' &&
      reopened.fieldNamed('confirm_details')!.isChecked;

  final radioSource = File(
    '${corpus.path}/06-dependent-benefits-multipage.pdf',
  ).readAsBytesSync();
  final radioEditor = PdfEditor(PdfDocument.open(radioSource));
  radioEditor.setRadioValue(
    radioEditor.acroForm!.fieldNamed('has_dependents')!,
    'Yes',
  );
  radioEditor.setTextValue(
    radioEditor.acroForm!.fieldNamed('dependent_full_name')!,
    'Synthetic Dependent',
  );
  final filledRadioFile = File('${corpus.path}/verified-filled-dependents.pdf');
  filledRadioFile.writeAsBytesSync(radioEditor.save(), flush: true);
  final radioReopenedDocument = PdfDocument.open(
    filledRadioFile.readAsBytesSync(),
  );
  final radioReopened = PdfAcroForm.of(radioReopenedDocument)!;
  final radioSaveReopenPassed =
      radioReopenedDocument.pageCount == 2 &&
      radioReopened.fieldNamed('has_dependents')!.value == 'Yes' &&
      radioReopened.fieldNamed('dependent_full_name')!.value ==
          'Synthetic Dependent';

  final householdSource = File(
    '${corpus.path}/08-household-support-five-page.pdf',
  ).readAsBytesSync();
  final householdEditor = PdfEditor(PdfDocument.open(householdSource));
  householdEditor.setTextValue(
    householdEditor.acroForm!.fieldNamed('number_of_dependents')!,
    '2',
  );
  householdEditor.setTextValue(
    householdEditor.acroForm!.fieldNamed('dependent_1_full_name')!,
    'Synthetic Dependent One',
  );
  householdEditor.setTextValue(
    householdEditor.acroForm!.fieldNamed('dependent_2_full_name')!,
    'Synthetic Dependent Two',
  );
  final filledHouseholdFile = File(
    '${corpus.path}/verified-filled-household.pdf',
  );
  filledHouseholdFile.writeAsBytesSync(householdEditor.save(), flush: true);
  final householdReopenedDocument = PdfDocument.open(
    filledHouseholdFile.readAsBytesSync(),
  );
  final householdReopened = PdfAcroForm.of(householdReopenedDocument)!;
  final repeatedSaveReopenPassed =
      householdReopenedDocument.pageCount == 5 &&
      householdReopened.fieldNamed('number_of_dependents')!.value == '2' &&
      householdReopened.fieldNamed('dependent_1_full_name')!.value ==
          'Synthetic Dependent One' &&
      householdReopened.fieldNamed('dependent_2_full_name')!.value ==
          'Synthetic Dependent Two';

  List<SmartFormQuestion> analyzed(String fileName) =>
      const SmartFormAnalyzer().analyze(
        PdfAcroForm.of(
          PdfDocument.open(File('${corpus.path}/$fileName').readAsBytesSync()),
        ),
      );
  final hindi = analyzed('09-hindi-contact.pdf');
  final japanese = analyzed('10-japanese-contact.pdf');
  final unicodeLabelsPassed =
      hindi
              .singleWhere((question) => question.fieldName == 'full_name')
              .label ==
          'पूरा नाम' &&
      japanese
              .singleWhere((question) => question.fieldName == 'email_address')
              .label ==
          'メールアドレス';

  final results = {
    'forms': forms.length,
    'fields': fields,
    'exactMetadataMatches': exactMatches,
    'metadataAccuracy': fields == 0 ? 0 : exactMatches / fields,
    'saveReopenPassed': saveReopenPassed,
    'radioSaveReopenPassed': radioSaveReopenPassed,
    'repeatedSaveReopenPassed': repeatedSaveReopenPassed,
    'unicodeLabelsPassed': unicodeLabelsPassed,
    'filledFixture': filledFile.path,
    'filledRadioFixture': filledRadioFile.path,
    'filledHouseholdFixture': filledHouseholdFile.path,
  };
  File('${corpus.path}/benchmark-results.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(results)}\n',
    flush: true,
  );
  stdout.writeln(jsonEncode(results));
  if (exactMatches != fields ||
      !saveReopenPassed ||
      !radioSaveReopenPassed ||
      !repeatedSaveReopenPassed ||
      !unicodeLabelsPassed) {
    exitCode = 1;
  }
}
