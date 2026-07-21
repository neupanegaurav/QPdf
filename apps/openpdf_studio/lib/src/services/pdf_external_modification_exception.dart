final class PdfExternalModificationException implements Exception {
  const PdfExternalModificationException(this.path);

  final String path;

  @override
  String toString() =>
      'The PDF changed in another application. Save a copy or reopen it before overwriting: $path';
}
