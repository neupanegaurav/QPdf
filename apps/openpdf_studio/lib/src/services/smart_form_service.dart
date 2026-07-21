import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';

/// Input presentation inferred locally from PDF form metadata.
enum SmartFormInputKind {
  text,
  multiline,
  email,
  phone,
  date,
  number,
  checkBox,
  choice,
}

enum SmartFormSemanticSource {
  deterministic,
  appleFoundationModel,
  portableModel,
}

enum SmartFormLabelSource {
  producerMetadata,
  fieldName,
  coordinateSuggestion,
  genericFallback,
}

enum SmartFormCompatibilityLevel { full, partial, unsupported }

class SmartFormCompatibility {
  const SmartFormCompatibility({
    required this.level,
    required this.hasXfa,
    required this.fillableFields,
    required this.genericLabels,
  });

  final SmartFormCompatibilityLevel level;
  final bool hasXfa;
  final int fillableFields;
  final int genericLabels;

  bool get needsReview => level != SmartFormCompatibilityLevel.full;
}

/// A user-facing question mapped back to one concrete AcroForm field.
class SmartFormQuestion {
  const SmartFormQuestion({
    required this.fieldName,
    required this.label,
    required this.kind,
    required this.required,
    required this.currentValue,
    this.options = const [],
    this.section = 'Form details',
    this.semanticSource = SmartFormSemanticSource.deterministic,
    this.labelSource = SmartFormLabelSource.fieldName,
    this.labelConfidence,
  });

  final String fieldName;
  final String label;
  final SmartFormInputKind kind;
  final bool required;
  final String currentValue;
  final List<(String, String)> options;
  final String section;
  final SmartFormSemanticSource semanticSource;
  final SmartFormLabelSource labelSource;
  final double? labelConfidence;

  bool get labelNeedsReview =>
      labelSource == SmartFormLabelSource.coordinateSuggestion ||
      labelSource == SmartFormLabelSource.genericFallback;

  SmartFormQuestion copyWith({
    String? label,
    SmartFormInputKind? kind,
    String? section,
    SmartFormSemanticSource? semanticSource,
    SmartFormLabelSource? labelSource,
    double? labelConfidence,
  }) => SmartFormQuestion(
    fieldName: fieldName,
    label: label ?? this.label,
    kind: kind ?? this.kind,
    required: required,
    currentValue: currentValue,
    options: options,
    section: section ?? this.section,
    semanticSource: semanticSource ?? this.semanticSource,
    labelSource: labelSource ?? this.labelSource,
    labelConfidence: labelConfidence ?? this.labelConfidence,
  );
}

/// Builds a private Smart Fill questionnaire without sending document data
/// anywhere. AcroForm metadata is authoritative; inference is used only to
/// turn poor producer names such as `applicant_email_1` into useful prompts.
class SmartFormAnalyzer {
  const SmartFormAnalyzer();

  List<SmartFormQuestion> analyze(PdfAcroForm? form) {
    if (form == null) return const [];
    return [
      for (final field in form.fields)
        if (_isFillable(field)) _question(field),
    ];
  }

  SmartFormCompatibility compatibility(PdfAcroForm? form) {
    if (form == null) {
      return const SmartFormCompatibility(
        level: SmartFormCompatibilityLevel.unsupported,
        hasXfa: false,
        fillableFields: 0,
        genericLabels: 0,
      );
    }
    final questions = analyze(form);
    final hasXfa = form.dict.containsKey('XFA');
    final genericLabels = questions
        .where(
          (question) =>
              question.labelSource == SmartFormLabelSource.genericFallback,
        )
        .length;
    return SmartFormCompatibility(
      level: questions.isEmpty
          ? SmartFormCompatibilityLevel.unsupported
          : hasXfa || genericLabels > 0
          ? SmartFormCompatibilityLevel.partial
          : SmartFormCompatibilityLevel.full,
      hasXfa: hasXfa,
      fillableFields: questions.length,
      genericLabels: genericLabels,
    );
  }

  bool _isFillable(PdfFormField field) =>
      !field.isReadOnly &&
      const {
        PdfFieldType.text,
        PdfFieldType.checkBox,
        PdfFieldType.radioGroup,
        PdfFieldType.comboBox,
        PdfFieldType.listBox,
      }.contains(field.type);

  SmartFormQuestion _question(PdfFormField field) {
    final labelDetails = _bestLabel(field);
    final label = labelDetails.$1;
    final searchable = '${field.name} $label'.toLowerCase();
    return SmartFormQuestion(
      fieldName: field.name,
      label: label,
      kind: _kind(field, searchable),
      required: field.isRequired,
      currentValue: switch (field.value) {
        null || '' || 'Off' => '',
        final value => value,
      },
      section: _section(searchable),
      options: switch (field.type) {
        PdfFieldType.radioGroup => [
          for (final value in field.onStates) (value, _humanize(value)),
        ],
        PdfFieldType.comboBox || PdfFieldType.listBox => field.options,
        _ => const [],
      },
      labelSource: labelDetails.$2,
    );
  }

  String _section(String searchable) {
    if (_containsAny(searchable, const [
      'agree',
      'consent',
      'confirm',
      'declaration',
      'terms',
    ])) {
      return 'Declarations';
    }
    if (_containsAny(searchable, const [
      'employer',
      'employment',
      'occupation',
      'income',
      'salary',
      'job title',
      'work phone',
    ])) {
      return 'Employment and income';
    }
    if (_containsAny(searchable, const [
      'email',
      'e-mail',
      'phone',
      'mobile',
      'telephone',
      ' tel',
    ])) {
      return 'Contact details';
    }
    if (_containsAny(searchable, const [
      'address',
      'city',
      'state',
      'province',
      'postal',
      'postcode',
      'country',
    ])) {
      return 'Address';
    }
    return 'Personal details';
  }

  (String, SmartFormLabelSource) _bestLabel(PdfFormField field) {
    for (final key in const ['TU', 'TM']) {
      final value = field.inherited(key);
      if (value is CosString && value.text.trim().isNotEmpty) {
        return (_humanize(value.text), SmartFormLabelSource.producerMetadata);
      }
    }
    final terminal = field.name
        .split('.')
        .last
        .replaceAll(RegExp(r'\[\d+\]'), '')
        .trim();
    final generic = RegExp(
      r'^[a-z]{1,3}\d*[_\-]?\d+$',
      caseSensitive: false,
    ).hasMatch(terminal);
    return generic
        ? (
            'Form field ${terminal.replaceAll(RegExp(r'[_\-]+'), ' ').toLowerCase()}',
            SmartFormLabelSource.genericFallback,
          )
        : (_humanize(terminal), SmartFormLabelSource.fieldName);
  }

  SmartFormInputKind _kind(PdfFormField field, String searchable) {
    if (field.type == PdfFieldType.checkBox) {
      return SmartFormInputKind.checkBox;
    }
    if (field.type == PdfFieldType.radioGroup ||
        field.type == PdfFieldType.comboBox ||
        field.type == PdfFieldType.listBox) {
      return SmartFormInputKind.choice;
    }
    if (field.isMultiline) return SmartFormInputKind.multiline;
    if (_containsAny(searchable, const ['email', 'e-mail'])) {
      return SmartFormInputKind.email;
    }
    if (_containsAny(searchable, const [
      'phone',
      'mobile',
      'telephone',
      'tel',
    ])) {
      return SmartFormInputKind.phone;
    }
    if (_containsAny(searchable, const ['date', 'dob', 'birth'])) {
      return SmartFormInputKind.date;
    }
    if (_containsAny(searchable, const [
      'amount',
      'number',
      'quantity',
      'income',
      'salary',
    ])) {
      return SmartFormInputKind.number;
    }
    return SmartFormInputKind.text;
  }

  bool _containsAny(String value, List<String> candidates) =>
      candidates.any(value.contains);

  String _humanize(String source) {
    var value = source
        .replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1 $2')
        .replaceAll(RegExp(r'[._\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    value = value.replaceAll(RegExp(r'\s+\d+$'), '');
    if (value.isEmpty) return 'Unnamed field';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
