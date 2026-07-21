import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:openpdf_studio/src/services/smart_form_service.dart';
import 'package:openpdf_studio/src/services/smart_form_label_recovery_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  final root = Directory.current.path;
  final catalogFile = File('$root/../../test_corpus/real_forms/catalog.json');
  final corpus = Directory('$root/../../output/pdf/c4-real-world');
  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, Object?>;
  final reports = <Map<String, Object?>>[];
  var allChecksumsMatch = true;
  var allOpen = true;

  for (final raw in catalog['forms'] as List) {
    final entry = raw as Map<String, Object?>;
    final id = entry['id'] as String;
    final file = File('${corpus.path}/${entry['file']}');
    if (!file.existsSync()) {
      allOpen = false;
      reports.add({
        'id': entry['id'],
        'available': false,
        'error': 'Run tool/download_c4_real_forms.py first.',
      });
      continue;
    }
    final bytes = file.readAsBytesSync();
    final checksum = sha256.convert(bytes).toString();
    final checksumMatches = checksum == entry['sha256'];
    allChecksumsMatch &= checksumMatches;
    try {
      final document = PdfDocument.open(bytes);
      final form = PdfAcroForm.of(document);
      const analyzer = SmartFormAnalyzer();
      final questions = analyzer.analyze(form);
      final recovered = const SmartFormLabelRecoveryService().recover(
        document,
        form,
        questions,
      );
      final compatibility = analyzer.compatibility(form);
      final typeCounts = <String, int>{};
      var missingWidgets = 0;
      for (final field in form?.fields ?? const <PdfFormField>[]) {
        typeCounts.update(
          field.type.name,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        if (field.widgets.isEmpty || field.widgetPageIndex(0) < 0) {
          missingWidgets++;
        }
      }

      var saveReopenPassed = false;
      String? saveReopenField;
      String? verificationOutput;
      final writableText = form?.fields.where(
        (field) => field.type == PdfFieldType.text && !field.isReadOnly,
      );
      if (writableText != null && writableText.isNotEmpty) {
        saveReopenField = writableText.first.name;
        try {
          final editor = PdfEditor(PdfDocument.open(bytes));
          final target = editor.acroForm!.fieldNamed(saveReopenField)!;
          const syntheticValue = 'QPdf compatibility check';
          editor.setTextValue(target, syntheticValue);
          final saved = editor.save();
          verificationOutput = 'verified-filled-$id.pdf';
          File(
            '${corpus.path}/$verificationOutput',
          ).writeAsBytesSync(saved, flush: true);
          final reopened = PdfAcroForm.of(PdfDocument.open(saved));
          saveReopenPassed =
              reopened?.fieldNamed(saveReopenField)?.value == syntheticValue;
        } catch (_) {
          saveReopenPassed = false;
        }
      }

      reports.add({
        'id': entry['id'],
        'category': entry['category'],
        'agency': entry['agency'],
        'title': entry['title'],
        'sourcePage': entry['sourcePage'],
        'downloadUrl': entry['downloadUrl'],
        'available': true,
        'sha256': checksum,
        'checksumMatches': checksumMatches,
        'bytes': bytes.length,
        'pages': document.pageCount,
        'xfa': compatibility.hasXfa,
        'compatibility': compatibility.level.name,
        'formFields': form?.fields.length ?? 0,
        'fillableQuestions': questions.length,
        'genericLabels': compatibility.genericLabels,
        'recoveredCoordinateLabels': recovered.recoveredCount,
        'remainingGenericLabels':
            compatibility.genericLabels - recovered.recoveredCount,
        'reviewableLabelCoverage': questions.isEmpty
            ? 0
            : (questions.length -
                      compatibility.genericLabels +
                      recovered.recoveredCount) /
                  questions.length,
        'recoveredLabelExamples': [
          for (final question in recovered.questions)
            if (question.labelSource ==
                SmartFormLabelSource.coordinateSuggestion)
              {
                'fieldName': question.fieldName,
                'label': question.label,
                'confidence': question.labelConfidence,
              },
        ].take(8).toList(),
        'semanticLabelCoverage': questions.isEmpty
            ? 0
            : (questions.length - compatibility.genericLabels) /
                  questions.length,
        'missingWidgetLocations': missingWidgets,
        'fieldTypes': typeCounts,
        'saveReopenField': saveReopenField,
        'saveReopenPassed': saveReopenPassed,
        'verificationOutput': verificationOutput,
      });
    } catch (error) {
      allOpen = false;
      reports.add({
        'id': entry['id'],
        'available': true,
        'checksumMatches': checksumMatches,
        'error': error.toString(),
      });
    }
  }

  final output = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'policy': catalog['policy'],
    'allChecksumsMatch': allChecksumsMatch,
    'allDocumentsOpen': allOpen,
    'forms': reports,
  };
  final report = File('${corpus.path}/compatibility-report.json');
  report.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
    flush: true,
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
  if (!allChecksumsMatch || !allOpen) exitCode = 1;
}
