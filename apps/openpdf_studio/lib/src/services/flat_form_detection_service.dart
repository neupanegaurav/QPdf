import 'dart:math' as math;

import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

enum FlatFormControlKind { text, checkBox }

/// One locally detected, non-interactive control on a native PDF page.
class FlatFormDetection {
  const FlatFormDetection({
    required this.pageIndex,
    required this.label,
    required this.kind,
    required this.rect,
    required this.confidence,
  });

  final int pageIndex;
  final String label;
  final FlatFormControlKind kind;
  final PdfRect rect;
  final double confidence;
}

class FlatFormDetectionResult {
  const FlatFormDetectionResult({
    required this.fields,
    required this.imageOnlyPages,
  });

  final List<FlatFormDetection> fields;

  /// Pages containing an image but no usable vector controls. These are
  /// candidates for raster control detection, with OCR providing the labels.
  final List<int> imageOnlyPages;
}

/// Detects common native flat-form controls from PDF vector geometry and
/// nearby positioned text. It never mutates the document and intentionally
/// rejects low-confidence/unlabelled shapes.
class FlatFormDetectionService {
  const FlatFormDetectionService();

  FlatFormDetectionResult detect(PdfDocument document) {
    final detections = <FlatFormDetection>[];
    final imageOnlyPages = <int>[];
    for (var pageIndex = 0; pageIndex < document.pageCount; pageIndex++) {
      final elements = PdfPageElements.of(document, pageIndex).elements;
      final text = PdfTextExtractor.extract(document, pageIndex);
      final controls = <_ControlShape>[];
      var hasPageImage = false;
      for (final element in elements) {
        if (element.kind == PdfElementKind.image ||
            element.kind == PdfElementKind.inlineImage) {
          hasPageImage = true;
        }
        if (element.kind != PdfElementKind.path || element.bounds == null) {
          continue;
        }
        final shape = _classifyShape(element.bounds!);
        if (shape != null && !_overlapsExisting(shape, controls)) {
          controls.add(shape);
        }
      }

      for (final control in controls) {
        final label = _nearestLabel(control.bounds, control.kind, text.runs);
        if (label == null) continue;
        final semantic = _semanticBoost(label.text);
        final confidence = (control.baseConfidence + label.score + semantic)
            .clamp(0.0, 1.0);
        if (confidence < 0.65) continue;
        detections.add(
          FlatFormDetection(
            pageIndex: pageIndex,
            label: _cleanLabel(label.text),
            kind: control.kind,
            rect: control.fieldRect,
            confidence: confidence,
          ),
        );
      }
      if (controls.isEmpty && hasPageImage) {
        imageOnlyPages.add(pageIndex);
      }
    }
    return FlatFormDetectionResult(
      fields: _deduplicateLabels(detections),
      imageOnlyPages: imageOnlyPages,
    );
  }

  _ControlShape? _classifyShape(PdfRect bounds) {
    final width = bounds.width.abs();
    final height = bounds.height.abs();
    if (width >= 8 &&
        width <= 28 &&
        height >= 8 &&
        height <= 28 &&
        width / height >= 0.72 &&
        width / height <= 1.38) {
      return _ControlShape(
        bounds: bounds,
        fieldRect: bounds,
        kind: FlatFormControlKind.checkBox,
        baseConfidence: 0.48,
      );
    }
    if (width >= 70 && height <= 3) {
      return _ControlShape(
        bounds: bounds,
        fieldRect: PdfRect(
          bounds.left,
          bounds.bottom + 1,
          bounds.right,
          bounds.bottom + 23,
        ),
        kind: FlatFormControlKind.text,
        baseConfidence: 0.45,
      );
    }
    if (width >= 70 && width <= 460 && height >= 14 && height <= 56) {
      return _ControlShape(
        bounds: bounds,
        fieldRect: PdfRect(
          bounds.left + 2,
          bounds.bottom + 2,
          bounds.right - 2,
          bounds.top - 2,
        ),
        kind: FlatFormControlKind.text,
        baseConfidence: 0.5,
      );
    }
    return null;
  }

  _LabelMatch? _nearestLabel(
    PdfRect control,
    FlatFormControlKind kind,
    List<PdfExtractedRun> runs,
  ) {
    _LabelMatch? best;
    PdfExtractedRun? bestRun;
    final cy = (control.bottom + control.top) / 2;
    for (final run in runs) {
      final value = run.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value.length < 2 || value.length > 100) continue;
      final b = run.bounds;
      final ry = (b.bottom + b.top) / 2;
      final vertical = (ry - cy).abs();
      double? distance;

      // Labels commonly sit immediately left of an underline/text box.
      final leftGap = control.left - b.right;
      if (leftGap >= -2 && leftGap <= 120 && vertical <= 18) {
        distance = leftGap.abs() + vertical * 2;
      }

      // Check-box captions usually sit on the right.
      final rightGap = b.left - control.right;
      if (kind == FlatFormControlKind.checkBox &&
          rightGap >= -2 &&
          rightGap <= 180 &&
          vertical <= 18) {
        final candidate = rightGap.abs() + vertical * 2;
        distance = distance == null ? candidate : math.min(distance, candidate);
      }

      // Captions above boxed/underlined controls are also common.
      final aboveGap = b.bottom - control.top;
      final horizontalOverlap =
          math.min(b.right, control.right) - math.max(b.left, control.left);
      if (aboveGap >= -2 && aboveGap <= 42 && horizontalOverlap >= -12) {
        final candidate = aboveGap.abs() + (b.left - control.left).abs() * 0.15;
        distance = distance == null ? candidate : math.min(distance, candidate);
      }

      if (distance == null) continue;
      final proximity = (0.36 - distance / 500).clamp(0.18, 0.36);
      if (best == null || proximity > best.score) {
        best = _LabelMatch(value, proximity);
        bestRun = run;
      }
    }
    if (best == null || bestRun == null) return null;
    return _LabelMatch(_expandLineLabel(bestRun, runs), best.score);
  }

  String _expandLineLabel(PdfExtractedRun seed, List<PdfExtractedRun> runs) {
    final seedY = (seed.bounds.bottom + seed.bounds.top) / 2;
    final line = [
      for (final run in runs)
        if (run.text.trim().isNotEmpty &&
            (((run.bounds.bottom + run.bounds.top) / 2) - seedY).abs() <= 4)
          run,
    ]..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    final seedIndex = line.indexOf(seed);
    if (seedIndex < 0) return seed.text.trim();
    var first = seedIndex;
    var last = seedIndex;
    while (first > 0 &&
        line[first].bounds.left - line[first - 1].bounds.right <= 18) {
      first--;
    }
    while (last + 1 < line.length &&
        line[last + 1].bounds.left - line[last].bounds.right <= 18) {
      last++;
    }
    return line
        .sublist(first, last + 1)
        .map((run) => run.text.trim())
        .where((text) => text.isNotEmpty)
        .join(' ');
  }

  double _semanticBoost(String label) {
    final value = label.toLowerCase();
    const hints = [
      'name',
      'address',
      'email',
      'phone',
      'date',
      'city',
      'state',
      'country',
      'postcode',
      'postal',
      'agree',
      'consent',
      'yes',
      'no',
    ];
    return hints.any(value.contains) ? 0.1 : 0.03;
  }

  String _cleanLabel(String label) {
    final cleaned = label
        .replaceAll(RegExp(r'[:*\s]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'Detected field' : cleaned;
  }

  bool _overlapsExisting(_ControlShape next, List<_ControlShape> existing) {
    for (final current in existing) {
      final overlap = _intersectionArea(next.bounds, current.bounds);
      final smaller = math.min(_area(next.bounds), _area(current.bounds));
      if (smaller > 0 && overlap / smaller > 0.8) return true;
    }
    return false;
  }

  List<FlatFormDetection> _deduplicateLabels(
    List<FlatFormDetection> detections,
  ) {
    final counts = <String, int>{};
    return [
      for (final detection in detections)
        FlatFormDetection(
          pageIndex: detection.pageIndex,
          label: () {
            final count = (counts[detection.label] ?? 0) + 1;
            counts[detection.label] = count;
            return count == 1 ? detection.label : '${detection.label} $count';
          }(),
          kind: detection.kind,
          rect: detection.rect,
          confidence: detection.confidence,
        ),
    ];
  }

  double _area(PdfRect rect) => rect.width.abs() * rect.height.abs();

  double _intersectionArea(PdfRect a, PdfRect b) {
    final width = math.max(
      0.0,
      math.min(a.right, b.right) - math.max(a.left, b.left),
    );
    final height = math.max(
      0.0,
      math.min(a.top, b.top) - math.max(a.bottom, b.bottom),
    );
    return width * height;
  }
}

class _ControlShape {
  const _ControlShape({
    required this.bounds,
    required this.fieldRect,
    required this.kind,
    required this.baseConfidence,
  });

  final PdfRect bounds;
  final PdfRect fieldRect;
  final FlatFormControlKind kind;
  final double baseConfidence;
}

class _LabelMatch {
  const _LabelMatch(this.text, this.score);

  final String text;
  final double score;
}
