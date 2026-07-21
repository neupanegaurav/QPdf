import 'dart:io';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'image-heavy pages render within the desktop smoke budget',
    () async {
      final fixture = File('../../test_corpus/generated/image-heavy.pdf');
      expect(
        fixture.existsSync(),
        isTrue,
        reason: 'Run tool/generate_image_heavy_fixture.py first.',
      );

      final document = PdfDocument.open(await fixture.readAsBytes());
      expect(document.pageCount, greaterThanOrEqualTo(6));

      final initialRss = ProcessInfo.currentRss;
      final durations = <Duration>[];
      for (final pageIndex in <int>[0, 1, 2, 5]) {
        final watch = Stopwatch()..start();
        final image = await PdfPageRenderer.renderImage(
          document.page(pageIndex),
          pixelRatio: 1,
        );
        watch.stop();
        expect(image.width, greaterThan(500));
        expect(image.height, greaterThan(700));
        image.dispose();
        durations.add(watch.elapsed);
      }

      final peakRender = durations.reduce(
        (left, right) => left > right ? left : right,
      );
      final rssDelta = ProcessInfo.currentRss - initialRss;
      // Broad CI smoke limits; release-profile device timings are stricter.
      expect(peakRender, lessThan(const Duration(seconds: 10)));
      expect(rssDelta, lessThan(768 * 1024 * 1024));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
