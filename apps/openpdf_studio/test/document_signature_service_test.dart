import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/document_signature_service.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  test('reports an unsigned document', () {
    expect(inspectPdfSignatures(_onePagePdf()), isEmpty);
  });

  test('validates a self-signed document and distinguishes trust', () {
    final identity = PdfSigningIdentity.generate(name: 'QPdf Test Signer');
    final signed = PdfEditor(PdfDocument.open(_onePagePdf())).saveSignedEcdsa(
      privateKey: identity.privateKey,
      certificates: identity.certificates,
      signerName: identity.name,
      reason: 'Automated verification',
    );

    final report = inspectPdfSignatures(signed).single;
    expect(report.signer, 'QPdf Test Signer');
    expect(report.intact, isTrue);
    expect(report.coversWholeDocument, isTrue);
    expect(report.trustStatus, 'Trust not evaluated');
    expect(report.problems, isEmpty);
  });
}

Uint8List _onePagePdf() => Uint8List.fromList(
  latin1.encode(
    '%PDF-1.4\n'
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n'
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n'
    'xref\n0 4\n'
    '0000000000 65535 f \n'
    '0000000009 00000 n \n'
    '0000000058 00000 n \n'
    '0000000115 00000 n \n'
    'trailer\n<< /Size 4 /Root 1 0 R >>\n'
    'startxref\n186\n%%EOF\n',
  ),
);
