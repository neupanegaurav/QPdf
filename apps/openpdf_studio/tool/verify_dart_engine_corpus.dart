import 'dart:convert';
import 'dart:io';

import 'package:openpdf_studio/src/engine/dart_pdf_engine.dart';
import 'package:openpdf_studio/src/services/document_security_service.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/verify_dart_engine_corpus.dart <corpus-directory>',
    );
    exitCode = 64;
    return;
  }

  final corpus = Directory(arguments.first).absolute;
  final manifestFile = File('${corpus.path}/manifest.json');
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
  final cases = manifest['cases']! as List<Object?>;
  final engine = DartPdfEngine();
  var openedCount = 0;
  var savedCount = 0;

  for (final rawCase in cases) {
    final fixture = rawCase! as Map<String, Object?>;
    final filename = fixture['file']! as String;
    final password = fixture['password'] as String? ?? '';
    final expectedPages = fixture['page_count']! as int;
    final bytes = await File('${corpus.path}/$filename').readAsBytes();
    final source = PdfDocumentSource(
      id: fixture['id']! as String,
      displayName: filename,
      bytes: bytes,
    );

    final opened = await engine.open(source, password: password);
    if (opened.summary.pageCount != expectedPages) {
      throw StateError(
        '$filename: expected $expectedPages pages, '
        'got ${opened.summary.pageCount}',
      );
    }
    openedCount++;

    final security = inspectPdfSecurity(bytes, password: password);
    if (security.isEncrypted != password.isNotEmpty) {
      throw StateError(
        '$filename: encryption report did not match the fixture manifest',
      );
    }

    final document = PdfDocument.open(bytes, password: password);
    final editor = PdfEditor(document);
    editor.setInfo(producer: 'QPdf corpus round trip');
    final savedBytes = editor.save();
    final reopened = PdfDocument.open(savedBytes, password: password);
    if (reopened.pageCount != expectedPages) {
      throw StateError('$filename: page count changed after save/reopen');
    }
    savedCount++;
  }

  stdout.writeln(
    'Dart engine verified $openedCount opens and $savedCount save/reopen cycles.',
  );
}
