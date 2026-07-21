import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/smart_form_label_recovery_service.dart';
import 'package:openpdf_studio/src/services/smart_form_service.dart';
import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  test('builds a useful private questionnaire from AcroForm metadata', () {
    final editor = PdfEditor(PdfDocument.open(PdfBlankDocument.create()));
    final email = editor.addTextField(
      0,
      'applicant_email_1',
      const PdfRect(72, 680, 320, 716),
    );
    email.dict['TU'] = CosString.fromText('Primary e-mail address');
    email.dict['Ff'] = const CosInteger(PdfFormField.requiredFlag);
    editor.addCheckBoxField(0, 'accept_terms', const PdfRect(72, 620, 96, 644));

    final document = PdfDocument.open(editor.save());
    final questions = const SmartFormAnalyzer().analyze(
      PdfAcroForm.of(document),
    );

    expect(questions, hasLength(2));
    expect(questions.first.fieldName, 'applicant_email_1');
    expect(questions.first.label, 'Primary e mail address');
    expect(questions.first.kind, SmartFormInputKind.email);
    expect(questions.first.required, isTrue);
    expect(questions.last.label, 'Accept terms');
    expect(questions.last.kind, SmartFormInputKind.checkBox);
  });

  test('does not expose read-only fields as questions', () {
    final editor = PdfEditor(PdfDocument.open(PdfBlankDocument.create()));
    final locked = editor.addTextField(
      0,
      'internal_reference',
      const PdfRect(72, 680, 320, 716),
    );
    locked.dict['Ff'] = const CosInteger(PdfFormField.readOnlyFlag);

    final document = PdfDocument.open(editor.save());
    expect(
      const SmartFormAnalyzer().analyze(PdfAcroForm.of(document)),
      isEmpty,
    );
  });

  test('simplifies hierarchical producer names and flags generic labels', () {
    final editor = PdfEditor(PdfDocument.open(PdfBlankDocument.create()));
    editor.addTextField(
      0,
      'topmostSubform[0].Page1[0].f1_01[0]',
      const PdfRect(72, 680, 320, 716),
    );
    final form = PdfAcroForm.of(PdfDocument.open(editor.save()))!;
    final questions = const SmartFormAnalyzer().analyze(form);

    expect(questions.single.label, 'Form field f1 01');
    expect(questions.single.labelSource, SmartFormLabelSource.genericFallback);
    expect(
      const SmartFormAnalyzer().compatibility(form).level,
      SmartFormCompatibilityLevel.partial,
    );
  });

  test('leaves a generic label unchanged without reliable nearby text', () {
    final editor = PdfEditor(PdfDocument.open(PdfBlankDocument.create()));
    editor.addTextField(
      0,
      'topmostSubform[0].Page1[0].f1_01[0]',
      const PdfRect(72, 680, 320, 716),
    );
    final document = PdfDocument.open(editor.save());
    final form = PdfAcroForm.of(document)!;
    final questions = const SmartFormAnalyzer().analyze(form);
    final result = const SmartFormLabelRecoveryService().recover(
      document,
      form,
      questions,
    );

    expect(result.recoveredCount, 0);
    expect(result.questions.single.label, 'Form field f1 01');
    expect(
      result.questions.single.labelSource,
      SmartFormLabelSource.genericFallback,
    );
    expect(result.questions.single.labelNeedsReview, isTrue);
  });

  test('reports hybrid XFA forms as partial compatibility', () {
    final editor = PdfEditor(PdfDocument.open(PdfBlankDocument.create()));
    editor.addTextField(0, 'applicant_name', const PdfRect(72, 680, 320, 716));
    editor.acroForm!.dict['XFA'] = CosString.fromText('synthetic XFA packet');
    final form = PdfAcroForm.of(PdfDocument.open(editor.save()))!;
    final result = const SmartFormAnalyzer().compatibility(form);

    expect(result.hasXfa, isTrue);
    expect(result.level, SmartFormCompatibilityLevel.partial);
    expect(result.fillableFields, 1);
  });
}
