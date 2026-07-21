import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/services/document_security_service.dart';
import 'package:openpdf_studio/src/services/pdf_protection_service.dart';

void main() {
  test('reports an unencrypted document with unrestricted permissions', () {
    final report = inspectPdfSecurity(_onePagePdf());

    expect(report.isEncrypted, isFalse);
    expect(report.algorithm, 'None');
    expect(report.permissions.values, everyElement(isTrue));
  });

  test('decodes standard security permission bits', () {
    final flags = (1 << 2) | (1 << 4) | (1 << 8) | (1 << 9);
    final permissions = decodePdfPermissions(flags);

    expect(permissions[PdfDocumentPermission.print], isTrue);
    expect(permissions[PdfDocumentPermission.modify], isFalse);
    expect(permissions[PdfDocumentPermission.copy], isTrue);
    expect(permissions[PdfDocumentPermission.annotate], isFalse);
    expect(permissions[PdfDocumentPermission.fillForms], isTrue);
    expect(permissions[PdfDocumentPermission.accessibility], isTrue);
    expect(permissions[PdfDocumentPermission.assemble], isFalse);
    expect(permissions[PdfDocumentPermission.highQualityPrint], isFalse);
  });

  test('adds AES-256 protection with permissions and removes it', () async {
    final protected = await protectPdf(
      _onePagePdf(),
      options: const PdfProtectionOptions(
        userPassword: 'reader-secret',
        ownerPassword: 'owner-secret',
        allowModification: false,
        allowCopying: false,
        allowPageAssembly: false,
      ),
    );

    final secured = inspectPdfSecurity(protected, password: 'reader-secret');
    expect(secured.isEncrypted, isTrue);
    expect(secured.algorithm, startsWith('AES-256'));
    expect(secured.permissions[PdfDocumentPermission.print], isTrue);
    expect(secured.permissions[PdfDocumentPermission.modify], isFalse);
    expect(secured.permissions[PdfDocumentPermission.copy], isFalse);
    expect(secured.permissions[PdfDocumentPermission.assemble], isFalse);

    final unprotected = await unprotectPdf(
      protected,
      currentPassword: 'reader-secret',
    );
    expect(inspectPdfSecurity(unprotected).isEncrypted, isFalse);
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
