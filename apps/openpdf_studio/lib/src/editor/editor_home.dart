import 'dart:async';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_domain/pdf_domain.dart';
import 'package:pdf_engine_api/pdf_engine_api.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:printing/printing.dart';

import '../../l10n/app_localizations.dart';
import '../services/document_file_service.dart';
import '../services/document_recovery_service.dart';
import '../services/document_scanner_service.dart';
import '../services/document_security_service.dart';
import '../services/document_signature_service.dart';
import '../services/document_stamp_service.dart';
import '../services/flat_form_detection_service.dart';
import '../services/images_to_pdf_service.dart';
import '../services/offline_ocr_service.dart';
import '../services/pdf_merge_service.dart';
import '../services/pdf_protection_service.dart';
import '../services/pdf_rewrite_service.dart';
import '../services/pdf_external_modification_exception.dart';
import '../services/portable_ai_model_manager.dart';
import '../services/portable_ai_self_test_service.dart';
import '../services/portable_form_inference_service.dart';
import '../services/raster_form_detection_service.dart';
import '../services/recent_documents_service.dart';
import '../services/secure_redaction_service.dart';
import '../services/smart_form_condition_service.dart';
import '../services/smart_form_label_recovery_service.dart';
import '../services/smart_form_service.dart';
import '../services/smart_form_semantic_service.dart';

final _qpdfEditorTools = Set<PdfEditTool>.unmodifiable(
  PdfEditTool.values.where((tool) => tool != PdfEditTool.redact),
);

class EditorHome extends StatefulWidget {
  const EditorHome({
    required this.engine,
    required this.fileService,
    required this.recoveryService,
    required this.recentDocumentsService,
    this.initialDocument,
    super.key,
  });

  final PdfEngine engine;
  final DocumentFileService fileService;
  final DocumentRecoveryService recoveryService;
  final RecentDocumentsService recentDocumentsService;
  final PdfDocumentSource? initialDocument;

  @override
  State<EditorHome> createState() => _EditorHomeState();
}

class _EditorHomeState extends State<EditorHome> {
  PdfOpenedDocument? _document;
  bool _busy = false;
  bool _modified = false;
  String? _busyMessage;
  String _documentPassword = '';
  PdfDocumentSource? _recoveryBaseSource;
  PdfEditingController? _editingController;
  List<RecentDocument> _recentDocuments = const [];
  String? _portableAIModelPath;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecentDocuments());
    unawaited(_loadPortableAIStatus());
    final initial = widget.initialDocument;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openProvidedDocument(initial)),
      );
    }
  }

  Future<void> _loadPortableAIStatus() async {
    final manager = PortableAIModelManager();
    try {
      final status = await manager.status();
      if (mounted && status.isReady) {
        setState(() => _portableAIModelPath = status.path);
      }
    } catch (_) {
      // Optional model discovery must never block normal PDF workflows.
    } finally {
      manager.close();
    }
  }

  @override
  void didUpdateWidget(covariant EditorHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialDocument;
    if (incoming != null && incoming.id != oldWidget.initialDocument?.id) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openIncomingDocument(incoming)),
      );
    }
  }

  Future<void> _openIncomingDocument(PdfDocumentSource source) async {
    if (!await _canLeaveCurrentDocument()) return;
    await _openProvidedDocument(source);
  }

  Future<void> _openProvidedDocument(PdfDocumentSource source) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final prepared = await _prepareRecovery(source);
      if (prepared == null || !mounted) return;
      _recoveryBaseSource = source;
      if (await _openSource(prepared)) {
        await widget.recentDocumentsService.remember(source);
        await _loadRecentDocuments();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadRecentDocuments() async {
    final recent = await widget.recentDocumentsService.list();
    if (mounted) setState(() => _recentDocuments = recent);
  }

  Future<void> _openDocument({PdfEditTool? startTool}) async {
    if (!await _canLeaveCurrentDocument()) return;
    setState(() => _busy = true);
    try {
      final source = await widget.fileService.pickPdf();
      if (source == null || !mounted) return;
      final prepared = await _prepareRecovery(source);
      if (prepared == null || !mounted) return;
      _recoveryBaseSource = source;
      if (await _openSource(prepared)) {
        if (startTool != null) _editingController?.tool = startTool;
        await widget.recentDocumentsService.remember(source);
        await _loadRecentDocuments();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRecent(RecentDocument recent) async {
    if (!await _canLeaveCurrentDocument()) return;
    setState(() => _busy = true);
    try {
      final source = await widget.fileService.openRecent(
        id: recent.id,
        displayName: recent.displayName,
        localPath: recent.localPath,
      );
      if (source == null) {
        await widget.recentDocumentsService.remove(recent.id);
        await _loadRecentDocuments();
        throw StateError(
          'The file is no longer available at its saved location.',
        );
      }
      final prepared = await _prepareRecovery(source);
      if (prepared == null || !mounted) return;
      _recoveryBaseSource = source;
      if (await _openSource(prepared)) {
        await widget.recentDocumentsService.remember(source);
        await _loadRecentDocuments();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createFromImages() async {
    if (!await _canLeaveCurrentDocument()) return;
    setState(() => _busy = true);
    try {
      final images = await widget.fileService.pickImages();
      if (images.isEmpty || !mounted) return;
      final bytes = await createPdfFromImages(images);
      final source = PdfDocumentSource(
        id: 'images-${DateTime.now().microsecondsSinceEpoch}',
        displayName: 'Images.pdf',
        bytes: bytes,
      );
      _recoveryBaseSource = source;
      if (await _openSource(source) && mounted) {
        setState(() => _modified = true);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mergePdfs() async {
    if (!await _canLeaveCurrentDocument()) return;
    setState(() => _busy = true);
    try {
      final sources = await widget.fileService.pickPdfs();
      if (sources.isEmpty || !mounted) return;
      if (sources.length < 2) {
        throw StateError('Select at least two PDF files to merge.');
      }
      final bytes = await mergePdfSources(sources);
      final source = PdfDocumentSource(
        id: 'merge-${DateTime.now().microsecondsSinceEpoch}',
        displayName: 'Merged.pdf',
        bytes: bytes,
      );
      _recoveryBaseSource = source;
      if (await _openSource(source) && mounted) {
        setState(() => _modified = true);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanDocument() async {
    if (!await _canLeaveCurrentDocument()) return;
    setState(() => _busy = true);
    try {
      final pages = await scanDocumentPages();
      if (pages.isEmpty || !mounted) return;
      final bytes = await createPdfFromImages(pages);
      final source = PdfDocumentSource(
        id: 'scan-${DateTime.now().microsecondsSinceEpoch}',
        displayName: 'Scan.pdf',
        bytes: bytes,
      );
      _recoveryBaseSource = source;
      if (await _openSource(source) && mounted) {
        setState(() => _modified = true);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<PdfDocumentSource?> _prepareRecovery(PdfDocumentSource source) async {
    final candidate = await widget.recoveryService.read(source);
    if (candidate == null || !mounted) return source;
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Recover unsaved changes?'),
        content: Text(
          'QPdf found edits from ${_formatRecoveryTime(candidate.updatedAt)}. '
          'Restore them, or discard the recovery data and open the saved file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (restore == null) return null;
    if (!restore) {
      await widget.recoveryService.clear(source);
      return source;
    }
    return PdfDocumentSource(
      id: source.id,
      displayName: source.displayName,
      bytes: candidate.bytes,
      localPath: source.localPath,
    );
  }

  String _formatRecoveryTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} at $hour:$minute';
  }

  Future<bool> _openSource(
    PdfDocumentSource source, {
    String password = '',
  }) async {
    try {
      final opened = await widget.engine.open(source, password: password);
      final editingController = PdfEditingController(
        source.bytes,
        password: password,
      );
      if (!mounted) {
        editingController.dispose();
        return false;
      }
      setState(() {
        _editingController?.dispose();
        _editingController = editingController;
        _document = opened;
        _documentPassword = password;
        _modified = false;
      });
      return true;
    } on PdfPasswordRequiredException {
      if (!mounted) return false;
      final entered = await _askForPassword();
      if (entered != null && mounted) {
        return _openSource(source, password: entered);
      }
      return false;
    }
  }

  Future<String?> _askForPassword() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password required'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PDF password'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Open'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _save(Uint8List bytes) async {
    final document = _document;
    if (document == null) return false;
    if (_editingController?.hasRedactionMarks ?? false) {
      _showError(
        StateError(
          'Apply or remove every redaction mark before saving. '
          'A marked region is not yet a secure redaction.',
        ),
      );
      return false;
    }
    try {
      final path = await widget.fileService.savePdf(
        document.source,
        bytes,
        expectedSourceBytes: _recoveryBaseSource?.bytes,
      );
      if (!mounted || path == null) return false;
      await _clearRecovery();
      if (!mounted) return false;
      final savedSource = PdfDocumentSource(
        id: document.source.id,
        displayName: document.source.displayName,
        bytes: bytes,
        localPath: path,
      );
      _recoveryBaseSource = savedSource;
      _document = PdfOpenedDocument(
        source: savedSource,
        summary: document.summary,
        engine: document.engine,
      );
      setState(() => _modified = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $path')));
      return true;
    } catch (error) {
      _showError(error);
      return false;
    }
  }

  Future<bool> _saveAs(Uint8List bytes) async {
    final document = _document;
    if (document == null) return false;
    if (_editingController?.hasRedactionMarks ?? false) {
      _showError(
        StateError(
          'Apply or remove every redaction mark before saving a copy. '
          'A marked region is not yet a secure redaction.',
        ),
      );
      return false;
    }
    try {
      final path = await widget.fileService.savePdfAs(
        document.source.displayName,
        bytes,
      );
      if (!mounted || path == null) return false;
      await _clearRecovery();
      if (!mounted) return false;
      setState(() => _modified = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved a copy to $path')));
      return true;
    } catch (error) {
      _showError(error);
      return false;
    }
  }

  Future<bool> _canLeaveCurrentDocument() async {
    if (_document == null || !_modified) return true;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save your changes?'),
        content: const Text(
          'This document has edits that have not been saved to the PDF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (choice == 'discard') {
      await _clearRecovery();
      return true;
    }
    if (choice == 'save') {
      final controller = _editingController;
      return controller != null && await _save(controller.bytes);
    }
    return false;
  }

  Future<void> _closeDocument() async {
    if (!await _canLeaveCurrentDocument() || !mounted) return;
    setState(() {
      _editingController?.dispose();
      _editingController = null;
      _document = null;
      _recoveryBaseSource = null;
      _documentPassword = '';
      _modified = false;
    });
  }

  Future<void> _printDocument(Uint8List bytes) async {
    try {
      await Printing.layoutPdf(
        name: _document?.source.displayName ?? 'QPdf document',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _applySecureRedactions(PdfEditingController editing) async {
    if (!editing.hasRedactionMarks) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Apply secure redactions?'),
        content: const Text(
          'QPdf will permanently flatten every page into a new '
          'high-resolution image. This prevents covered text and image pixels '
          'from remaining in hidden PDF objects.\n\n'
          'Search, selectable text, forms, links, comments, bookmarks, '
          'accessibility structure, metadata, and existing digital signatures '
          'will be removed. Save As is recommended.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('secure-redaction-confirm-apply'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Flatten and apply'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Applying secure redactions…';
    });
    PdfEditingController? workingCopy;
    try {
      // Work transactionally. If applying or rasterizing fails, the live
      // controller keeps its redaction marks and Save remains blocked.
      workingCopy = PdfEditingController(
        editing.bytes,
        password: _documentPassword,
      );
      if (!workingCopy.applyRedactions()) {
        throw StateError('The redaction marks could not be applied.');
      }
      final flattened = await securelyFlattenRedactedPdf(workingCopy.document);
      if (!mounted) return;
      final next = PdfEditingController(
        flattened,
        preferences: editing.preferences,
        pageClipboard: editing.pageClipboard,
      );
      final recoveryBase = _recoveryBaseSource;
      if (recoveryBase != null) {
        widget.recoveryService.schedule(recoveryBase, flattened);
      }
      setState(() {
        _editingController = next;
        _documentPassword = '';
        _modified = true;
      });
      editing.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Secure redactions applied. The document is now image-only.',
            ),
          ),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      workingCopy?.dispose();
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _shareDocument(Uint8List bytes) async {
    try {
      await Printing.sharePdf(
        bytes: bytes,
        filename: _document?.source.displayName ?? 'document.pdf',
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addPageNumbers(PdfEditingController editing) async {
    final controller = TextEditingController(text: 'Page {page} of {pages}');
    try {
      final template = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add page numbers'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Footer template',
              helperText: 'Tokens: {page}, {pages}, {label}, {date}',
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (template == null || template.trim().isEmpty) return;
      editing.apply(
        (editor) => editor.stampHeaderFooter(
          footer: PdfHeaderFooter(center: template.trim()),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addWatermark(PdfEditingController editing) async {
    final controller = TextEditingController(text: 'CONFIDENTIAL');
    try {
      final text = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add watermark'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Watermark text'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (text == null || text.trim().isEmpty) return;
      editing.apply((editor) => addTextWatermark(editor, text));
    } catch (error) {
      _showError(error);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addBatesNumbers(PdfEditingController editing) async {
    final prefix = TextEditingController(text: 'QPDF-');
    final start = TextEditingController(text: '1');
    final digits = TextEditingController(text: '6');
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Bates numbers'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: prefix,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Prefix'),
                ),
                TextField(
                  controller: start,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Start number'),
                ),
                TextField(
                  controller: digits,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Digits'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      editing.apply(
        (editor) => addBatesNumbers(
          editor,
          prefix: prefix.text,
          start: int.parse(start.text),
          digits: int.parse(digits.text),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      prefix.dispose();
      start.dispose();
      digits.dispose();
    }
  }

  Future<void> _editMetadata(PdfEditingController editing) async {
    final title = TextEditingController();
    final author = TextEditingController();
    final subject = TextEditingController();
    final keywords = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Document information'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: author,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                TextField(
                  controller: keywords,
                  decoration: const InputDecoration(labelText: 'Keywords'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      editing.apply(
        (editor) => editor.setInfo(
          title: title.text,
          author: author.text,
          subject: subject.text,
          keywords: keywords.text,
          creator: 'QPdf',
          producer: 'QPdf',
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      title.dispose();
      author.dispose();
      subject.dispose();
      keywords.dispose();
    }
  }

  Future<void> _compareWithPdf(PdfEditingController editing) async {
    try {
      final other = await widget.fileService.pickPdf();
      if (other == null || !mounted) return;
      final left = PdfDocument.open(editing.bytes, password: _documentPassword);
      final right = PdfDocument.open(other.bytes);
      final comparison = PdfComparisonController(before: left, after: right)
        ..build();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Document comparison'),
          content: SizedBox(
            width: 560,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Current document: ${left.pageCount} pages\n'
                  '${other.displayName}: ${right.pageCount} pages\n\n'
                  '${comparison.changes.length} text or page-structure changes found.',
                ),
                if (comparison.changes.isNotEmpty) const Divider(height: 28),
                for (final change in comparison.changes.take(20))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.change_circle_outlined),
                    title: Text(change.label),
                    subtitle: Text('Page ${change.displayPage + 1}'),
                  ),
                if (comparison.changes.length > 20)
                  Text(
                    '${comparison.changes.length - 20} additional changes omitted.',
                  ),
                const SizedBox(height: 8),
                const Text(
                  'The comparison aligns pages by position. Use independent visual and forensic tools for legal review.',
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _runOfflineOcr(PdfEditingController editing) async {
    if (!isOfflineOcrSupported) {
      _showError(
        UnsupportedError(
          'Offline OCR is available on Android, iOS, macOS, Windows, and Linux.',
        ),
      );
      return;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make text searchable?'),
        content: const Text(
          'QPdf will run OCR on this device. The first use downloads a '
          'verified model of about 21 MB; document pages are not uploaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run OCR'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Preparing offline OCR…';
    });
    try {
      final bytes = await applyOfflineOcr(
        editing.bytes,
        password: _documentPassword,
        onProgress: (message, fraction) {
          if (mounted) setState(() => _busyMessage = message);
        },
      );
      final current = _document;
      if (current == null) return;
      final revision = PdfDocumentSource(
        id: current.source.id,
        displayName: current.source.displayName,
        bytes: bytes,
        localPath: current.source.localPath,
      );
      if (await _openSource(revision, password: _documentPassword) && mounted) {
        widget.recoveryService.schedule(_recoveryBaseSource ?? revision, bytes);
        setState(() => _modified = true);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _auditDocument(PdfEditingController editing) async {
    try {
      final document = PdfDocument.open(
        editing.bytes,
        password: _documentPassword,
      );
      final accessibility = validatePdfUa(document);
      final archival = validatePdfA(document);
      final findings = <PdfConformanceIssue>[
        ...accessibility.issues,
        ...archival.issues,
      ];
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Document standards audit'),
          content: SizedBox(
            width: 620,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  '${accessibility.profile}: '
                  '${accessibility.isCompliant ? 'pass' : '${accessibility.errors.length} errors'}',
                ),
                Text(
                  '${archival.profile}: '
                  '${archival.isCompliant ? 'pass' : '${archival.errors.length} errors'}',
                ),
                const Divider(height: 28),
                if (findings.isEmpty)
                  const Text('No machine-checkable issues found.')
                else
                  for (final issue in findings.take(30))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        issue.severity == PdfConformanceSeverity.error
                            ? Icons.error_outline
                            : Icons.warning_amber_outlined,
                      ),
                      title: Text(issue.rule),
                      subtitle: Text(issue.message),
                    ),
                if (findings.length > 30)
                  Text('${findings.length - 30} additional findings omitted.'),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showSecurityReport(PdfEditingController editing) async {
    try {
      final report = inspectPdfSecurity(
        editing.bytes,
        password: _documentPassword,
      );
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Security & permissions'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      report.isEncrypted
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                    ),
                    title: Text(
                      report.isEncrypted
                          ? 'Password protected'
                          : 'No password protection',
                    ),
                    subtitle: Text('Encryption: ${report.algorithm}'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Document permissions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  for (final permission in PdfDocumentPermission.values)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        report.permissions[permission]!
                            ? Icons.check_circle_outline
                            : Icons.block_outlined,
                        color: report.permissions[permission]!
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                      ),
                      title: Text(permission.label),
                      trailing: Text(
                        report.permissions[permission]! ? 'Allowed' : 'Blocked',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    report.isEncrypted
                        ? 'Supported incremental edits retain this protection. Changing or removing protection performs a full rewrite and invalidates existing digital signatures.'
                        : 'You can add AES-256 password protection and choose which actions the user password permits.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (report.isEncrypted)
              TextButton(
                onPressed: () => Navigator.pop(context, 'remove'),
                child: const Text('Remove password'),
              ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, 'protect'),
              child: Text(report.isEncrypted ? 'Change password' : 'Protect'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == 'protect') {
        await _configurePasswordProtection(editing);
      } else if (action == 'remove') {
        await _removePasswordProtection(editing);
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _configurePasswordProtection(
    PdfEditingController editing,
  ) async {
    final password = TextEditingController();
    final confirmPassword = TextEditingController();
    final ownerPassword = TextEditingController();
    var allowPrinting = true;
    var allowHighQualityPrinting = true;
    var allowModification = true;
    var allowCopying = true;
    var allowAnnotations = true;
    var allowFormFilling = true;
    var allowAccessibility = true;
    var allowPageAssembly = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Password protection'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QPdf will create an AES-256 protected copy of the current revision. The owner password must be different and grants unrestricted access.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: password,
                      autofocus: true,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password to open',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ownerPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Owner password',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Allowed with the opening password',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Print'),
                      value: allowPrinting,
                      onChanged: (value) =>
                          setDialogState(() => allowPrinting = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('High-quality print'),
                      value: allowHighQualityPrinting,
                      onChanged: (value) => setDialogState(
                        () => allowHighQualityPrinting = value,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Modify content'),
                      value: allowModification,
                      onChanged: (value) =>
                          setDialogState(() => allowModification = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Copy text and graphics'),
                      value: allowCopying,
                      onChanged: (value) =>
                          setDialogState(() => allowCopying = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Comment and annotate'),
                      value: allowAnnotations,
                      onChanged: (value) =>
                          setDialogState(() => allowAnnotations = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fill form fields'),
                      value: allowFormFilling,
                      onChanged: (value) =>
                          setDialogState(() => allowFormFilling = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Accessibility extraction'),
                      value: allowAccessibility,
                      onChanged: (value) =>
                          setDialogState(() => allowAccessibility = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Assemble pages'),
                      value: allowPageAssembly,
                      onChanged: (value) =>
                          setDialogState(() => allowPageAssembly = value),
                    ),
                    const Text(
                      'Changing protection rewrites the file and invalidates existing digital signatures.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apply protection'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true || !mounted) return;
      if (password.text.isEmpty || password.text != confirmPassword.text) {
        _showError(ArgumentError('The opening passwords must match.'));
        return;
      }
      if (ownerPassword.text.isEmpty || ownerPassword.text == password.text) {
        _showError(
          ArgumentError(
            'Enter a different owner password for unrestricted access.',
          ),
        );
        return;
      }
      setState(() {
        _busy = true;
        _busyMessage = 'Applying AES-256 protection…';
      });
      final bytes = await protectPdf(
        editing.bytes,
        currentPassword: _documentPassword,
        options: PdfProtectionOptions(
          userPassword: password.text,
          ownerPassword: ownerPassword.text,
          allowPrinting: allowPrinting,
          allowHighQualityPrinting: allowHighQualityPrinting,
          allowModification: allowModification,
          allowCopying: allowCopying,
          allowAnnotations: allowAnnotations,
          allowFormFilling: allowFormFilling,
          allowAccessibility: allowAccessibility,
          allowPageAssembly: allowPageAssembly,
        ),
      );
      await _replaceWithRewrittenRevision(bytes, password: password.text);
    } catch (error) {
      _showError(error);
    } finally {
      password.dispose();
      confirmPassword.dispose();
      ownerPassword.dispose();
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _removePasswordProtection(PdfEditingController editing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove password protection?'),
        content: const Text(
          'The new revision will open without a password. This full rewrite invalidates existing digital signatures.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove password'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Removing password protection…';
    });
    try {
      final bytes = await unprotectPdf(
        editing.bytes,
        currentPassword: _documentPassword,
      );
      await _replaceWithRewrittenRevision(bytes);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _replaceWithRewrittenRevision(
    Uint8List bytes, {
    String password = '',
  }) async {
    final current = _document;
    if (current == null) return;
    final revision = PdfDocumentSource(
      id: current.source.id,
      displayName: current.source.displayName,
      bytes: bytes,
      localPath: current.source.localPath,
    );
    if (await _openSource(revision, password: password) && mounted) {
      widget.recoveryService.schedule(_recoveryBaseSource ?? revision, bytes);
      setState(() => _modified = true);
    }
  }

  Future<void> _optimizeDocument(PdfEditingController editing) async {
    var quality = 75.0;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Optimize PDF'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recompress large images and remove unused objects. Lower quality creates a smaller file.',
                ),
                const SizedBox(height: 16),
                Text('Image quality: ${quality.round()}%'),
                Slider(
                  value: quality,
                  min: 35,
                  max: 95,
                  divisions: 12,
                  label: '${quality.round()}%',
                  onChanged: (value) => setDialogState(() => quality = value),
                ),
                const Text(
                  'Optimization performs a full rewrite and invalidates existing digital signatures.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Optimize'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Optimizing PDF…';
    });
    try {
      final before = editing.bytes.length;
      final result = await optimizePdf(
        editing.bytes,
        password: _documentPassword,
        imageQuality: quality.round(),
      );
      await _replaceWithRewrittenRevision(
        result.bytes,
        password: _documentPassword,
      );
      if (mounted) {
        final delta = before - result.bytes.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.images} images optimized · ${_formatByteDifference(delta)}',
            ),
          ),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _scrubMetadata(PdfEditingController editing) async {
    final confirmed = await _confirmFullRewrite(
      title: 'Remove hidden metadata?',
      message:
          'QPdf will remove document properties and timestamps. This full rewrite invalidates existing digital signatures.',
      action: 'Remove metadata',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Removing metadata…';
    });
    try {
      final bytes = await scrubPdfMetadata(
        editing.bytes,
        password: _documentPassword,
      );
      await _replaceWithRewrittenRevision(bytes, password: _documentPassword);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _convertToPdfA(PdfEditingController editing) async {
    final confirmed = await _confirmFullRewrite(
      title: 'Convert to PDF/A?',
      message:
          'QPdf will create a PDF/A-1 archival revision. PDF/A forbids encryption, so password protection will be removed. Existing digital signatures will be invalidated.',
      action: 'Convert',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Converting to PDF/A…';
    });
    try {
      final bytes = await convertPdfToPdfA(
        editing.bytes,
        password: _documentPassword,
      );
      await _replaceWithRewrittenRevision(bytes);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<bool> _confirmFullRewrite({
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  String _formatByteDifference(int bytes) {
    if (bytes == 0) return 'file size unchanged';
    final magnitude = bytes.abs();
    final value = magnitude >= 1024 * 1024
        ? '${(magnitude / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(magnitude / 1024).toStringAsFixed(1)} KB';
    return bytes > 0 ? '$value smaller' : '$value larger';
  }

  Future<void> _verifyDigitalSignatures(PdfEditingController editing) async {
    try {
      final signatures = inspectPdfSignatures(
        editing.bytes,
        password: _documentPassword,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Digital signatures'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
            child: signatures.isEmpty
                ? const Text('This document has no digital signatures.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: signatures.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final signature = signatures[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        isThreeLine: true,
                        leading: Icon(
                          signature.intact
                              ? Icons.verified_outlined
                              : Icons.gpp_bad_outlined,
                          color: signature.intact
                              ? Colors.green
                              : Theme.of(context).colorScheme.error,
                        ),
                        title: Text(signature.signer),
                        subtitle: Text(
                          '${signature.intact ? 'Cryptographically intact' : 'Invalid or modified'} · '
                          '${signature.coversWholeDocument ? 'covers this revision' : 'later changes exist'}\n'
                          '${signature.trustStatus}'
                          '${signature.padesLevel == null ? '' : ' · PAdES ${signature.padesLevel}'}'
                          '${signature.timestampValid == null
                              ? ''
                              : signature.timestampValid!
                              ? ' · valid timestamp'
                              : ' · invalid timestamp'}'
                          '${signature.problems.isEmpty ? '' : '\n${signature.problems.join('; ')}'}',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addDigitalSignature(PdfEditingController editing) async {
    final name = TextEditingController();
    final reason = TextEditingController(text: 'Approved');
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create a digital signature'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'QPdf will create a one-time self-signed identity locally. '
                  'It proves whether the PDF changed afterward, but other '
                  'viewers will show the signer as untrusted until its '
                  'certificate is trusted.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Signer name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign'),
            ),
          ],
        ),
      );
      if (accepted != true || name.text.trim().isEmpty) return;
      final identity = PdfSigningIdentity.generate(name: name.text.trim());
      final changed = await editing.addSelfSignedSignature(
        identity,
        reason: reason.text.trim(),
      );
      if (changed && mounted) {
        setState(() => _modified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Digital signature added. Save the signed revision.'),
          ),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      name.dispose();
      reason.dispose();
    }
  }

  Future<void> _showFillAndSign(PdfEditingController editing) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('smart-fill-form-button'),
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Smart Fill'),
              subtitle: Text(
                editing.acroForm == null
                    ? 'No interactive form fields were found.'
                    : 'Review every field in one private, on-device questionnaire.',
              ),
              onTap: () => Navigator.pop(context, 'smart'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_document),
              title: const Text('Fill form fields'),
              subtitle: Text(
                editing.acroForm == null
                    ? 'No existing fields found. Use Edit > Form to create fields.'
                    : 'Tap text fields, check boxes, radio buttons, or choices.',
              ),
              onTap: () => Navigator.pop(context, 'fill'),
            ),
            ListTile(
              leading: const Icon(Icons.draw_outlined),
              title: const Text('Add handwritten signature'),
              subtitle: const Text('Draw once, then tap the page to place it.'),
              onTap: () => Navigator.pop(context, 'sign'),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Add digital signature'),
              subtitle: const Text(
                'Create a cryptographic self-signed revision.',
              ),
              onTap: () => Navigator.pop(context, 'digital'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'smart':
        editing.tool = PdfEditTool.select;
        await _showSmartFormFiller(editing);
      case 'fill':
        // Interactive AcroForm controls are mounted in reader/select mode.
        // The Form tool is intentionally reserved for field authoring and
        // suppresses direct input while it owns page gestures.
        editing.tool = PdfEditTool.select;
        await _showFormFieldFiller(editing);
      case 'sign':
        editing.tool = PdfEditTool.signature;
      case 'digital':
        await _addDigitalSignature(editing);
    }
  }

  Future<void> _showSmartFormFiller(PdfEditingController editing) async {
    const analyzer = SmartFormAnalyzer();
    final compatibility = analyzer.compatibility(editing.acroForm);
    var questions = analyzer.analyze(editing.acroForm);
    if (questions.isEmpty) {
      if (editing.acroForm == null &&
          await _detectAndCreateFlatFormFields(editing)) {
        // Let the detection review route finish its reverse transition before
        // mounting the questionnaire. Chaining both overlays in one frame can
        // leave stale accessibility nodes on mobile screen readers.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final current = _editingController;
        if (mounted && current != null) await _showSmartFormFiller(current);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fillable fields were found in this document.'),
        ),
      );
      return;
    }

    final labelRecovery = const SmartFormLabelRecoveryService().recover(
      editing.document,
      editing.acroForm,
      questions,
    );
    questions = labelRecovery.questions;

    var semantic = SmartFormSemanticResult(
      questions: questions,
      usedModel: false,
    );
    // Partial/XFA forms keep coordinate-based suggestions authoritative. A
    // model may organize trustworthy metadata, but cannot override uncertain
    // geometry or compatibility warnings.
    if (!compatibility.needsReview &&
        !kIsWeb &&
        const {
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      semantic = await const SmartFormSemanticService().analyze(questions);
      if (!mounted) return;
    } else if (!compatibility.needsReview) {
      final modelPath = _portableAIModelPath;
      if (modelPath != null) {
        const inference = PortableFormInferenceService();
        semantic = await SmartFormSemanticService(
          backend: (fields) => inference.analyze(fields, modelPath: modelPath),
          timeout: const Duration(seconds: 60),
          modelSource: SmartFormSemanticSource.portableModel,
        ).analyze(questions);
        if (!mounted) return;
      }
    }
    questions = semantic.questions;

    final formKey = GlobalKey<FormState>();
    final textValues = <String, String>{
      for (final question in questions)
        if (question.kind != SmartFormInputKind.checkBox &&
            question.kind != SmartFormInputKind.choice)
          question.fieldName: question.currentValue,
    };
    final checks = <String, bool>{
      for (final question in questions)
        if (question.kind == SmartFormInputKind.checkBox)
          question.fieldName: question.currentValue.isNotEmpty,
    };
    final choices = <String, String?>{
      for (final question in questions)
        if (question.kind == SmartFormInputKind.choice)
          question.fieldName:
              question.options.any(
                (option) => option.$1 == question.currentValue,
              )
              ? question.currentValue
              : null,
    };
    final displayLabels = <String, String>{
      for (final question in questions) question.fieldName: question.label,
    };
    const conditions = SmartFormConditionService();
    List<SmartFormQuestion> visibleQuestions() => conditions.visibleQuestions(
      questions,
      textValues: textValues,
      checks: checks,
      choices: choices,
    );

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final displayedQuestions = visibleQuestions();
          final hiddenCount = questions.length - displayedQuestions.length;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                maxWidth: 720,
              ),
              child: FocusTraversalGroup(
                key: const Key('smart-fill-focus-order'),
                policy: ReadingOrderTraversalPolicy(),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Smart Fill found ${questions.length} ${questions.length == 1 ? 'field' : 'fields'}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (semantic.usedModel) ...[
                            const SizedBox(width: 8),
                            const Chip(
                              avatar: Icon(Icons.memory_outlined, size: 16),
                              label: Text('On-device AI'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the information below. QPdf will populate the matching PDF fields after you review and confirm. Nothing leaves this device.',
                      ),
                      if (compatibility.needsReview) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            key: const Key('smart-fill-compatibility-warning'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              compatibility.hasXfa
                                  ? 'This PDF contains an Adobe XFA form. QPdf can fill the compatible fields listed below, but dynamic XFA rules may still require Adobe Acrobat. ${labelRecovery.recoveredCount} nearby-text ${labelRecovery.recoveredCount == 1 ? 'label is a suggestion' : 'labels are suggestions'} for you to review. Review every page after saving.'
                                  : '${compatibility.genericLabels} ${compatibility.genericLabels == 1 ? 'field has' : 'fields have'} limited producer metadata. QPdf found ${labelRecovery.recoveredCount} conservative nearby-text ${labelRecovery.recoveredCount == 1 ? 'suggestion' : 'suggestions'}; compare and edit them before populating the PDF.',
                            ),
                          ),
                        ),
                      ],
                      if (hiddenCount > 0) ...[
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          label:
                              '$hiddenCount conditional ${hiddenCount == 1 ? 'field is' : 'fields are'} hidden based on your answers',
                          child: Text(
                            '$hiddenCount conditional ${hiddenCount == 1 ? 'field is' : 'fields are'} hidden based on your answers. Existing values are always kept visible.',
                            key: const Key('smart-fill-conditional-summary'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: displayedQuestions.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final question = displayedQuestions[index];
                            final displayLabel =
                                displayLabels[question.fieldName] ??
                                question.label;
                            final requiredLabel = question.required ? ' *' : '';
                            final showSection =
                                index == 0 ||
                                displayedQuestions[index - 1].section !=
                                    question.section;
                            late Widget fieldInput;
                            if (question.kind == SmartFormInputKind.checkBox) {
                              fieldInput = SwitchListTile.adaptive(
                                key: Key(
                                  'smart-form-field-${question.fieldName}',
                                ),
                                contentPadding: EdgeInsets.zero,
                                title: Text('$displayLabel$requiredLabel'),
                                subtitle: Text(
                                  question.required
                                      ? 'Required confirmation'
                                      : 'Optional confirmation',
                                ),
                                value: checks[question.fieldName] ?? false,
                                onChanged: (value) => setSheetState(
                                  () => checks[question.fieldName] = value,
                                ),
                              );
                            } else if (question.kind ==
                                SmartFormInputKind.choice) {
                              fieldInput = DropdownButtonFormField<String>(
                                key: Key(
                                  'smart-form-field-${question.fieldName}',
                                ),
                                initialValue: choices[question.fieldName],
                                decoration: InputDecoration(
                                  labelText: '$displayLabel$requiredLabel',
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  for (final option in question.options)
                                    DropdownMenuItem(
                                      value: option.$1,
                                      child: Text(option.$2),
                                    ),
                                ],
                                validator: (value) =>
                                    question.required && value == null
                                    ? 'This field is required'
                                    : null,
                                onChanged: (value) => setSheetState(
                                  () => choices[question.fieldName] = value,
                                ),
                              );
                            } else {
                              fieldInput = TextFormField(
                                key: Key(
                                  'smart-form-field-${question.fieldName}',
                                ),
                                initialValue: textValues[question.fieldName],
                                maxLines:
                                    question.kind ==
                                        SmartFormInputKind.multiline
                                    ? 4
                                    : 1,
                                keyboardType: _smartFormKeyboard(question.kind),
                                autofillHints: _smartFormAutofillHints(
                                  question.kind,
                                ),
                                decoration: InputDecoration(
                                  labelText: '$displayLabel$requiredLabel',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    question.required &&
                                        (value?.trim().isEmpty ?? true)
                                    ? 'This field is required'
                                    : null,
                                onChanged: (value) {
                                  textValues[question.fieldName] = value;
                                  if (conditions.isController(question)) {
                                    setSheetState(() {});
                                  }
                                },
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showSection) ...[
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      question.section,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (question.labelNeedsReview) ...[
                                  TextFormField(
                                    key: Key(
                                      'smart-form-label-${question.fieldName}',
                                    ),
                                    initialValue: displayLabel,
                                    decoration: InputDecoration(
                                      labelText: 'Review detected PDF label',
                                      helperText:
                                          question.labelSource ==
                                              SmartFormLabelSource
                                                  .coordinateSuggestion
                                          ? 'Nearby page text - ${((question.labelConfidence ?? 0) * 100).round()}% confidence'
                                          : 'No reliable nearby label found - edit this before filling',
                                      prefixIcon: const Icon(
                                        Icons.fact_check_outlined,
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (value) => setSheetState(
                                      () => displayLabels[question.fieldName] =
                                          value.trim().isEmpty
                                          ? question.label
                                          : value.trim(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                fieldInput,
                              ],
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            key: const Key('smart-fill-apply-button'),
                            onPressed: () {
                              if (formKey.currentState?.validate() ?? false) {
                                Navigator.pop(sheetContext, true);
                              }
                            },
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Populate fields'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (accepted != true) return;

    final submittedQuestions = visibleQuestions();
    final pending = <SmartFormQuestion>[];
    for (final question in submittedQuestions) {
      final field = editing.acroForm?.fieldNamed(question.fieldName);
      if (field == null) continue;
      switch (question.kind) {
        case SmartFormInputKind.checkBox:
          final desired = checks[question.fieldName] ?? false;
          if (field.isChecked != desired) pending.add(question);
        case SmartFormInputKind.choice:
          final value = choices[question.fieldName];
          if (value != null && value != field.value) pending.add(question);
        default:
          final value = (textValues[question.fieldName] ?? '').trim();
          if (value != (field.value ?? '')) pending.add(question);
      }
    }
    if (pending.isEmpty) return;
    final changed = editing.apply((editor) {
      for (final question in pending) {
        final field = editor.acroForm?.fieldNamed(question.fieldName);
        if (field == null) continue;
        switch (question.kind) {
          case SmartFormInputKind.checkBox:
            editor.setCheckBoxValue(field, checks[question.fieldName] ?? false);
          case SmartFormInputKind.choice:
            final value = choices[question.fieldName];
            if (value == null) continue;
            if (field.type == PdfFieldType.radioGroup) {
              editor.setRadioValue(field, value);
            } else {
              editor.setChoiceValue(field, value);
            }
          default:
            editor.setTextValue(
              field,
              (textValues[question.fieldName] ?? '').trim(),
            );
        }
      }
    });
    if (!changed || !mounted) return;
    setState(() => _modified = true);
    final recoveryBase = _recoveryBaseSource;
    if (recoveryBase != null) {
      widget.recoveryService.schedule(recoveryBase, editing.bytes);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${submittedQuestions.length} form ${submittedQuestions.length == 1 ? 'field' : 'fields'} populated. Review the document before saving.',
        ),
      ),
    );
  }

  TextInputType _smartFormKeyboard(SmartFormInputKind kind) => switch (kind) {
    SmartFormInputKind.email => TextInputType.emailAddress,
    SmartFormInputKind.phone => TextInputType.phone,
    SmartFormInputKind.number => const TextInputType.numberWithOptions(
      decimal: true,
    ),
    SmartFormInputKind.multiline => TextInputType.multiline,
    _ => TextInputType.text,
  };

  Iterable<String>? _smartFormAutofillHints(SmartFormInputKind kind) =>
      switch (kind) {
        SmartFormInputKind.email => const [AutofillHints.email],
        SmartFormInputKind.phone => const [AutofillHints.telephoneNumber],
        _ => null,
      };

  Future<bool> _detectAndCreateFlatFormFields(
    PdfEditingController editing,
  ) async {
    setState(() {
      _busy = true;
      _busyMessage = 'Detecting form fields on this device…';
    });
    late FlatFormDetectionResult result;
    try {
      await Future<void>.delayed(Duration.zero);
      result = const FlatFormDetectionService().detect(editing.document);
      if (result.fields.isEmpty && result.imageOnlyPages.isNotEmpty) {
        final raster = await const RasterFormDetectionService().detect(
          editing.document,
          pages: result.imageOnlyPages,
        );
        result = FlatFormDetectionResult(
          fields: raster.fields,
          imageOnlyPages: raster.pagesNeedingOcr,
        );
      }
    } catch (error) {
      _showError(error);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
    // Let the busy overlay finish its semantics transition before mounting
    // either the review sheet or the OCR recovery message.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return false;
    if (result.fields.isEmpty) {
      final scanned = result.imageOnlyPages.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scanned > 0
                ? 'I found $scanned scanned ${scanned == 1 ? 'page' : 'pages'}, but no positioned labels. Run private OCR first, then use Smart Fill again.'
                : 'No reliable flat-form controls were detected. You can create fields manually with Edit > Form.',
          ),
          action: scanned > 0
              ? SnackBarAction(
                  label: 'Run OCR',
                  onPressed: () => unawaited(_runOfflineOcr(editing)),
                )
              : null,
        ),
      );
      return false;
    }

    final selected = <int>{
      for (var i = 0; i < result.fields.length; i++)
        if (result.fields[i].confidence >= 0.7) i,
    };
    final labels = <int, String>{
      for (var i = 0; i < result.fields.length; i++) i: result.fields[i].label,
    };
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              maxWidth: 720,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review detected fields',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'QPdf found these lines and boxes using private on-device page analysis. Correct the labels and deselect anything that is not a form field.',
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: result.fields.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final field = result.fields[index];
                      return CheckboxListTile(
                        key: Key('detected-flat-field-$index'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: selected.contains(index),
                        onChanged: (value) => setSheetState(() {
                          if (value ?? false) {
                            selected.add(index);
                          } else {
                            selected.remove(index);
                          }
                        }),
                        title: TextFormField(
                          initialValue: labels[index],
                          enabled: selected.contains(index),
                          decoration: const InputDecoration(
                            labelText: 'Field label',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => labels[index] = value,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Page ${field.pageIndex + 1} • ${field.kind == FlatFormControlKind.checkBox ? 'Check box' : 'Text'} • ${(field.confidence * 100).round()}% confidence',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const Key('create-detected-fields-button'),
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.auto_fix_high_outlined),
                      label: Text(
                        'Create ${selected.length} ${selected.length == 1 ? 'field' : 'fields'}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (accepted != true) return false;

    var created = 0;
    for (final index in selected.toList()..sort()) {
      final detection = result.fields[index];
      final generated = editing.addFormField(
        detection.kind == FlatFormControlKind.checkBox
            ? PdfFormFieldKind.checkBox
            : PdfFormFieldKind.text,
        detection.pageIndex,
        detection.rect,
      );
      if (generated == null) continue;
      final requested = (labels[index] ?? detection.label).trim();
      final name = _uniqueDetectedFieldName(
        editing,
        requested.isEmpty ? detection.label : requested,
        except: generated,
      );
      editing.renameFormField(generated, name);
      created++;
    }
    if (created == 0 || !mounted) return false;
    // Form widgets change the viewer's interactive/semantic topology. Start a
    // clean session from the one committed revision so stale page semantics
    // cannot survive from the previously form-less document.
    final next = PdfEditingController(
      editing.bytes,
      preferences: editing.preferences,
      pageClipboard: editing.pageClipboard,
    );
    setState(() {
      _editingController = next;
      _modified = true;
    });
    editing.dispose();
    final recoveryBase = _recoveryBaseSource;
    if (recoveryBase != null) {
      widget.recoveryService.schedule(recoveryBase, next.bytes);
    }
    return true;
  }

  String _uniqueDetectedFieldName(
    PdfEditingController editing,
    String requested, {
    required String except,
  }) {
    var candidate = requested;
    var suffix = 2;
    while (editing.acroForm?.fields.any(
          (field) => field.name != except && field.name == candidate,
        ) ??
        false) {
      candidate = '$requested $suffix';
      suffix++;
    }
    return candidate;
  }

  Future<void> _showFormFieldFiller(PdfEditingController editing) async {
    final fields = editing.acroForm?.fields ?? const <PdfFormField>[];
    final fillable = fields
        .where(
          (field) =>
              !field.isReadOnly &&
              const {
                PdfFieldType.text,
                PdfFieldType.checkBox,
                PdfFieldType.radioGroup,
                PdfFieldType.comboBox,
                PdfFieldType.listBox,
              }.contains(field.type),
        )
        .toList();
    if (fillable.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fillable fields found. Use Edit > Form to create fields.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final current = editing.acroForm;
          final currentFields = [
            for (final original in fillable)
              ?current?.fieldNamed(original.name),
          ];
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Form fields',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: currentFields.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final field = currentFields[index];
                        if (field.type == PdfFieldType.checkBox) {
                          return SwitchListTile.adaptive(
                            title: Text(field.name),
                            subtitle: const Text('Check box'),
                            value: field.isChecked,
                            onChanged: (_) {
                              editing.toggleFormCheckBox(field.name);
                              setSheetState(() {});
                            },
                          );
                        }
                        return ListTile(
                          leading: Icon(_formFieldIcon(field.type)),
                          title: Text(field.name),
                          subtitle: Text(_formFieldValue(field)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            if (field.type == PdfFieldType.text) {
                              await _editTextFormField(editing, field);
                            } else {
                              await _chooseFormFieldValue(editing, field);
                            }
                            if (context.mounted) setSheetState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _formFieldIcon(PdfFieldType type) => switch (type) {
    PdfFieldType.text => Icons.text_fields,
    PdfFieldType.radioGroup => Icons.radio_button_checked,
    PdfFieldType.comboBox ||
    PdfFieldType.listBox => Icons.arrow_drop_down_circle_outlined,
    _ => Icons.edit_document,
  };

  String _formFieldValue(PdfFormField field) {
    final value = field.value;
    if (value == null || value.isEmpty || value == 'Off') {
      return switch (field.type) {
        PdfFieldType.text => 'Empty text field',
        PdfFieldType.radioGroup => 'No option selected',
        _ => 'Choose an option',
      };
    }
    return value;
  }

  Future<void> _editTextFormField(
    PdfEditingController editing,
    PdfFormField field,
  ) async {
    var draft = field.value ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(field.name),
        content: TextFormField(
          initialValue: draft,
          autofocus: true,
          maxLines: field.isMultiline ? 5 : 1,
          decoration: const InputDecoration(labelText: 'Value'),
          onChanged: (value) => draft = value,
          onFieldSubmitted: field.isMultiline
              ? null
              : (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value != null) editing.setFormFieldText(field.name, value);
  }

  Future<void> _chooseFormFieldValue(
    PdfEditingController editing,
    PdfFormField field,
  ) async {
    final options = field.type == PdfFieldType.radioGroup
        ? field.onStates.map((value) => (value, value)).toList()
        : field.options;
    if (options.isEmpty) return;
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(field.name),
        children: [
          RadioGroup<String>(
            groupValue: field.value,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (export, display) in options)
                  RadioListTile<String>(title: Text(display), value: export),
              ],
            ),
          ),
        ],
      ),
    );
    if (value == null) return;
    if (field.type == PdfFieldType.radioGroup) {
      editing.setFormRadioValue(field.name, value);
    } else {
      editing.setFormChoiceValue(field.name, value);
    }
  }

  Future<void> _clearRecovery() async {
    final recoveryBase = _recoveryBaseSource;
    if (recoveryBase != null) {
      await widget.recoveryService.clear(recoveryBase);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is PdfOpenException
        ? error.message
        : error is PdfExternalModificationException
        ? error.toString()
        : 'Something went wrong: $error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _showAIModelSettings() async {
    final manager = PortableAIModelManager();
    late PortableAIModelStatus status;
    try {
      status = await manager.status();
    } catch (error) {
      manager.close();
      _showError(error);
      return;
    }
    var downloading = false;
    var testing = false;
    var received = 0;
    PortableAISelfTestResult? selfTestResult;
    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final manifest = status.manifest;
            final actionBusy = downloading || testing;
            final progress = manifest.sizeBytes == 0
                ? 0.0
                : (received / manifest.sizeBytes).clamp(0.0, 1.0);
            final stateLabel = switch (status.state) {
              PortableAIModelState.ready =>
                'Downloaded · ready for private analysis',
              PortableAIModelState.invalid => 'Invalid model · download again',
              PortableAIModelState.unavailable =>
                'Unavailable on this platform',
              PortableAIModelState.notDownloaded => 'Not downloaded',
            };
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.memory_outlined),
                  SizedBox(width: 10),
                  Text('On-device AI'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manifest.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(stateLabel),
                    const SizedBox(height: 16),
                    Text(
                      '${manifest.sizeMegabytes.toStringAsFixed(1)} MB · ${manifest.license}\n'
                      'The model is optional and is never downloaded automatically. After SHA-256 verification it stays on this device and can be deleted here. QPdf sends only field names and labels to it—never document pages, entered values, or signatures—and validates every suggestion before showing the form.',
                    ),
                    if (downloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 6),
                      Text(
                        '${(received / (1024 * 1024)).toStringAsFixed(1)} of ${manifest.sizeMegabytes.toStringAsFixed(1)} MB',
                      ),
                    ],
                    if (testing) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 6),
                      const Text('Testing private inference on this device…'),
                    ],
                    if (selfTestResult case final result?) ...[
                      const SizedBox(height: 16),
                      Container(
                        key: const Key('portable-ai-self-test-result'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: result.passed
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              result.passed
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${result.message} '
                                '${(result.elapsed.inMilliseconds / 1000).toStringAsFixed(2)} seconds.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (status.message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        status.message!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: actionBusy
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                if (status.isReady)
                  OutlinedButton.icon(
                    key: const Key('portable-ai-self-test-button'),
                    onPressed: actionBusy || status.path == null
                        ? null
                        : () async {
                            setDialogState(() {
                              testing = true;
                              selfTestResult = null;
                            });
                            try {
                              final result =
                                  await const PortableAISelfTestService().run(
                                    modelPath: status.path!,
                                  );
                              if (dialogContext.mounted) {
                                setDialogState(() => selfTestResult = result);
                              }
                            } catch (error) {
                              if (dialogContext.mounted) _showError(error);
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => testing = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.speed_outlined),
                    label: const Text('Test model'),
                  ),
                if (status.isReady)
                  TextButton(
                    onPressed: actionBusy
                        ? null
                        : () async {
                            final remove = await showDialog<bool>(
                              context: dialogContext,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete on-device model?'),
                                content: const Text(
                                  'This removes the optional model from this device. It can be downloaded and verified again later.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete model'),
                                  ),
                                ],
                              ),
                            );
                            if (remove != true) return;
                            await manager.delete();
                            status = await manager.status();
                            selfTestResult = null;
                            if (mounted) {
                              setState(() => _portableAIModelPath = null);
                            }
                            if (dialogContext.mounted) setDialogState(() {});
                          },
                    child: const Text('Delete model'),
                  )
                else if (status.state != PortableAIModelState.unavailable)
                  FilledButton.icon(
                    onPressed: actionBusy
                        ? null
                        : () async {
                            final download = await showDialog<bool>(
                              context: dialogContext,
                              builder: (context) => AlertDialog(
                                title: const Text(
                                  'Download optional AI model?',
                                ),
                                content: Text(
                                  'Download ${manifest.sizeMegabytes.toStringAsFixed(1)} MB from Hugging Face? The Apache-2.0 model will be verified with a pinned SHA-256 before QPdf accepts it. Wi-Fi is recommended.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Download'),
                                  ),
                                ],
                              ),
                            );
                            if (download != true || !dialogContext.mounted) {
                              return;
                            }
                            setDialogState(() {
                              downloading = true;
                              received = 0;
                            });
                            try {
                              status = await manager.download(
                                onProgress: (value, _) {
                                  if (dialogContext.mounted) {
                                    setDialogState(() => received = value);
                                  }
                                },
                              );
                              if (mounted) {
                                setState(
                                  () => _portableAIModelPath = status.path,
                                );
                              }
                            } catch (error) {
                              if (dialogContext.mounted) _showError(error);
                              status = await manager.status();
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => downloading = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download model'),
                  ),
              ],
            );
          },
        ),
      );
    } finally {
      manager.close();
    }
  }

  void _openShortcut() {
    if (_busy) return;
    unawaited(_openDocument());
  }

  void _saveShortcut() {
    final editing = _editingController;
    if (_busy || _document == null || editing == null) return;
    unawaited(_save(editing.bytes));
  }

  void _saveAsShortcut() {
    final editing = _editingController;
    if (_busy || _document == null || editing == null) return;
    unawaited(_saveAs(editing.bytes));
  }

  void _printShortcut() {
    final editing = _editingController;
    if (_busy || _document == null || editing == null) return;
    unawaited(_printDocument(editing.bytes));
  }

  /// Desktop accelerators. Each action is bound under both Control (Windows and
  /// Linux) and Meta/Command (macOS). Modifier combinations never carry text,
  /// so a focused text field still receives normal typing.
  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings() {
    final bindings = <ShortcutActivator, VoidCallback>{};
    void bind(
      LogicalKeyboardKey key,
      VoidCallback action, {
      bool shift = false,
    }) {
      bindings[SingleActivator(key, control: true, shift: shift)] = action;
      bindings[SingleActivator(key, meta: true, shift: shift)] = action;
    }

    bind(LogicalKeyboardKey.keyO, _openShortcut);
    bind(LogicalKeyboardKey.keyS, _saveShortcut);
    bind(LogicalKeyboardKey.keyS, _saveAsShortcut, shift: true);
    bind(LogicalKeyboardKey.keyP, _printShortcut);
    return bindings;
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return CallbackShortcuts(
      bindings: _buildShortcutBindings(),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                document == null
                    ? 'QPdf'
                    : '${document.source.displayName}${_modified ? ' *' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (document != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '${document.summary.pageCount} pages  •  PDF ${document.summary.pdfVersion}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          if (document != null)
            IconButton(
              key: const Key('close-document-button'),
              tooltip: 'Close document',
              onPressed: _busy ? null : _closeDocument,
              icon: const Icon(Icons.close),
            ),
          if (_editingController case final editing?)
            ListenableBuilder(
              listenable: editing,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('secure-redaction-tool-button'),
                    tooltip: 'Mark secure redaction',
                    onPressed: _busy
                        ? null
                        : () => editing.tool = PdfEditTool.redact,
                    icon: const Icon(Icons.gradient),
                  ),
                  if (editing.hasRedactionMarks)
                    IconButton.filledTonal(
                      key: const Key('secure-redaction-apply-button'),
                      tooltip: 'Apply secure redactions',
                      onPressed: _busy
                          ? null
                          : () => unawaited(_applySecureRedactions(editing)),
                      icon: const Icon(Icons.security),
                    ),
                ],
              ),
            ),
          IconButton(
            key: const Key('open-pdf-button'),
            tooltip: 'Open PDF',
            onPressed: _busy ? null : _openDocument,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            key: const Key('on-device-ai-settings-button'),
            tooltip: 'On-device AI',
            onPressed: _busy ? null : _showAIModelSettings,
            icon: const Icon(Icons.memory_outlined),
          ),
          IconButton(
            tooltip: 'About QPdf',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'QPdf',
              applicationVersion: '0.1.0 (1)',
              applicationLegalese:
                  'Copyright © 2026 Gaurav Studios. Documents stay local '
                  'unless you choose to share them.',
              children: const [
                SizedBox(height: 12),
                Text(
                  'Cross-platform PDF reading, editing, forms, page tools, '
                  'scanning, private OCR, and guarded on-device form intelligence.',
                ),
              ],
            ),
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          if (document == null)
            _EmptyState(
              onOpen: _busy ? null : _openDocument,
              onFillAndSign: _busy
                  ? null
                  : () => _openDocument(startTool: PdfEditTool.select),
              onCreateFromImages: _busy ? null : _createFromImages,
              onMergePdfs: _busy ? null : _mergePdfs,
              onScanDocument: _busy || !isDocumentScannerSupported
                  ? null
                  : _scanDocument,
              recentDocuments: _recentDocuments,
              onOpenRecent: _busy ? null : _openRecent,
            )
          else
            PdfEditorView(
              key: ValueKey(
                '${document.source.id}-${identityHashCode(_editingController)}',
              ),
              controller: _editingController,
              documentId: document.source.id,
              features: PdfEditorFeatures(tools: _qpdfEditorTools),
              onSave: (bytes) => unawaited(_save(bytes)),
              onSaveAs: (bytes) => unawaited(_saveAs(bytes)),
              showSaveButton: false,
              onDocumentChanged: (bytes) {
                final recoveryBase = _recoveryBaseSource;
                if (recoveryBase != null) {
                  widget.recoveryService.schedule(recoveryBase, bytes);
                }
                if (!_modified && mounted) setState(() => _modified = true);
              },
              onPickPdfToInsert: _pickBytes,
              onExportPages: _saveExportedPages,
              toolbarLeading: [
                (context, editing, viewer) => FilledButton.icon(
                  key: const Key('fill-and-sign-toolbar-button'),
                  onPressed: () => unawaited(_showFillAndSign(editing)),
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Fill & Sign'),
                ),
              ],
              toolbarTrailing: [
                (context, editing, viewer) => FilledButton.icon(
                  onPressed: _modified
                      ? () => unawaited(_save(editing.bytes))
                      : null,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save'),
                ),
                (context, editing, viewer) => PopupMenuButton<String>(
                  tooltip: 'Document actions',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'print':
                        unawaited(_printDocument(editing.bytes));
                      case 'share':
                        unawaited(_shareDocument(editing.bytes));
                      case 'pageNumbers':
                        unawaited(_addPageNumbers(editing));
                      case 'watermark':
                        unawaited(_addWatermark(editing));
                      case 'bates':
                        unawaited(_addBatesNumbers(editing));
                      case 'metadata':
                        unawaited(_editMetadata(editing));
                      case 'compare':
                        unawaited(_compareWithPdf(editing));
                      case 'ocr':
                        unawaited(_runOfflineOcr(editing));
                      case 'audit':
                        unawaited(_auditDocument(editing));
                      case 'security':
                        unawaited(_showSecurityReport(editing));
                      case 'optimize':
                        unawaited(_optimizeDocument(editing));
                      case 'scrubMetadata':
                        unawaited(_scrubMetadata(editing));
                      case 'pdfa':
                        unawaited(_convertToPdfA(editing));
                      case 'digitalSignature':
                        unawaited(_addDigitalSignature(editing));
                      case 'verifySignatures':
                        unawaited(_verifyDigitalSignatures(editing));
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'print',
                      child: ListTile(
                        leading: Icon(Icons.print_outlined),
                        title: Text('Print'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ocr',
                      child: ListTile(
                        leading: Icon(Icons.document_scanner_outlined),
                        title: Text('Make text searchable (OCR)'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: Icon(Icons.share_outlined),
                        title: Text('Share PDF'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pageNumbers',
                      child: ListTile(
                        leading: Icon(Icons.format_list_numbered),
                        title: Text('Add page numbers'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'watermark',
                      child: ListTile(
                        leading: Icon(Icons.branding_watermark_outlined),
                        title: Text('Add watermark'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'bates',
                      child: ListTile(
                        leading: Icon(Icons.numbers_outlined),
                        title: Text('Add Bates numbers'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'metadata',
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Document information'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'compare',
                      child: ListTile(
                        leading: Icon(Icons.compare_outlined),
                        title: Text('Compare with PDF'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'audit',
                      child: ListTile(
                        leading: Icon(Icons.fact_check_outlined),
                        title: Text('Standards audit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'security',
                      child: ListTile(
                        leading: Icon(Icons.shield_outlined),
                        title: Text('Security & permissions'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'optimize',
                      child: ListTile(
                        leading: Icon(Icons.compress_outlined),
                        title: Text('Optimize PDF'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'scrubMetadata',
                      child: ListTile(
                        leading: Icon(Icons.cleaning_services_outlined),
                        title: Text('Remove hidden metadata'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdfa',
                      child: ListTile(
                        leading: Icon(Icons.inventory_2_outlined),
                        title: Text('Convert to PDF/A'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'digitalSignature',
                      child: ListTile(
                        leading: Icon(Icons.verified_user_outlined),
                        title: Text('Digital signature'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'verifySignatures',
                      child: ListTile(
                        leading: Icon(Icons.verified_outlined),
                        title: Text('Verify signatures'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (_busy)
            ColoredBox(
              color: const Color(0x66000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        if (_busyMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(_busyMessage!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _pickBytes() async {
    final source = await widget.fileService.pickPdf();
    return source?.bytes;
  }

  void _saveExportedPages(Uint8List bytes) {
    final document = _document;
    if (document == null) return;
    final original = document.source.displayName;
    final base = original.toLowerCase().endsWith('.pdf')
        ? original.substring(0, original.length - 4)
        : original;
    widget.fileService
        .savePdfAs('${base}_pages.pdf', bytes)
        .catchError(_showExportError);
  }

  String? _showExportError(Object error) {
    _showError(error);
    return null;
  }

  @override
  void dispose() {
    _editingController?.dispose();
    unawaited(widget.recoveryService.dispose());
    super.dispose();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onOpen,
    required this.onFillAndSign,
    required this.onCreateFromImages,
    required this.onMergePdfs,
    required this.onScanDocument,
    required this.recentDocuments,
    required this.onOpenRecent,
  });

  final VoidCallback? onOpen;
  final VoidCallback? onFillAndSign;
  final VoidCallback? onCreateFromImages;
  final VoidCallback? onMergePdfs;
  final VoidCallback? onScanDocument;
  final List<RecentDocument> recentDocuments;
  final ValueChanged<RecentDocument>? onOpenRecent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 48.0 : 20.0;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                34,
                horizontalPadding,
                40,
              ),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.homeTitle,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.1,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.homePrompt,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 30),
                        _QuickActions(
                          onOpen: onOpen,
                          onFillAndSign: onFillAndSign,
                          onCreateFromImages: onCreateFromImages,
                          onMergePdfs: onMergePdfs,
                          onScanDocument: onScanDocument,
                        ),
                        const SizedBox(height: 38),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.recentDocuments,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.4,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: onOpen,
                              child: Text(l10n.actionBrowse),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Material(
                          color: colors.surface,
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.circular(20),
                          child: recentDocuments.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    children: [
                                      _SoftIcon(
                                        icon: Icons.schedule_outlined,
                                        color: colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          'No recent documents yet. Files you open will appear here.',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < recentDocuments.length;
                                      i++
                                    ) ...[
                                      ListTile(
                                        key: Key(
                                          'recent-${recentDocuments[i].id}',
                                        ),
                                        leading: _SoftIcon(
                                          icon: Icons.description_outlined,
                                          color: colors.primary,
                                        ),
                                        title: Text(
                                          recentDocuments[i].displayName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '${_recentLabel(recentDocuments[i].openedAt)}\n'
                                          '${recentDocuments[i].localPath}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Icon(
                                          Icons.chevron_right,
                                          color: colors.onSurfaceVariant,
                                        ),
                                        onTap: onOpenRecent == null
                                            ? null
                                            : () => onOpenRecent!(
                                                recentDocuments[i],
                                              ),
                                      ),
                                      if (i != recentDocuments.length - 1)
                                        const Divider(indent: 70),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 15,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                l10n.privacyFooter,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _recentLabel(DateTime openedAt) {
    final local = openedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = today.difference(day).inDays;
    if (days == 0) return 'Opened today';
    if (days == 1) return 'Opened yesterday';
    if (days > 1 && days < 7) return 'Opened $days days ago';
    return 'Opened ${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpen,
    required this.onFillAndSign,
    required this.onCreateFromImages,
    required this.onMergePdfs,
    required this.onScanDocument,
  });

  final VoidCallback? onOpen;
  final VoidCallback? onFillAndSign;
  final VoidCallback? onCreateFromImages;
  final VoidCallback? onMergePdfs;
  final VoidCallback? onScanDocument;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final l10n = AppLocalizations.of(context)!;
      final phone = constraints.maxWidth < 600;
      final compactWidth = phone
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth >= 1000
          ? 168.0
          : 180.0;
      final featureWidth = phone ? constraints.maxWidth : 344.0;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _HomeActionCard(
            key: const Key('fill-and-sign-home-button'),
            width: featureWidth,
            height: phone ? 164 : 176,
            icon: Icons.draw_outlined,
            title: l10n.actionFillAndSign,
            subtitle: l10n.fillAndSignSubtitle,
            primary: true,
            onTap: onFillAndSign,
          ),
          _HomeActionCard(
            key: const Key('empty-open-pdf-button'),
            width: compactWidth,
            icon: Icons.folder_open_outlined,
            title: l10n.actionOpen,
            subtitle: l10n.openSubtitle,
            onTap: onOpen,
          ),
          if (isDocumentScannerSupported)
            _HomeActionCard(
              key: const Key('scan-document-button'),
              width: compactWidth,
              icon: Icons.document_scanner_outlined,
              title: l10n.actionScanShort,
              subtitle: l10n.scanSubtitle,
              onTap: onScanDocument,
            ),
          _HomeActionCard(
            key: const Key('create-from-images-button'),
            width: compactWidth,
            icon: Icons.photo_library_outlined,
            title: l10n.photosTitle,
            subtitle: l10n.photosSubtitle,
            onTap: onCreateFromImages,
          ),
          _HomeActionCard(
            key: const Key('merge-pdfs-button'),
            width: compactWidth,
            icon: Icons.call_merge_outlined,
            title: l10n.combineTitle,
            subtitle: l10n.actionMergePdfs,
            onTap: onMergePdfs,
          ),
        ],
      );
    },
  );
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: color, size: 22),
  );
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.width,
    this.height = 144,
    this.primary = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: primary ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: primary ? 48 : 42,
                  height: primary ? 48 : 42,
                  decoration: BoxDecoration(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.18)
                        : colors.primary.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(primary ? 15 : 12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: primary ? 27 : 22,
                    color: primary ? Colors.white : colors.primary,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: primary ? Colors.white : colors.onSurface,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.25,
                            ),
                      ),
                    ),
                    if (primary)
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.78)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
