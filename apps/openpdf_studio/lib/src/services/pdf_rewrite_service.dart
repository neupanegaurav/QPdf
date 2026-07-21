import 'dart:typed_data';

import 'package:pdf_manipulator/pdf_manipulator.dart' as manipulator;

final class PdfOptimizationResult {
  const PdfOptimizationResult({required this.bytes, required this.images});

  final Uint8List bytes;
  final int images;
}

Future<PdfOptimizationResult> optimizePdf(
  Uint8List bytes, {
  String password = '',
  int imageQuality = 75,
}) async {
  final result = await _editAndRewrite(
    bytes,
    password: password,
    edit: (editor) => editor.optimizeImages(quality: imageQuality),
  );
  return PdfOptimizationResult(bytes: result.bytes, images: result.value);
}

Future<Uint8List> scrubPdfMetadata(
  Uint8List bytes, {
  String password = '',
}) async => (await _editAndRewrite<void>(
  bytes,
  password: password,
  edit: (editor) => editor.scrubMetadata(),
)).bytes;

Future<Uint8List> convertPdfToPdfA(
  Uint8List bytes, {
  String password = '',
  int level = 1,
}) async => (await _editAndRewrite<void>(
  bytes,
  password: password,
  edit: (editor) => editor.convertToPdfA(level: level),
  encryption: const manipulator.PdfEncryption.remove(),
)).bytes;

final class _RewriteResult<T> {
  const _RewriteResult(this.bytes, this.value);

  final Uint8List bytes;
  final T value;
}

Future<_RewriteResult<T>> _editAndRewrite<T>(
  Uint8List bytes, {
  required String password,
  required Future<T> Function(manipulator.PdfEditor editor) edit,
  manipulator.PdfEncryption encryption = const manipulator.PdfEncryption.keep(),
}) async {
  final engine = manipulator.Pdf();
  manipulator.PdfEditor? editor;
  try {
    editor = await engine.edit(
      manipulator.MemorySource(bytes),
      password: password.isEmpty ? null : password,
    );
    final value = await edit(editor);
    final output = manipulator.MemorySink();
    await editor.save(
      output,
      options: manipulator.PdfSaveOptions.fullRewrite(encryption: encryption),
    );
    return _RewriteResult(output.takeBytes(), value);
  } finally {
    await editor?.dispose();
    await engine.dispose();
  }
}
