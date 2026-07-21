import 'dart:convert';
import 'dart:io';

import 'package:pdf_domain/pdf_domain.dart';
import 'package:pdf_engine_pdfium/pdf_engine_pdfium.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/verify_pdfium_corpus.dart <corpus-directory>',
    );
    exitCode = 64;
    return;
  }
  final corpus = Directory(arguments.first).absolute;
  final manifest =
      jsonDecode(await File('${corpus.path}/manifest.json').readAsString())
          as Map<String, Object?>;
  final engine = PdfiumEngine();
  var passed = 0;

  for (final rawCase in manifest['cases']! as List<Object?>) {
    final fixture = rawCase! as Map<String, Object?>;
    final filename = fixture['file']! as String;
    final source = PdfDocumentSource(
      id: fixture['id']! as String,
      displayName: filename,
      bytes: await File('${corpus.path}/$filename').readAsBytes(),
    );
    final opened = await engine.open(
      source,
      password: fixture['password'] as String? ?? '',
    );
    final expected = fixture['page_count']! as int;
    if (opened.summary.pageCount != expected) {
      throw StateError(
        '$filename: expected $expected pages, got ${opened.summary.pageCount}',
      );
    }
    passed++;
  }
  stdout.writeln('PDFium verified $passed corpus documents.');
}
