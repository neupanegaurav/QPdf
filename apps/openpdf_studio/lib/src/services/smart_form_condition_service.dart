import 'smart_form_service.dart';

enum _ConditionGroup { spouse, employment, mailing, dependents }

class SmartFormConditionService {
  const SmartFormConditionService();

  bool isController(SmartFormQuestion question) =>
      _controllerGroup(question) != null;

  List<SmartFormQuestion> visibleQuestions(
    List<SmartFormQuestion> questions, {
    required Map<String, String> textValues,
    required Map<String, bool> checks,
    required Map<String, String?> choices,
  }) {
    final decisions = <_ConditionGroup, bool?>{};
    int? dependentLimit;
    for (final question in questions) {
      final group = _controllerGroup(question);
      if (group == null) continue;
      decisions[group] = _decision(
        question,
        textValues: textValues,
        checks: checks,
        choices: choices,
      );
      if (group == _ConditionGroup.dependents &&
          question.kind != SmartFormInputKind.checkBox &&
          question.kind != SmartFormInputKind.choice) {
        dependentLimit = int.tryParse(
          (textValues[question.fieldName] ?? '').trim(),
        );
      }
    }
    return [
      for (final question in questions)
        if (_isVisible(question, decisions, dependentLimit)) question,
    ];
  }

  bool _isVisible(
    SmartFormQuestion question,
    Map<_ConditionGroup, bool?> decisions,
    int? dependentLimit,
  ) {
    if (question.currentValue.trim().isNotEmpty) return true;
    final child = _childGroup(question);
    if (child == null) return true;
    if (decisions[child] == false) return false;
    if (child == _ConditionGroup.dependents && dependentLimit != null) {
      final ordinal = _dependentOrdinal(question);
      if (ordinal != null && ordinal > dependentLimit) return false;
    }
    return true;
  }

  int? _dependentOrdinal(SmartFormQuestion question) {
    final value = _searchable(question);
    final numeric = RegExp(r'\bdependent\s+(\d+)\b').firstMatch(value);
    if (numeric != null) return int.tryParse(numeric.group(1)!);
    for (final entry in const {
      'first dependent': 1,
      'second dependent': 2,
      'third dependent': 3,
      'fourth dependent': 4,
      'fifth dependent': 5,
    }.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    return null;
  }

  bool? _decision(
    SmartFormQuestion question, {
    required Map<String, String> textValues,
    required Map<String, bool> checks,
    required Map<String, String?> choices,
  }) {
    final group = _controllerGroup(question);
    if (group == null) return null;
    if (question.kind == SmartFormInputKind.checkBox) {
      final checked = checks[question.fieldName] ?? false;
      return group == _ConditionGroup.mailing &&
              _searchable(question).contains('same')
          ? !checked
          : checked;
    }
    final answer = switch (question.kind) {
      SmartFormInputKind.choice => choices[question.fieldName],
      _ => textValues[question.fieldName],
    };
    if (answer == null || answer.trim().isEmpty) return null;
    final value = answer.toLowerCase().replaceAll(RegExp(r'[_\-]+'), ' ');
    return switch (group) {
      _ConditionGroup.spouse => _classified(
        value,
        positive: const ['married', 'partnered', 'civil partner', 'yes'],
        negative: const [
          'unmarried',
          'single',
          'divorced',
          'widowed',
          'separated',
          'no',
          'none',
        ],
      ),
      _ConditionGroup.employment => _classified(
        value,
        positive: const ['employed', 'self employed', 'yes'],
        negative: const [
          'unemployed',
          'not employed',
          'retired',
          'student',
          'no',
        ],
      ),
      _ConditionGroup.mailing => _classified(
        value,
        positive: const ['different', 'separate', 'yes'],
        negative: const ['same', 'no'],
      ),
      _ConditionGroup.dependents => _dependentDecision(value),
    };
  }

  bool? _dependentDecision(String value) {
    final normalized = value.trim();
    final number = num.tryParse(normalized);
    if (number != null) return number > 0;
    return _classified(
      normalized,
      positive: const ['yes', 'has dependents', 'have dependents'],
      negative: const ['no', 'none', 'without dependents'],
    );
  }

  bool? _classified(
    String value, {
    required List<String> positive,
    required List<String> negative,
  }) {
    if (negative.any(value.contains)) return false;
    if (positive.any(value.contains)) return true;
    return null;
  }

  _ConditionGroup? _controllerGroup(SmartFormQuestion question) {
    final value = _searchable(question);
    if (value.contains('marital status') ||
        value.contains('has spouse') ||
        value.contains('have spouse') ||
        value.contains('are you married')) {
      return _ConditionGroup.spouse;
    }
    if (value.contains('employment status') ||
        value.contains('currently employed') ||
        value.contains('has employer') ||
        value.contains('have employer')) {
      return _ConditionGroup.employment;
    }
    if (value.contains('different mailing') ||
        value.contains('separate mailing') ||
        value.contains('same as residential') ||
        value.contains('same as home address')) {
      return _ConditionGroup.mailing;
    }
    if (value.contains('has dependents') ||
        value.contains('have dependents') ||
        value.contains('any dependents') ||
        value.contains('number of dependents') ||
        value.contains('dependent status')) {
      return _ConditionGroup.dependents;
    }
    return null;
  }

  _ConditionGroup? _childGroup(SmartFormQuestion question) {
    if (isController(question)) return null;
    final value = _searchable(question);
    if (value.contains('spouse') || value.contains('partner name')) {
      return _ConditionGroup.spouse;
    }
    if (value.contains('employer') ||
        value.contains('occupation') ||
        value.contains('job title') ||
        value.contains('work phone') ||
        question.section == 'Employment and income') {
      return _ConditionGroup.employment;
    }
    if (value.contains('mailing address') ||
        value.contains('mailing city') ||
        value.contains('mailing state') ||
        value.contains('mailing postcode') ||
        value.contains('mailing postal') ||
        value.contains('mailing country')) {
      return _ConditionGroup.mailing;
    }
    if (value.contains('dependent')) {
      return _ConditionGroup.dependents;
    }
    return null;
  }

  String _searchable(SmartFormQuestion question) =>
      '${question.fieldName} ${question.label}'
          .toLowerCase()
          .replaceAll(RegExp(r'[._\-]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
}
