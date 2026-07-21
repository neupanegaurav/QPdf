library;

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:flutter_pdfium/flutter_pdfium.dart';
import 'package:pdf_domain/pdf_domain.dart';
import 'package:pdf_engine_api/pdf_engine_api.dart';

/// Optional PDFium compatibility oracle.
///
/// QPdf does not ship this adapter in its main application yet. Keeping it in
/// a separate package lets CI and native test hosts compare parsing behavior
/// without making PDFium binaries part of web or Linux builds.
final class PdfiumEngine implements PdfEngine {
  static const _descriptor = PdfEngineDescriptor(
    id: 'pdfium-native',
    label: 'PDFium native comparison engine',
    experimental: true,
    capabilities: {
      PdfEngineCapability.render,
      PdfEngineCapability.textSelection,
      PdfEngineCapability.search,
      PdfEngineCapability.forms,
    },
  );

  @override
  PdfEngineDescriptor get descriptor => _descriptor;

  @override
  Future<PdfOpenedDocument> open(
    PdfDocumentSource source, {
    String password = '',
  }) async {
    final library = createInitializedLibrary();
    try {
      return using((arena) {
        final data = arena<ffi.Uint8>(source.bytes.length);
        data.asTypedList(source.bytes.length).setAll(0, source.bytes);
        final passwordPointer = password.isEmpty
            ? ffi.nullptr.cast<ffi.Char>()
            : password.toNativeUtf8(allocator: arena).cast<ffi.Char>();
        final document = library.LoadMemDocument64(
          data.cast<ffi.Void>(),
          source.bytes.length,
          passwordPointer,
        );
        if (document == ffi.nullptr) {
          final error = library.GetLastError();
          if (error == FPDF_ERR_PASSWORD) {
            throw const PdfPasswordRequiredException();
          }
          throw PdfInvalidDocumentException(
            'PDFium could not open this document (error $error).',
          );
        }

        try {
          final versionPointer = arena<ffi.Int>();
          final hasVersion =
              library.GetFileVersion(document, versionPointer) != 0;
          final rawVersion = hasVersion ? versionPointer.value : 17;
          final version = '${rawVersion ~/ 10}.${rawVersion % 10}';
          return PdfOpenedDocument(
            source: source,
            engine: descriptor,
            summary: PdfDocumentSummary(
              pageCount: library.GetPageCount(document),
              pdfVersion: version,
            ),
          );
        } finally {
          library.CloseDocument(document);
        }
      }, malloc);
    } finally {
      library.DestroyLibrary();
    }
  }
}
