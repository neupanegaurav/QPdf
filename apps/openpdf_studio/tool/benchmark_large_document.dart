import 'dart:convert';
import 'dart:io';

import 'package:openpdf_studio/src/engine/dart_pdf_engine.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';

Future<void> main(List<String> arguments) async {
  final pageCount = arguments.isEmpty ? 1000 : int.parse(arguments.first);
  final initialRss = ProcessInfo.currentRss;

  final generateWatch = Stopwatch()..start();
  final bytes = PdfBlankDocument.create(pageCount: pageCount);
  generateWatch.stop();

  final source = PdfDocumentSource(
    id: 'benchmark-$pageCount',
    displayName: 'benchmark-$pageCount.pdf',
    bytes: bytes,
  );
  final openWatch = Stopwatch()..start();
  final opened = await DartPdfEngine().open(source);
  openWatch.stop();

  final document = PdfDocument.open(bytes);
  final traverseWatch = Stopwatch()..start();
  var totalArea = 0.0;
  for (var index = 0; index < document.pageCount; index++) {
    final box = document.page(index).cropBox;
    totalArea += box.width * box.height;
  }
  traverseWatch.stop();

  final saveWatch = Stopwatch()..start();
  final editor = PdfEditor(document)
    ..setInfo(producer: 'QPdf performance benchmark');
  final saved = editor.save();
  final reopened = PdfDocument.open(saved);
  saveWatch.stop();

  if (opened.summary.pageCount != pageCount ||
      reopened.pageCount != pageCount) {
    throw StateError('Page count changed during the benchmark.');
  }

  final rssDelta = ProcessInfo.currentRss - initialRss;
  final report = <String, Object>{
    'pages': pageCount,
    'source_bytes': bytes.length,
    'saved_bytes': saved.length,
    'generate_ms': generateWatch.elapsedMilliseconds,
    'open_ms': openWatch.elapsedMilliseconds,
    'traverse_ms': traverseWatch.elapsedMilliseconds,
    'save_reopen_ms': saveWatch.elapsedMilliseconds,
    'rss_delta_mb': (rssDelta / (1024 * 1024)).toStringAsFixed(1),
    'page_area_checksum': totalArea.toStringAsFixed(0),
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));

  const timeBudget = Duration(seconds: 5);
  const memoryBudgetBytes = 512 * 1024 * 1024;
  final stages = {
    'generate': generateWatch.elapsed,
    'open': openWatch.elapsed,
    'traverse': traverseWatch.elapsed,
    'save/reopen': saveWatch.elapsed,
  };
  for (final entry in stages.entries) {
    if (entry.value > timeBudget) {
      stderr.writeln(
        '${entry.key} exceeded the ${timeBudget.inSeconds}s budget.',
      );
      exitCode = 1;
    }
  }
  if (rssDelta > memoryBudgetBytes) {
    stderr.writeln('RSS growth exceeded the 512 MB desktop budget.');
    exitCode = 1;
  }
}
