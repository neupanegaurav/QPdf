import 'dart:math' as math;

import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import 'smart_form_service.dart';

class SmartFormLabelRecoveryResult {
  const SmartFormLabelRecoveryResult({
    required this.questions,
    required this.recoveredCount,
  });

  final List<SmartFormQuestion> questions;
  final int recoveredCount;
}

/// Recovers reviewable labels for fields with unusable producer metadata.
///
/// PDF widget coordinates and positioned page text are the only inputs. The
/// service deliberately rejects distant, instruction-like, or ambiguous text;
/// an on-device language model never supplies or overrides these coordinates.
class SmartFormLabelRecoveryService {
  const SmartFormLabelRecoveryService({this.minimumConfidence = 0.84});

  final double minimumConfidence;

  SmartFormLabelRecoveryResult recover(
    PdfDocument document,
    PdfAcroForm? form,
    List<SmartFormQuestion> questions,
  ) {
    if (form == null || questions.isEmpty) {
      return SmartFormLabelRecoveryResult(
        questions: questions,
        recoveredCount: 0,
      );
    }
    final fields = {for (final field in form.fields) field.name: field};
    final pageRuns = <int, List<PdfExtractedRun>>{};
    final labelCounts = <String, int>{};
    var recoveredCount = 0;
    final recovered = <SmartFormQuestion>[];
    for (final question in questions) {
      if (question.labelSource != SmartFormLabelSource.genericFallback) {
        recovered.add(question);
        continue;
      }
      final field = fields[question.fieldName];
      final suggestion = field == null
          ? null
          : _suggest(document, field, pageRuns);
      if (suggestion == null || suggestion.confidence < minimumConfidence) {
        recovered.add(question);
        continue;
      }
      final count = (labelCounts[suggestion.label] ?? 0) + 1;
      labelCounts[suggestion.label] = count;
      final label = count == 1
          ? suggestion.label
          : '${suggestion.label} (part $count)';
      recovered.add(
        question.copyWith(
          label: label,
          labelSource: SmartFormLabelSource.coordinateSuggestion,
          labelConfidence: suggestion.confidence,
        ),
      );
      recoveredCount++;
    }
    return SmartFormLabelRecoveryResult(
      questions: recovered,
      recoveredCount: recoveredCount,
    );
  }

  _LabelSuggestion? _suggest(
    PdfDocument document,
    PdfFormField field,
    Map<int, List<PdfExtractedRun>> pageRuns,
  ) {
    if (field.widgets.isEmpty) return null;
    final pageIndex = field.widgetPageIndex(0);
    final rect = field.widgetRect(0);
    if (pageIndex < 0 || rect == null) return null;
    final runs = pageRuns.putIfAbsent(
      pageIndex,
      () => PdfTextExtractor.extract(document, pageIndex).runs,
    );
    _LabelSuggestion? best;
    for (final run in runs) {
      final label = _cleanCandidate(run.text);
      if (!_isUsable(label)) continue;
      final score = _score(rect, run.bounds, field.type, label);
      if (score == null || score < minimumConfidence) continue;
      if (best == null || score > best.confidence) {
        best = _LabelSuggestion(label, score);
      }
    }
    return best;
  }

  double? _score(PdfRect field, PdfRect text, PdfFieldType type, String label) {
    final fieldCenterY = (field.bottom + field.top) / 2;
    final textCenterY = (text.bottom + text.top) / 2;
    final vertical = (fieldCenterY - textCenterY).abs();
    final horizontalOverlap =
        math.min(field.right, text.right) - math.max(field.left, text.left);
    double? score;

    // Most text controls place their caption immediately above the widget.
    final aboveGap = text.bottom - field.top;
    if (aboveGap >= -2 &&
        aboveGap <= 26 &&
        horizontalOverlap >= math.min(12, field.width.abs() * 0.2)) {
      score =
          0.78 +
          (aboveGap <= 14 ? 0.08 : 0) +
          (text.left >= field.left - 8 ? 0.04 : 0);
    }

    // Checkbox/radio captions conventionally sit directly on the right.
    final rightGap = text.left - field.right;
    if ((type == PdfFieldType.checkBox || type == PdfFieldType.radioGroup) &&
        rightGap >= -2 &&
        rightGap <= 22 &&
        vertical <= 10) {
      final candidate = 0.84 + (rightGap <= 10 ? 0.06 : 0);
      score = score == null ? candidate : math.max(score, candidate);
    }

    // Short code boxes sometimes follow a descriptive caption on the left.
    final leftGap = field.left - text.right;
    if (type == PdfFieldType.text &&
        leftGap >= -2 &&
        leftGap <= 72 &&
        vertical <= 10 &&
        field.width.abs() <= 120) {
      final candidate = 0.76 + (leftGap <= 28 ? 0.07 : 0);
      score = score == null ? candidate : math.max(score, candidate);
    }

    if (score == null) return null;
    if (_hasLabelHint(label)) score += 0.05;
    if (label.length > 72) score -= 0.06;
    return score.clamp(0.0, 1.0);
  }

  String _cleanCandidate(String source) {
    var value = source
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s•]+|[:*\s]+$'), '')
        .trim();
    final sentence = RegExp(r'^(.{3,80}?)[.!?](?:\s|$)').firstMatch(value);
    if (sentence != null) value = sentence.group(1)!.trim();
    return value;
  }

  bool _isUsable(String value) {
    if (value.length < 2 || value.length > 100) return false;
    if (!RegExp(r'[A-Za-z\p{L}]', unicode: true).hasMatch(value)) return false;
    final lower = value.toLowerCase();
    const rejected = [
      'before you begin',
      'specific instructions',
      'department of the treasury',
      'internal revenue service',
      'for instructions',
      'do not send',
    ];
    return !rejected.any(lower.contains);
  }

  bool _hasLabelHint(String value) {
    final lower = value.toLowerCase();
    const hints = [
      'name',
      'address',
      'email',
      'phone',
      'date',
      'city',
      'state',
      'zip',
      'number',
      'classification',
      'corporation',
      'partnership',
      'estate',
      'exempt',
      'account',
      'signature',
      'individual',
    ];
    return hints.any(lower.contains);
  }
}

class _LabelSuggestion {
  const _LabelSuggestion(this.label, this.confidence);

  final String label;
  final double confidence;
}
