import 'dart:typed_data';

import 'package:pdf_manipulator/pdf_manipulator.dart' as manipulator;

final class PdfProtectionOptions {
  const PdfProtectionOptions({
    required this.userPassword,
    required this.ownerPassword,
    this.allowPrinting = true,
    this.allowHighQualityPrinting = true,
    this.allowModification = true,
    this.allowCopying = true,
    this.allowAnnotations = true,
    this.allowFormFilling = true,
    this.allowAccessibility = true,
    this.allowPageAssembly = true,
  });

  final String userPassword;
  final String ownerPassword;
  final bool allowPrinting;
  final bool allowHighQualityPrinting;
  final bool allowModification;
  final bool allowCopying;
  final bool allowAnnotations;
  final bool allowFormFilling;
  final bool allowAccessibility;
  final bool allowPageAssembly;
}

/// Rewrites [bytes] with AES-256 standard security and explicit permissions.
///
/// A full rewrite invalidates existing digital signatures, which callers must
/// confirm with the user before invoking this function.
Future<Uint8List> protectPdf(
  Uint8List bytes, {
  String currentPassword = '',
  required PdfProtectionOptions options,
}) => _rewriteProtection(
  bytes,
  currentPassword: currentPassword,
  encryption: manipulator.PdfEncryption.config(
    userPassword: options.userPassword,
    ownerPassword: options.ownerPassword,
    algorithm: manipulator.PdfEncryptionAlgorithm.aes256,
    permissions: manipulator.PdfPermissions(
      print: options.allowPrinting,
      printHq: options.allowHighQualityPrinting,
      modify: options.allowModification,
      copy: options.allowCopying,
      annotate: options.allowAnnotations,
      fillForms: options.allowFormFilling,
      accessibility: options.allowAccessibility,
      assemble: options.allowPageAssembly,
    ),
  ),
);

/// Removes standard password encryption with a structure-preserving rewrite.
Future<Uint8List> unprotectPdf(
  Uint8List bytes, {
  required String currentPassword,
}) => _rewriteProtection(
  bytes,
  currentPassword: currentPassword,
  encryption: const manipulator.PdfEncryption.remove(),
);

Future<Uint8List> _rewriteProtection(
  Uint8List bytes, {
  required String currentPassword,
  required manipulator.PdfEncryption encryption,
}) async {
  final engine = manipulator.Pdf();
  manipulator.PdfEditor? editor;
  try {
    editor = await engine.edit(
      manipulator.MemorySource(bytes),
      password: currentPassword.isEmpty ? null : currentPassword,
    );
    final output = manipulator.MemorySink();
    await editor.save(
      output,
      options: manipulator.PdfSaveOptions.fullRewrite(encryption: encryption),
    );
    return output.takeBytes();
  } finally {
    await editor?.dispose();
    await engine.dispose();
  }
}
