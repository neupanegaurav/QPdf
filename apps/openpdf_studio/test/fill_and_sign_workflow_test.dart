import 'dart:ui';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('created form fields can be filled and survive save/reopen', () async {
    final controller = PdfEditingController(PdfBlankDocument.create());
    addTearDown(controller.dispose);
    await controller.preferences.ready;

    final name = controller.addFormField(
      PdfFormFieldKind.text,
      0,
      const PdfRect(72, 680, 320, 716),
    );
    final consent = controller.addFormField(
      PdfFormFieldKind.checkBox,
      0,
      const PdfRect(72, 620, 96, 644),
    );

    expect(name, 'Field 1');
    expect(consent, 'Field 2');
    expect(controller.setFormFieldText(name!, 'Taylor Example'), isTrue);
    expect(controller.toggleFormCheckBox(consent!), isTrue);

    final reopened = PdfDocument.open(controller.bytes);
    final form = PdfAcroForm.of(reopened);
    expect(form, isNotNull);
    expect(form!.fieldNamed(name)!.value, 'Taylor Example');
    expect(form.fieldNamed(consent)!.isChecked, isTrue);
    expect(form.needsAppearances, isFalse);
  });

  test(
    'handwritten signature remains a visible ink annotation after reopen',
    () async {
      final controller = PdfEditingController(PdfBlankDocument.create());
      addTearDown(controller.dispose);
      await controller.preferences.ready;

      controller.preferences.signature = PdfInkSignature.fromPad(
        const [
          [Offset(10, 38), Offset(40, 12), Offset(82, 34), Offset(126, 8)],
        ],
        const [null],
        const Color(0xFF0A56D9),
      );

      expect(controller.placeSignature(0, 300, 180), isTrue);
      final reopened = PdfDocument.open(controller.bytes);
      final ink = reopened
          .page(0)
          .annotations
          .where((annotation) => annotation.subtype == 'Ink');

      expect(ink, hasLength(1));
      expect(ink.single.rect.width, greaterThan(100));
      expect(ink.single.rect.height, greaterThan(0));
    },
  );
}
