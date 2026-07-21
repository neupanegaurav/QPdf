import 'dart:async';

import 'package:flutter/services.dart';

import 'smart_form_service.dart';

typedef SmartFormSemanticBackend =
    Future<Object?> Function(List<Map<String, Object?>> fields);

class SmartFormSemanticResult {
  const SmartFormSemanticResult({
    required this.questions,
    required this.usedModel,
    this.unavailableReason,
  });

  final List<SmartFormQuestion> questions;
  final bool usedModel;
  final String? unavailableReason;
}

/// Strict privacy and validation boundary around optional on-device models.
///
/// Only field metadata crosses the platform channel. Current/user-entered
/// values, document bytes, page text, coordinates, and signatures never do.
class SmartFormSemanticService {
  const SmartFormSemanticService({
    this.backend,
    this.timeout = const Duration(seconds: 8),
    this.modelSource = SmartFormSemanticSource.appleFoundationModel,
  });

  static const _channel = MethodChannel('studio.gaurav.qpdf/smart_form_ai');
  final SmartFormSemanticBackend? backend;
  final Duration timeout;
  final SmartFormSemanticSource modelSource;

  Future<SmartFormSemanticResult> analyze(
    List<SmartFormQuestion> questions,
  ) async {
    if (questions.isEmpty) {
      return const SmartFormSemanticResult(questions: [], usedModel: false);
    }
    final safeQuestions = questions.take(40).toList(growable: false);
    final payload = [
      for (final question in safeQuestions)
        <String, Object?>{
          'fieldName': question.fieldName,
          'label': question.label,
          'kind': question.kind.name,
          'required': question.required,
        },
    ];
    Object? response;
    try {
      response =
          await (backend != null
                  ? backend!(payload)
                  : _channel.invokeMethod<Object?>(
                      'analyzeFormFields',
                      payload,
                    ))
              .timeout(timeout);
    } on TimeoutException {
      return _fallback(questions, 'The on-device model timed out.');
    } on MissingPluginException {
      return _fallback(questions, 'No compatible system model is installed.');
    } on PlatformException catch (error) {
      return _fallback(
        questions,
        error.message ?? 'The on-device model is unavailable.',
      );
    } catch (_) {
      return _fallback(questions, 'The on-device model is unavailable.');
    }

    if (response is Map && response['status'] != 'available') {
      return _fallback(
        questions,
        _cleanText(response['reason'], maximum: 120) ??
            'The on-device model is unavailable.',
      );
    }
    final raw = response is Map ? response['suggestions'] : response;
    if (raw is! List) {
      return _fallback(questions, 'The on-device model returned invalid data.');
    }
    final originals = {
      for (final question in safeQuestions) question.fieldName: question,
    };
    final accepted = <String, SmartFormQuestion>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final fieldName = item['fieldName'];
      if (fieldName is! String || accepted.containsKey(fieldName)) continue;
      final original = originals[fieldName];
      if (original == null) continue;
      final proposedLabel = item.containsKey('label')
          ? _safeLabel(item['label'], original)
          : original.label;
      if (proposedLabel == null) continue;
      final section =
          _cleanText(item['section'], maximum: 40) ?? original.section;
      final kind = _safeKind(item['kind'], original.kind);
      if (kind == null) continue;
      accepted[fieldName] = original.copyWith(
        label: proposedLabel,
        section: section,
        kind: kind,
        semanticSource: modelSource,
      );
    }
    if (accepted.length != safeQuestions.length) {
      return _fallback(
        questions,
        'The on-device model response was incomplete.',
      );
    }
    return SmartFormSemanticResult(
      questions: [
        for (final question in questions)
          accepted[question.fieldName] ?? question,
      ],
      usedModel: true,
    );
  }

  SmartFormSemanticResult _fallback(
    List<SmartFormQuestion> questions,
    String reason,
  ) => SmartFormSemanticResult(
    questions: questions,
    usedModel: false,
    unavailableReason: reason,
  );

  String? _cleanText(Object? value, {required int maximum}) {
    if (value is! String) return null;
    final cleaned = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (cleaned.isEmpty || cleaned.length > maximum) return null;
    return cleaned;
  }

  String? _safeLabel(Object? value, SmartFormQuestion original) {
    final label = _cleanText(value, maximum: 80);
    if (label == null) return null;
    final lower = label.toLowerCase();
    if (const {
      'yes',
      'no',
      'true',
      'false',
      'none',
      'unknown',
      'n/a',
    }.contains(lower)) {
      return null;
    }
    if (RegExp(r'^[\d\s.,/+\-()$€£¥%]+$').hasMatch(label) ||
        RegExp(r'\b[^\s@]+@[^\s@]+\.[^\s@]+\b').hasMatch(label)) {
      return null;
    }

    final originalText = '${original.fieldName} ${original.label}';
    final originalTokens = _semanticTokens(originalText);
    final proposedTokens = _semanticTokens(label);
    if (originalTokens.isEmpty && proposedTokens.isEmpty) {
      // Preserve non-Latin labels while still rejecting numeric-only answers.
      return label;
    }
    if (originalTokens.intersection(proposedTokens).isEmpty) return null;
    return label;
  }

  Set<String> _semanticTokens(String value) => RegExp(r'[a-z0-9]+')
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .where((token) => token.length >= 3)
      .map(_canonicalToken)
      .where(
        (token) => !const {
          'the',
          'and',
          'for',
          'field',
          'input',
          'value',
        }.contains(token),
      )
      .toSet();

  String _canonicalToken(String token) => switch (token) {
    'dob' || 'birth' => 'date',
    'tel' || 'telephone' || 'mobile' => 'phone',
    'postal' || 'postcode' || 'zipcode' || 'zip' => 'postcode',
    'mail' || 'e-mail' => 'email',
    _ => token,
  };

  SmartFormInputKind? _safeKind(Object? value, SmartFormInputKind original) {
    if (value == null) return original;
    if (value is! String) return null;
    final proposed = SmartFormInputKind.values.where(
      (kind) => kind.name == value,
    );
    if (proposed.isEmpty) return null;
    final kind = proposed.first;
    if (original == SmartFormInputKind.checkBox ||
        original == SmartFormInputKind.choice) {
      return kind == original ? kind : null;
    }
    if (kind == SmartFormInputKind.checkBox ||
        kind == SmartFormInputKind.choice) {
      return null;
    }
    // Deterministic PDF/widget evidence remains authoritative. A model may
    // specialize a generic text field, but cannot weaken or replace an
    // already inferred semantic type such as date, email, or multiline.
    if (original != SmartFormInputKind.text) return original;
    return kind;
  }
}
