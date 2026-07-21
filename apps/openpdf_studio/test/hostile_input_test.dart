import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/engine/dart_pdf_engine.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_domain/pdf_domain.dart';
import 'package:pdf_engine_api/pdf_engine_api.dart';

/// Treat-every-PDF-as-hostile gate.
///
/// `open` must satisfy one contract on any input: either return a document or
/// throw a [PdfOpenException]. It must never surface a raw parser error
/// (`RangeError`, `StateError`, `FormatException`, …) that would crash the app,
/// and it must never hang. Each mutation set is deterministic so a failure is
/// always reproducible from the printed seed.
void main() {
  final engine = DartPdfEngine();
  final base = PdfBlankDocument.create(pageCount: 4);

  Future<void> expectHandled(Uint8List bytes, String label) async {
    try {
      await engine
          .open(
            PdfDocumentSource(id: label, displayName: label, bytes: bytes),
          )
          .timeout(const Duration(seconds: 5));
      // A clean open is acceptable: the mutation happened to stay valid.
    } on PdfOpenException {
      // The declared, handled failure mode. Acceptable.
    } on Object catch (error, stack) {
      fail(
        'open() leaked ${error.runtimeType} on "$label" instead of a '
        'PdfOpenException (or a TimeoutException = hang):\n$error\n$stack',
      );
    }
  }

  test('degenerate inputs never crash open()', () async {
    await expectHandled(Uint8List(0), 'empty');
    await expectHandled(Uint8List.fromList([0x25, 0x50]), 'two-bytes');
    await expectHandled(
      Uint8List.fromList('%PDF-1.7\nnot really a pdf'.codeUnits),
      'header-then-garbage',
    );
    await expectHandled(
      Uint8List.fromList(List<int>.filled(4096, 0)),
      'all-zeroes',
    );
  });

  test('single-byte flips of a valid PDF never crash open()', () async {
    final random = Random(0xB16B00B5);
    for (var i = 0; i < 200; i++) {
      final mutated = Uint8List.fromList(base);
      final index = random.nextInt(mutated.length);
      mutated[index] = mutated[index] ^ (1 << random.nextInt(8));
      await expectHandled(mutated, 'flip#$i@$index');
    }
  });

  test('truncations of a valid PDF never crash open()', () async {
    final random = Random(0x5EED);
    for (var i = 0; i < 100; i++) {
      final length = random.nextInt(base.length);
      await expectHandled(
        Uint8List.sublistView(base, 0, length),
        'truncate#$i@$length',
      );
    }
  });

  test('random garbage never crashes open()', () async {
    final random = Random(0xDEADBEEF);
    for (var i = 0; i < 100; i++) {
      final length = random.nextInt(8192);
      final garbage = Uint8List(length);
      for (var b = 0; b < length; b++) {
        garbage[b] = random.nextInt(256);
      }
      await expectHandled(garbage, 'garbage#$i@$length');
    }
  });
}
