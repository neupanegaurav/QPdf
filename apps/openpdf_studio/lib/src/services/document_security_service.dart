import 'dart:typed_data';

import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';

/// The standard security permissions encoded by ISO 32000's `/P` bit field.
enum PdfDocumentPermission {
  print('Print'),
  modify('Modify content'),
  copy('Copy text and graphics'),
  annotate('Comment and annotate'),
  fillForms('Fill form fields'),
  accessibility('Extract for accessibility'),
  assemble('Assemble pages'),
  highQualityPrint('High-quality print');

  const PdfDocumentPermission(this.label);

  final String label;
}

final class PdfSecurityReport {
  const PdfSecurityReport({
    required this.isEncrypted,
    required this.algorithm,
    required this.permissions,
    required this.rawPermissionFlags,
  });

  final bool isEncrypted;
  final String algorithm;
  final Map<PdfDocumentPermission, bool> permissions;
  final int? rawPermissionFlags;
}

PdfSecurityReport inspectPdfSecurity(Uint8List bytes, {String password = ''}) {
  final document = PdfDocument.open(bytes, password: password);
  final handler = document.cos.encryption;
  if (handler == null) {
    return PdfSecurityReport(
      isEncrypted: false,
      algorithm: 'None',
      permissions: {
        for (final permission in PdfDocumentPermission.values) permission: true,
      },
      rawPermissionFlags: null,
    );
  }

  final encrypt = document.cos.resolve(document.cos.trailer['Encrypt']);
  final flagsObject = encrypt is CosDictionary
      ? document.cos.resolve(encrypt['P'])
      : null;
  final flags = flagsObject is CosInteger ? flagsObject.value : -1;
  final revisionObject = encrypt is CosDictionary
      ? document.cos.resolve(encrypt['R'])
      : null;
  final revision = revisionObject is CosInteger
      ? revisionObject.value
      : handler.revision;

  return PdfSecurityReport(
    isEncrypted: true,
    algorithm: _algorithmLabel(handler, revision),
    permissions: decodePdfPermissions(flags),
    rawPermissionFlags: flags,
  );
}

Map<PdfDocumentPermission, bool> decodePdfPermissions(int flags) => {
  PdfDocumentPermission.print: _isAllowed(flags, 3),
  PdfDocumentPermission.modify: _isAllowed(flags, 4),
  PdfDocumentPermission.copy: _isAllowed(flags, 5),
  PdfDocumentPermission.annotate: _isAllowed(flags, 6),
  PdfDocumentPermission.fillForms: _isAllowed(flags, 9),
  PdfDocumentPermission.accessibility: _isAllowed(flags, 10),
  PdfDocumentPermission.assemble: _isAllowed(flags, 11),
  PdfDocumentPermission.highQualityPrint: _isAllowed(flags, 12),
};

bool _isAllowed(int flags, int bitNumber) =>
    (flags & (1 << (bitNumber - 1))) != 0;

String _algorithmLabel(StandardSecurityHandler handler, int revision) {
  final ciphers = {handler.stringCipher, handler.streamCipher}
    ..remove(PdfCipher.none);
  final cipher = ciphers.contains(PdfCipher.aes256)
      ? 'AES-256'
      : ciphers.contains(PdfCipher.aes128)
      ? 'AES-128'
      : ciphers.contains(PdfCipher.rc4)
      ? 'RC4'
      : 'Identity';
  return '$cipher (security revision $revision)';
}
