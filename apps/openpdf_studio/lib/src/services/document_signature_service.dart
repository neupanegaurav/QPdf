import 'dart:typed_data';

import 'package:pdf_document/pdf_document.dart';

final class PdfSignatureReportEntry {
  const PdfSignatureReportEntry({
    required this.signer,
    required this.intact,
    required this.coversWholeDocument,
    required this.trustStatus,
    required this.signedAt,
    required this.padesLevel,
    required this.timestampValid,
    required this.problems,
  });

  final String signer;
  final bool intact;
  final bool coversWholeDocument;
  final String trustStatus;
  final DateTime? signedAt;
  final String? padesLevel;
  final bool? timestampValid;
  final List<String> problems;
}

List<PdfSignatureReportEntry> inspectPdfSignatures(
  Uint8List bytes, {
  String password = '',
  PdfTrustStore? trustStore,
}) {
  final document = PdfDocument.open(bytes, password: password);
  return [
    for (final signature in PdfSignature.of(document))
      _inspectSignature(signature, trustStore),
  ];
}

PdfSignatureReportEntry _inspectSignature(
  PdfSignature signature,
  PdfTrustStore? trustStore,
) {
  final validation = signature.validate(trustStore: trustStore);
  final trustStatus = switch (validation.chainTrusted) {
    true => 'Trusted certificate chain',
    false => 'Untrusted certificate chain',
    null => 'Trust not evaluated',
  };
  return PdfSignatureReportEntry(
    signer:
        signature.signerName ??
        validation.signerCertificate?.subjectCommonName ??
        'Unknown signer',
    intact: validation.intact,
    coversWholeDocument: validation.coversWholeDocument,
    trustStatus: trustStatus,
    signedAt: validation.signedAt ?? signature.signingTime,
    padesLevel: validation.padesLevel?.name,
    timestampValid: validation.timestamp?.valid,
    problems: [...validation.problems, ...validation.chainProblems],
  );
}
