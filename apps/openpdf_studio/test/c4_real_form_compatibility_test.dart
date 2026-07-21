import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/smart_form_service.dart';
import 'package:openpdf_studio/src/services/smart_form_label_recovery_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  final root = Directory.current.path;
  final corpus = Directory('$root/../../output/pdf/c4-real-world');
  final catalog =
      jsonDecode(
            File(
              '$root/../../test_corpus/real_forms/catalog.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;

  test('pinned official forms open with expected compatibility boundaries', () {
    const expected =
        <
          String,
          ({
            int pages,
            int questions,
            bool xfa,
            SmartFormCompatibilityLevel level,
          })
        >{
          'irs-w9': (
            pages: 6,
            questions: 23,
            xfa: true,
            level: SmartFormCompatibilityLevel.partial,
          ),
          'uscis-i9': (
            pages: 4,
            questions: 128,
            xfa: false,
            level: SmartFormCompatibilityLevel.full,
          ),
          'va-10-5345': (
            pages: 2,
            questions: 57,
            xfa: true,
            level: SmartFormCompatibilityLevel.partial,
          ),
        };

    for (final raw in catalog['forms'] as List) {
      final entry = raw as Map<String, Object?>;
      final id = entry['id'] as String;
      final bytes = File('${corpus.path}/${entry['file']}').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), entry['sha256'], reason: id);
      final document = PdfDocument.open(bytes);
      final form = PdfAcroForm.of(document);
      final compatibility = const SmartFormAnalyzer().compatibility(form);
      final boundary = expected[id]!;

      expect(document.pageCount, boundary.pages, reason: id);
      expect(compatibility.fillableFields, boundary.questions, reason: id);
      expect(compatibility.hasXfa, boundary.xfa, reason: id);
      expect(compatibility.level, boundary.level, reason: id);
    }
  });

  test('official forms preserve a synthetic value through save and reopen', () {
    for (final raw in catalog['forms'] as List) {
      final entry = raw as Map<String, Object?>;
      final id = entry['id'] as String;
      final bytes = File('${corpus.path}/${entry['file']}').readAsBytesSync();
      final editor = PdfEditor(PdfDocument.open(bytes));
      final textField = editor.acroForm!.fields.firstWhere(
        (field) => field.type == PdfFieldType.text && !field.isReadOnly,
      );
      editor.setTextValue(textField, 'QPdf compatibility check');
      final reopened = PdfAcroForm.of(PdfDocument.open(editor.save()))!;
      expect(
        reopened.fieldNamed(textField.name)!.value,
        'QPdf compatibility check',
        reason: id,
      );
    }
  });

  test(
    'W-9 recovers only high-confidence reviewable labels from page text',
    () {
      final entry = (catalog['forms'] as List)
          .cast<Map<String, Object?>>()
          .singleWhere((item) => item['id'] == 'irs-w9');
      final document = PdfDocument.open(
        File('${corpus.path}/${entry['file']}').readAsBytesSync(),
      );
      final form = PdfAcroForm.of(document)!;
      final result = const SmartFormLabelRecoveryService().recover(
        document,
        form,
        const SmartFormAnalyzer().analyze(form),
      );

      expect(result.recoveredCount, 21);
      expect(result.questions.first.label, 'Name of entity/individual');
      expect(
        result.questions.first.labelSource,
        SmartFormLabelSource.coordinateSuggestion,
      );
      expect(
        result.questions.first.labelConfidence,
        greaterThanOrEqualTo(0.84),
      );
      expect(
        result.questions
            .where(
              (question) =>
                  question.labelSource == SmartFormLabelSource.genericFallback,
            )
            .length,
        2,
        reason:
            'Ambiguous fields must remain generic instead of being guessed.',
      );
    },
  );
}
