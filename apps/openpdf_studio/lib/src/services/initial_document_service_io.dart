import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pdf_domain/pdf_domain.dart';

const _channel = MethodChannel('studio.gaurav.qpdf/launch_document');
final _incomingDocuments = StreamController<PdfDocumentSource>.broadcast();
bool _channelHandlerInstalled = false;

Stream<PdfDocumentSource> get incomingDocuments => _incomingDocuments.stream;

PdfDocumentSource? _sourceFromPlatformData(Map<String, Object?>? data) {
  final bytes = data?['bytes'];
  final name = data?['name'];
  final id = data?['id'];
  if (bytes is! Uint8List || name is! String || id is! String) return null;
  return PdfDocumentSource(id: id, displayName: name, bytes: bytes);
}

void _installChannelHandler() {
  if (_channelHandlerInstalled || !(Platform.isAndroid || Platform.isIOS)) {
    return;
  }
  _channelHandlerInstalled = true;
  _channel.setMethodCallHandler((call) async {
    if (call.method != 'documentOpened') return;
    final arguments = call.arguments;
    if (arguments is! Map) return;
    final source = _sourceFromPlatformData(
      arguments.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (source != null) _incomingDocuments.add(source);
  });
}

Future<PdfDocumentSource?> loadInitialDocument(List<String> arguments) async {
  _installChannelHandler();
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final data = await _channel.invokeMapMethod<String, Object?>(
        'getInitialDocument',
      );
      return _sourceFromPlatformData(data);
    } on PlatformException {
      // A provider can revoke its grant, disappear, or send a URI the app
      // cannot read. Never prevent QPdf from rendering its Home screen.
      return null;
    }
  }
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    for (final argument in arguments) {
      if (!argument.toLowerCase().endsWith('.pdf')) continue;
      final file = File(argument);
      if (!await file.exists()) continue;
      return PdfDocumentSource(
        id: file.absolute.path,
        displayName: file.uri.pathSegments.last,
        bytes: await file.readAsBytes(),
        localPath: file.absolute.path,
      );
    }
  }
  return null;
}
