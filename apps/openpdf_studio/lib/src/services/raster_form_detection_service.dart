import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/painting.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import 'flat_form_detection_service.dart';

class RasterFormDetectionResult {
  const RasterFormDetectionResult({
    required this.fields,
    required this.pagesNeedingOcr,
  });

  final List<FlatFormDetection> fields;
  final List<int> pagesNeedingOcr;
}

/// Private pixel-based control detection for scanned/image PDF pages.
///
/// Geometry comes from rendered pixels; labels come only from an existing OCR
/// text layer. A page without positioned OCR is reported instead of guessing.
class RasterFormDetectionService {
  const RasterFormDetectionService({
    this.pixelRatio = 1.5,
    this.rasterizer = const PdfRendererOcrRasterizer(),
  });

  final double pixelRatio;
  final PdfOcrRasterizer rasterizer;

  Future<RasterFormDetectionResult> detect(
    PdfDocument document, {
    required Iterable<int> pages,
  }) async {
    final fields = <FlatFormDetection>[];
    final pagesNeedingOcr = <int>[];
    for (final pageIndex in pages) {
      final pageText = PdfTextExtractor.extract(document, pageIndex);
      if (pageText.runs.where((run) => run.text.trim().isNotEmpty).isEmpty) {
        pagesNeedingOcr.add(pageIndex);
        continue;
      }
      final page = document.page(pageIndex);
      final pageImage = await rasterizer.rasterize(
        page,
        pageIndex: pageIndex,
        pixelRatio: pixelRatio,
      );
      try {
        final components = await _darkComponents(pageImage.image);
        final shapes = <_RasterShape>[];
        for (final component in components) {
          final shape = _classify(component, pageImage);
          if (shape != null && !_overlaps(shape, shapes)) shapes.add(shape);
        }
        for (final shape in shapes) {
          final label = _nearestLabel(shape.bounds, shape.kind, pageText.runs);
          if (label == null) continue;
          final confidence =
              (shape.baseConfidence + label.score + _semanticBoost(label.text))
                  .clamp(0.0, 1.0);
          if (confidence < 0.65) continue;
          fields.add(
            FlatFormDetection(
              pageIndex: pageIndex,
              label: _cleanLabel(label.text),
              kind: shape.kind,
              rect: shape.fieldRect,
              confidence: confidence,
            ),
          );
        }
      } finally {
        pageImage.dispose();
      }
      await Future<void>.delayed(Duration.zero);
    }
    return RasterFormDetectionResult(
      fields: _deduplicateLabels(fields),
      pagesNeedingOcr: pagesNeedingOcr,
    );
  }

  Future<List<_PixelComponent>> _darkComponents(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return const [];
    final rgba = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final width = image.width;
    final height = image.height;
    final dark = Uint8List(width * height);
    for (var i = 0; i < dark.length; i++) {
      final offset = i * 4;
      final r = rgba[offset];
      final g = rgba[offset + 1];
      final b = rgba[offset + 2];
      final a = rgba[offset + 3];
      final luminance = (r * 299 + g * 587 + b * 114) ~/ 1000;
      if (a > 32 && luminance < 175) dark[i] = 1;
    }

    final seen = Uint8List(dark.length);
    final components = <_PixelComponent>[];
    final queue = <int>[];
    for (var start = 0; start < dark.length; start++) {
      if (dark[start] == 0 || seen[start] != 0) continue;
      queue
        ..clear()
        ..add(start);
      seen[start] = 1;
      var head = 0;
      var minX = start % width;
      var maxX = minX;
      var minY = start ~/ width;
      var maxY = minY;
      var count = 0;
      while (head < queue.length) {
        final index = queue[head++];
        final x = index % width;
        final y = index ~/ width;
        count++;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            final next = ny * width + nx;
            if (dark[next] == 0 || seen[next] != 0) continue;
            seen[next] = 1;
            queue.add(next);
          }
        }
      }
      if (count >= 6) {
        components.add(_PixelComponent(minX, minY, maxX + 1, maxY + 1, count));
      }
    }
    return components;
  }

  _RasterShape? _classify(
    _PixelComponent component,
    PdfOcrPageImage pageImage,
  ) {
    final widthPoints = component.width / pixelRatio;
    final heightPoints = component.height / pixelRatio;
    final density = component.count / (component.width * component.height);
    final user = pageImage.userSpaceRect(
      Rect.fromLTRB(
        component.left.toDouble(),
        component.top.toDouble(),
        component.right.toDouble(),
        component.bottom.toDouble(),
      ),
    );
    if (widthPoints >= 8 &&
        widthPoints <= 30 &&
        heightPoints >= 8 &&
        heightPoints <= 30 &&
        widthPoints / heightPoints >= 0.7 &&
        widthPoints / heightPoints <= 1.4 &&
        density >= 0.08 &&
        density <= 0.72) {
      return _RasterShape(
        bounds: user,
        fieldRect: user,
        kind: FlatFormControlKind.checkBox,
        baseConfidence: 0.44,
      );
    }
    if (widthPoints >= 70 && heightPoints <= 5 && density >= 0.22) {
      return _RasterShape(
        bounds: user,
        fieldRect: PdfRect(
          user.left,
          user.bottom + 1,
          user.right,
          user.bottom + 23,
        ),
        kind: FlatFormControlKind.text,
        baseConfidence: 0.42,
      );
    }
    return null;
  }

  _RasterLabel? _nearestLabel(
    PdfRect control,
    FlatFormControlKind kind,
    List<PdfExtractedRun> runs,
  ) {
    PdfExtractedRun? bestRun;
    var bestScore = -1.0;
    final cy = (control.bottom + control.top) / 2;
    for (final run in runs) {
      final value = run.text.trim();
      if (value.length < 2 || value.length > 100) continue;
      final b = run.bounds;
      final vertical = (((b.bottom + b.top) / 2) - cy).abs();
      double? distance;
      final leftGap = control.left - b.right;
      if (leftGap >= -3 && leftGap <= 130 && vertical <= 20) {
        distance = leftGap.abs() + vertical * 2;
      }
      final rightGap = b.left - control.right;
      if (kind == FlatFormControlKind.checkBox &&
          rightGap >= -3 &&
          rightGap <= 190 &&
          vertical <= 20) {
        final candidate = rightGap.abs() + vertical * 2;
        distance = distance == null ? candidate : math.min(distance, candidate);
      }
      final aboveGap = b.bottom - control.top;
      final overlap =
          math.min(b.right, control.right) - math.max(b.left, control.left);
      if (aboveGap >= -3 && aboveGap <= 45 && overlap >= -14) {
        final candidate = aboveGap.abs() + (b.left - control.left).abs() * 0.15;
        distance = distance == null ? candidate : math.min(distance, candidate);
      }
      if (distance == null) continue;
      final score = (0.35 - distance / 520).clamp(0.17, 0.35);
      if (score > bestScore) {
        bestScore = score;
        bestRun = run;
      }
    }
    if (bestRun == null) return null;
    return _RasterLabel(_expandLineLabel(bestRun, runs), bestScore);
  }

  String _expandLineLabel(PdfExtractedRun seed, List<PdfExtractedRun> runs) {
    final seedY = (seed.bounds.bottom + seed.bounds.top) / 2;
    final line = [
      for (final run in runs)
        if (run.text.trim().isNotEmpty &&
            (((run.bounds.bottom + run.bounds.top) / 2) - seedY).abs() <= 5)
          run,
    ]..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    final seedIndex = line.indexOf(seed);
    if (seedIndex < 0) return seed.text.trim();
    var first = seedIndex;
    var last = seedIndex;
    while (first > 0 &&
        line[first].bounds.left - line[first - 1].bounds.right <= 20) {
      first--;
    }
    while (last + 1 < line.length &&
        line[last + 1].bounds.left - line[last].bounds.right <= 20) {
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
    ];
    return hints.any(value.contains) ? 0.12 : 0.04;
  }

  String _cleanLabel(String value) => value
      .replaceAll(RegExp(r'[:*\s]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _overlaps(_RasterShape next, List<_RasterShape> current) {
    for (final shape in current) {
      final width = math.max(
        0.0,
        math.min(next.bounds.right, shape.bounds.right) -
            math.max(next.bounds.left, shape.bounds.left),
      );
      final height = math.max(
        0.0,
        math.min(next.bounds.top, shape.bounds.top) -
            math.max(next.bounds.bottom, shape.bounds.bottom),
      );
      final overlap = width * height;
      final smaller = math.min(_area(next.bounds), _area(shape.bounds));
      if (smaller > 0 && overlap / smaller > 0.8) return true;
    }
    return false;
  }

  double _area(PdfRect rect) => rect.width.abs() * rect.height.abs();

  List<FlatFormDetection> _deduplicateLabels(List<FlatFormDetection> fields) {
    final counts = <String, int>{};
    return [
      for (final field in fields)
        FlatFormDetection(
          pageIndex: field.pageIndex,
          label: () {
            final count = (counts[field.label] ?? 0) + 1;
            counts[field.label] = count;
            return count == 1 ? field.label : '${field.label} $count';
          }(),
          kind: field.kind,
          rect: field.rect,
          confidence: field.confidence,
        ),
    ];
  }
}

class _PixelComponent {
  const _PixelComponent(
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.count,
  );

  final int left;
  final int top;
  final int right;
  final int bottom;
  final int count;

  int get width => right - left;
  int get height => bottom - top;
}

class _RasterShape {
  const _RasterShape({
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

class _RasterLabel {
  const _RasterLabel(this.text, this.score);

  final String text;
  final double score;
}
