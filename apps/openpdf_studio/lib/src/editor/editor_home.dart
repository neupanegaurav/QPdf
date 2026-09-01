import 'dart:async';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import '../services/advanced_print_service.dart';
import '../services/images_to_pdf_service.dart';
import '../services/offline_ocr_service.dart';
import '../services/open_documents_session_service.dart';
import '../services/pdf_merge_service.dart';
import '../services/pdf_protection_service.dart';
import '../services/pdf_rewrite_service.dart';
import '../services/pdf_external_modification_exception.dart';
import '../services/recent_documents_service.dart';
import '../services/reveal_local_file.dart';
import '../services/secure_redaction_service.dart';
import 'document_commands.dart';
import 'document_desktop_menu_bar.dart';
import 'document_edit_menu.dart';
import 'document_mode_rail.dart';
import 'document_tools_panel.dart';

final _qpdfEditorTools = Set<PdfEditTool>.unmodifiable(
  PdfEditTool.values.where((tool) => tool != PdfEditTool.redact),
);

enum _WorkspaceContextAction { select, edit, comment, fillAndSign, allTools }

enum _RecentAction { pin, unpin, reveal, remove }

class EditorHome extends StatefulWidget {
  const EditorHome({
    required this.engine,
    required this.fileService,
    required this.recoveryService,
    required this.recentDocumentsService,
    required this.openDocumentsSessionService,
    this.initialDocument,
    super.key,
  });

  final PdfEngine engine;
  final DocumentFileService fileService;
  final DocumentRecoveryService recoveryService;
  final RecentDocumentsService recentDocumentsService;
  final OpenDocumentsSessionService openDocumentsSessionService;
  final PdfDocumentSource? initialDocument;

  @override
  State<EditorHome> createState() => _EditorHomeState();
}

class _EditorHomeState extends State<EditorHome> {
  static const _maximumOpenDocuments = 8;

  final List<_DocumentSession> _sessions = [];
  int _activeSessionIndex = -1;
  bool _busy = false;
  String? _busyMessage;
  List<RecentDocument> _recentDocuments = const [];
  bool _draggingFiles = false;

  _DocumentSession? get _activeSession =>
      _activeSessionIndex >= 0 && _activeSessionIndex < _sessions.length
      ? _sessions[_activeSessionIndex]
      : null;

  PdfOpenedDocument? get _document => _activeSession?.document;
  set _document(PdfOpenedDocument? value) {
    if (value != null) _activeSession?.document = value;
  }

  bool get _modified => _activeSession?.modified ?? false;
  set _modified(bool value) {
    _activeSession?.modified = value;
  }

  String get _documentPassword => _activeSession?.password ?? '';
  set _documentPassword(String value) {
    _activeSession?.password = value;
  }

  PdfDocumentSource? get _recoveryBaseSource =>
      _activeSession?.recoveryBaseSource;
  set _recoveryBaseSource(PdfDocumentSource? value) {
    if (value != null) _activeSession?.recoveryBaseSource = value;
  }

  PdfEditingController? get _editingController => _activeSession?.controller;
  set _editingController(PdfEditingController? value) {
    if (value != null) _activeSession?.controller = value;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecentDocuments());
    final initial = widget.initialDocument;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openProvidedDocument(initial)),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_restoreOpenDocuments()),
      );
    }
  }

  Future<void> _restoreOpenDocuments() async {
    final saved = await widget.openDocumentsSessionService.read();
    if (!mounted || saved.documents.isEmpty || _sessions.isNotEmpty) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Restoring documents…';
    });
    try {
      for (final item in saved.documents) {
        final source = await widget.fileService.openRecent(
          id: item.id,
          displayName: item.displayName,
          localPath: item.localPath,
        );
        if (source == null || !mounted) continue;
        await _openSource(source, openInNewTab: true, persistSession: false);
      }
      if (!mounted) return;
      final activeIndex = _sessions.indexWhere(
        (session) => session.document.source.id == saved.activeDocumentId,
      );
      if (activeIndex >= 0) setState(() => _activeSessionIndex = activeIndex);
      await _persistOpenDocuments();
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

  Future<void> _persistOpenDocuments() {
    final documents = _sessions
        .map((session) => session.document.source)
        .where((source) => source.localPath?.isNotEmpty ?? false)
        .map(
          (source) => OpenDocumentSessionEntry(
            id: source.id,
            displayName: source.displayName,
            localPath: source.localPath!,
          ),
        )
        .toList(growable: false);
    return widget.openDocumentsSessionService.write(
      OpenDocumentsSession(
        documents: documents,
        activeDocumentId: _activeSession?.document.source.id,
      ),
    );
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
    await _openProvidedDocument(source);
  }

  Future<void> _openProvidedDocument(PdfDocumentSource source) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final prepared = await _prepareRecovery(source);
      if (prepared == null || !mounted) return;
      if (await _openSource(
        prepared,
        openInNewTab: true,
        recoveryBaseSource: source,
      )) {
        await widget.recentDocumentsService.remember(source);
        await _loadRecentDocuments();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDroppedFiles(DropDoneDetails details) async {
    if (mounted) setState(() => _draggingFiles = false);
    final pdfs = details.files
        .where((item) => item.name.toLowerCase().endsWith('.pdf'))
        .take(_maximumOpenDocuments - _sessions.length)
        .toList(growable: false);
    if (pdfs.isEmpty) {
      _showError(StateError('Drop one or more PDF files to open them.'));
      return;
    }
    setState(() {
      _busy = true;
      _busyMessage = pdfs.length == 1
          ? 'Opening dropped PDF…'
          : 'Opening ${pdfs.length} dropped PDFs…';
    });
    try {
      for (final item in pdfs) {
        final bookmark = item.extraAppleBookmark;
        if (bookmark != null && bookmark.isNotEmpty) {
          await DesktopDrop.instance.startAccessingSecurityScopedResource(
            bookmark: bookmark,
          );
        }
        final bytes = await item.readAsBytes();
        if (bytes.length < 5 ||
            String.fromCharCodes(bytes.take(5)) != '%PDF-') {
          throw StateError('${item.name} is not a valid PDF file.');
        }
        final path = item.fromPromise || item.path.isEmpty ? null : item.path;
        final source = PdfDocumentSource(
          id: path ?? 'drop:${item.name}:${bytes.length}',
          displayName: item.name,
          bytes: bytes,
          localPath: path,
        );
        if (!mounted) return;
        if (await _openSource(
          source,
          openInNewTab: true,
          recoveryBaseSource: source,
        )) {
          await widget.recentDocumentsService.remember(source);
        }
      }
      await _loadRecentDocuments();
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

  Future<void> _loadRecentDocuments() async {
    final recent = await widget.recentDocumentsService.list();
    if (mounted) setState(() => _recentDocuments = recent);
  }

  Future<void> _openDocument({PdfEditTool? startTool}) async {
    setState(() => _busy = true);
    try {
      final source = await widget.fileService.pickPdf();
      if (source == null || !mounted) return;
      final prepared = await _prepareRecovery(source);
      if (prepared == null || !mounted) return;
      if (await _openSource(
        prepared,
        openInNewTab: true,
        recoveryBaseSource: source,
      )) {
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
      if (await _openSource(
        prepared,
        openInNewTab: true,
        recoveryBaseSource: source,
      )) {
        await widget.recentDocumentsService.remember(source);
        await _loadRecentDocuments();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleRecentAction(
    RecentDocument recent,
    _RecentAction action,
  ) async {
    try {
      switch (action) {
        case _RecentAction.pin:
          await widget.recentDocumentsService.setPinned(recent.id, true);
        case _RecentAction.unpin:
          await widget.recentDocumentsService.setPinned(recent.id, false);
        case _RecentAction.reveal:
          if (!await revealLocalFile(recent.localPath)) {
            throw StateError('The containing folder could not be opened.');
          }
        case _RecentAction.remove:
          await widget.recentDocumentsService.remove(recent.id);
      }
      if (action != _RecentAction.reveal) await _loadRecentDocuments();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _createFromImages() async {
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
      if (await _openSource(
            source,
            openInNewTab: true,
            recoveryBaseSource: source,
          ) &&
          mounted) {
        setState(() => _modified = true);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mergePdfs() async {
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
      if (await _openSource(
            source,
            openInNewTab: true,
            recoveryBaseSource: source,
          ) &&
          mounted) {
        setState(() => _modified = true);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanDocument() async {
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
      if (await _openSource(
            source,
            openInNewTab: true,
            recoveryBaseSource: source,
          ) &&
          mounted) {
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
    bool openInNewTab = false,
    PdfDocumentSource? recoveryBaseSource,
    bool persistSession = true,
  }) async {
    if (openInNewTab) {
      final existing = _sessions.indexWhere(
        (session) => session.document.source.id == source.id,
      );
      if (existing >= 0) {
        if (mounted) setState(() => _activeSessionIndex = existing);
        return true;
      }
      if (_sessions.length >= _maximumOpenDocuments) {
        _showError(
          StateError(
            'Close a document before opening another. QPdf keeps up to '
            '$_maximumOpenDocuments documents open to limit memory use.',
          ),
        );
        return false;
      }
    }
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
        if (openInNewTab || _activeSession == null) {
          _sessions.add(
            _DocumentSession(
              document: opened,
              controller: editingController,
              password: password,
              recoveryBaseSource: recoveryBaseSource ?? source,
            ),
          );
          _activeSessionIndex = _sessions.length - 1;
        } else {
          final session = _activeSession!;
          session.controller.dispose();
          session
            ..controller = editingController
            ..document = opened
            ..password = password
            ..modified = false;
        }
      });
      if (persistSession) await _persistOpenDocuments();
      return true;
    } on PdfPasswordRequiredException {
      if (!mounted) return false;
      final entered = await _askForPassword();
      if (entered != null && mounted) {
        return _openSource(
          source,
          password: entered,
          openInNewTab: openInNewTab,
          recoveryBaseSource: recoveryBaseSource,
          persistSession: persistSession,
        );
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
      await _persistOpenDocuments();
      if (!mounted) return false;
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
      final removed = _sessions.removeAt(_activeSessionIndex);
      removed.controller.dispose();
      removed.viewerController.dispose();
      if (_sessions.isEmpty) {
        _activeSessionIndex = -1;
      } else if (_activeSessionIndex >= _sessions.length) {
        _activeSessionIndex = _sessions.length - 1;
      }
    });
    await _persistOpenDocuments();
  }

  void _switchToSession(int index) {
    if (_busy || index == _activeSessionIndex) return;
    setState(() => _activeSessionIndex = index);
    unawaited(_persistOpenDocuments());
  }

  Future<void> _closeSession(int index) async {
    if (_busy || index < 0 || index >= _sessions.length) return;
    final previous = _activeSessionIndex;
    if (index != previous) setState(() => _activeSessionIndex = index);
    if (!await _canLeaveCurrentDocument() || !mounted) {
      if (mounted && previous < _sessions.length) {
        setState(() => _activeSessionIndex = previous);
      }
      return;
    }
    setState(() {
      final removed = _sessions.removeAt(index);
      removed.controller.dispose();
      removed.viewerController.dispose();
      if (_sessions.isEmpty) {
        _activeSessionIndex = -1;
      } else {
        final adjustedPrevious = previous > index ? previous - 1 : previous;
        _activeSessionIndex = adjustedPrevious.clamp(0, _sessions.length - 1);
      }
    });
    await _persistOpenDocuments();
  }

  Future<void> _printDocument(Uint8List bytes) async {
    final selection = await _showPrintOptions();
    if (selection == null || !mounted) return;
    try {
      final printable = buildPrintSelection(bytes, selection);
      await Printing.layoutPdf(
        name: _document?.source.displayName ?? 'QPdf document',
        onLayout: (_) async => printable,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<PdfPrintSelection?> _showPrintOptions() async {
    final range = TextEditingController();
    var subset = PdfPrintSubset.all;
    try {
      return await showDialog<PdfPrintSelection>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Print'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('print-page-range'),
                    controller: range,
                    decoration: const InputDecoration(
                      labelText: 'Pages',
                      hintText: 'All pages, or 1-3, 5, 8-10',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PdfPrintSubset>(
                    key: const Key('print-page-subset'),
                    initialValue: subset,
                    decoration: const InputDecoration(labelText: 'Subset'),
                    items: const [
                      DropdownMenuItem(
                        value: PdfPrintSubset.all,
                        child: Text('All selected pages'),
                      ),
                      DropdownMenuItem(
                        value: PdfPrintSubset.odd,
                        child: Text('Odd pages only'),
                      ),
                      DropdownMenuItem(
                        value: PdfPrintSubset.even,
                        child: Text('Even pages only'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => subset = value ?? PdfPrintSubset.all,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Paper size, orientation, scaling, duplex, grayscale, '
                    'pages per sheet, booklet, and poster options are provided '
                    'by your system print panel where supported.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('print-continue'),
                onPressed: () => Navigator.pop(
                  context,
                  PdfPrintSelection(range: range.text, subset: subset),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      range.dispose();
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
              key: const Key('fill-form-fields-button'),
              leading: const Icon(Icons.edit_document),
              title: const Text('Fill form fields'),
              subtitle: Text(
                editing.acroForm == null
                    ? 'No existing fields found. Use “Type on page” instead.'
                    : 'Tap text fields, check boxes, radio buttons, or choices.',
              ),
              onTap: () => Navigator.pop(context, 'fill'),
            ),
            ListTile(
              key: const Key('type-on-page-button'),
              leading: const Icon(Icons.text_fields),
              title: const Text('Type on page'),
              subtitle: const Text(
                'Drag a box anywhere, then type — works on flat or scanned forms.',
              ),
              onTap: () => Navigator.pop(context, 'text'),
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
      case 'fill':
        // Interactive AcroForm controls are mounted in reader/select mode.
        // The Form tool is intentionally reserved for field authoring and
        // suppresses direct input while it owns page gestures.
        editing.tool = PdfEditTool.select;
        await _showFormFieldFiller(editing);
      case 'text':
        // Free-text typing works on any page, including flattened or scanned
        // forms that carry no interactive fields. Drag a box, then type.
        editing.tool = PdfEditTool.freeText;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Drag a box on the page, then type your text.'),
            ),
          );
        }
      case 'sign':
        editing.tool = PdfEditTool.signature;
      case 'digital':
        await _addDigitalSignature(editing);
    }
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

  void _allToolsShortcut() {
    final editing = _editingController;
    if (_busy || _document == null || editing == null) return;
    unawaited(_showDocumentTools(editing));
  }

  void _undoShortcut() {
    final editing = _editingController;
    if (_busy || editing == null || !editing.canUndo) return;
    editing.undo();
  }

  void _redoShortcut() {
    final editing = _editingController;
    if (_busy || editing == null || !editing.canRedo) return;
    editing.redo();
  }

  void _closeTabShortcut() {
    if (_busy || _activeSession == null) return;
    unawaited(_closeDocument());
  }

  void _nextTabShortcut({required bool reverse}) {
    if (_busy || _sessions.length < 2) return;
    final delta = reverse ? -1 : 1;
    final next = (_activeSessionIndex + delta) % _sessions.length;
    setState(() => _activeSessionIndex = next);
  }

  void _runDocumentCommand(
    DocumentCommandId command,
    PdfEditingController editing,
  ) {
    switch (command) {
      case DocumentCommandId.print:
        unawaited(_printDocument(editing.bytes));
      case DocumentCommandId.share:
        unawaited(_shareDocument(editing.bytes));
      case DocumentCommandId.pageNumbers:
        unawaited(_addPageNumbers(editing));
      case DocumentCommandId.watermark:
        unawaited(_addWatermark(editing));
      case DocumentCommandId.bates:
        unawaited(_addBatesNumbers(editing));
      case DocumentCommandId.metadata:
        unawaited(_editMetadata(editing));
      case DocumentCommandId.compare:
        unawaited(_compareWithPdf(editing));
      case DocumentCommandId.ocr:
        unawaited(_runOfflineOcr(editing));
      case DocumentCommandId.audit:
        unawaited(_auditDocument(editing));
      case DocumentCommandId.security:
        unawaited(_showSecurityReport(editing));
      case DocumentCommandId.optimize:
        unawaited(_optimizeDocument(editing));
      case DocumentCommandId.scrubMetadata:
        unawaited(_scrubMetadata(editing));
      case DocumentCommandId.pdfa:
        unawaited(_convertToPdfA(editing));
      case DocumentCommandId.digitalSignature:
        unawaited(_addDigitalSignature(editing));
      case DocumentCommandId.verifySignatures:
        unawaited(_verifyDigitalSignatures(editing));
    }
  }

  Future<void> _showDocumentTools(PdfEditingController editing) async {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    if (wide) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: DocumentToolsPanel(
            onSelected: (command) => _runDocumentCommand(command, editing),
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: DocumentToolsPanel(
          onSelected: (command) => _runDocumentCommand(command, editing),
        ),
      ),
    );
  }

  Future<void> _showEditMenu(PdfEditingController editing) async {
    if (MediaQuery.sizeOf(context).width < 900) {
      await _showDocumentTools(editing);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black38,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        child: DocumentEditMenu(
          onToolSelected: (tool) => editing.tool = tool,
          onCommandSelected: (command) => _runDocumentCommand(command, editing),
          onFillAndSign: () => unawaited(_showFillAndSign(editing)),
          onAllTools: () => unawaited(_showDocumentTools(editing)),
        ),
      ),
    );
  }

  void _selectWorkspaceMode(
    DocumentWorkspaceMode mode,
    PdfEditingController editing,
  ) {
    final session = _activeSession;
    if (session == null) return;
    setState(() => session.workspaceMode = mode);
    switch (mode) {
      case DocumentWorkspaceMode.read:
        editing.tool = PdfEditTool.select;
      case DocumentWorkspaceMode.edit:
        editing.tool = PdfEditTool.content;
      case DocumentWorkspaceMode.comment:
        editing.tool = PdfEditTool.note;
      case DocumentWorkspaceMode.fillAndSign:
        unawaited(_showFillAndSign(editing));
      case DocumentWorkspaceMode.organize:
        unawaited(_showDocumentTools(editing));
      case DocumentWorkspaceMode.convert:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Document conversion is not available in this release yet.',
            ),
          ),
        );
      case DocumentWorkspaceMode.protect:
        unawaited(_showSecurityReport(editing));
    }
  }

  Widget _buildDocumentWorkspace(
    BuildContext context,
    PdfOpenedDocument document,
    PdfEditingController editing,
    bool showFullToolbarActions,
  ) {
    final editor = PdfEditorView(
      key: ValueKey(
        '${document.source.id}-${identityHashCode(editing)}-'
        '${_activeSession?.viewerGeneration}',
      ),
      controller: editing,
      viewerController: _activeSession?.viewerController,
      documentId: document.source.id,
      features: PdfEditorFeatures(tools: _qpdfEditorTools),
      initialFit: _activeSession?.viewerFit ?? PdfViewerFit.page,
      pageLayout:
          _activeSession?.pageLayout ??
          const PdfPageLayout.verticalContinuous(),
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
      toolbarLeading: showFullToolbarActions
          ? [
              (context, editing, viewer) => FilledButton.icon(
                key: const Key('fill-and-sign-toolbar-button'),
                onPressed: () => unawaited(_showFillAndSign(editing)),
                icon: const Icon(Icons.draw_outlined),
                label: const Text('Fill & Sign'),
              ),
            ]
          : const [],
      toolbarTrailing: showFullToolbarActions
          ? [
              (context, editing, viewer) => FilledButton.icon(
                onPressed: _modified
                    ? () => unawaited(_save(editing.bytes))
                    : null,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save'),
              ),
            ]
          : const [],
    );
    final selected =
        _activeSession?.workspaceMode ?? DocumentWorkspaceMode.read;
    final workspace = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              DocumentModeRail(
                selected: selected,
                horizontal: false,
                onSelected: (mode) => _selectWorkspaceMode(mode, editing),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: editor),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: editor),
            const Divider(height: 1),
            DocumentModeRail(
              selected: selected,
              horizontal: true,
              onSelected: (mode) => _selectWorkspaceMode(mode, editing),
            ),
          ],
        );
      },
    );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.buttons & kSecondaryMouseButton != 0) {
          unawaited(_showWorkspaceContextMenu(editing, event.position));
        }
      },
      child: workspace,
    );
  }

  Future<void> _showWorkspaceContextMenu(
    PdfEditingController editing,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final action = await showMenu<_WorkspaceContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          key: Key('workspace-context-select'),
          value: _WorkspaceContextAction.select,
          child: ListTile(
            leading: Icon(Icons.near_me_outlined),
            title: Text('Select'),
          ),
        ),
        PopupMenuItem(
          key: Key('workspace-context-edit'),
          value: _WorkspaceContextAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit text or image'),
          ),
        ),
        PopupMenuItem(
          key: Key('workspace-context-comment'),
          value: _WorkspaceContextAction.comment,
          child: ListTile(
            leading: Icon(Icons.comment_outlined),
            title: Text('Add comment'),
          ),
        ),
        PopupMenuItem(
          value: _WorkspaceContextAction.fillAndSign,
          child: ListTile(
            leading: Icon(Icons.draw_outlined),
            title: Text('Fill & Sign'),
          ),
        ),
        PopupMenuItem(
          value: _WorkspaceContextAction.allTools,
          child: ListTile(
            leading: Icon(Icons.apps_outlined),
            title: Text('All tools…'),
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _WorkspaceContextAction.select:
        _selectWorkspaceMode(DocumentWorkspaceMode.read, editing);
      case _WorkspaceContextAction.edit:
        _selectWorkspaceMode(DocumentWorkspaceMode.edit, editing);
      case _WorkspaceContextAction.comment:
        _selectWorkspaceMode(DocumentWorkspaceMode.comment, editing);
      case _WorkspaceContextAction.fillAndSign:
        _selectWorkspaceMode(DocumentWorkspaceMode.fillAndSign, editing);
      case _WorkspaceContextAction.allTools:
        unawaited(_showDocumentTools(editing));
    }
  }

  void _setViewerFit(PdfViewerFit fit) {
    final session = _activeSession;
    if (session == null || session.viewerFit == fit) return;
    setState(() {
      session
        ..viewerFit = fit
        ..viewerGeneration = session.viewerGeneration + 1;
    });
  }

  void _setPageLayout(PdfPageLayout layout) {
    final session = _activeSession;
    if (session == null || session.pageLayout == layout) return;
    setState(() {
      session
        ..pageLayout = layout
        ..viewerGeneration = session.viewerGeneration + 1;
    });
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
    bind(LogicalKeyboardKey.keyK, _allToolsShortcut);
    bind(LogicalKeyboardKey.keyW, _closeTabShortcut);
    bind(LogicalKeyboardKey.keyZ, _undoShortcut);
    bind(LogicalKeyboardKey.keyZ, _redoShortcut, shift: true);
    bindings[const SingleActivator(
      LogicalKeyboardKey.tab,
      control: true,
    )] = () =>
        _nextTabShortcut(reverse: false);
    bindings[const SingleActivator(
      LogicalKeyboardKey.tab,
      control: true,
      shift: true,
    )] = () =>
        _nextTabShortcut(reverse: true);
    bindings[const SingleActivator(LogicalKeyboardKey.tab, meta: true)] = () =>
        _nextTabShortcut(reverse: false);
    bindings[const SingleActivator(
      LogicalKeyboardKey.tab,
      meta: true,
      shift: true,
    )] = () =>
        _nextTabShortcut(reverse: true);
    return bindings;
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return CallbackShortcuts(
      bindings: _buildShortcutBindings(),
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, appConstraints) {
            final windowWidth = appConstraints.maxWidth;
            return Scaffold(
              appBar: AppBar(
                titleSpacing: 20,
                title: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset(
                        'assets/branding/qpdf-icon-master.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        semanticLabel: 'QPdf',
                      ),
                    ),
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
                  if (document != null && windowWidth >= 700)
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
                  if (windowWidth >= 900)
                    if (_editingController case final editing?)
                      TextButton.icon(
                        key: const Key('edit-pdf-menu-button'),
                        onPressed: _busy
                            ? null
                            : () => unawaited(_showEditMenu(editing)),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('Edit'),
                      ),
                  if (windowWidth >= 700)
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
                                    : () => unawaited(
                                        _applySecureRedactions(editing),
                                      ),
                                icon: const Icon(Icons.security),
                              ),
                          ],
                        ),
                      ),
                  if (_editingController case final editing?)
                    IconButton(
                      key: const Key('document-tools-button'),
                      tooltip: 'All tools (⌘/Ctrl+K)',
                      onPressed: _busy
                          ? null
                          : () => unawaited(_showDocumentTools(editing)),
                      icon: const Icon(Icons.apps_outlined),
                    ),
                  if (windowWidth < 700)
                    if (_editingController case final editing?)
                      IconButton(
                        key: const Key('mobile-save-button'),
                        tooltip: 'Save',
                        onPressed: _busy || !_modified
                            ? null
                            : () => unawaited(_save(editing.bytes)),
                        icon: const Icon(Icons.save_alt),
                      ),
                  if (windowWidth >= 700)
                    IconButton(
                      key: const Key('open-pdf-button'),
                      tooltip: 'Open PDF',
                      onPressed: _busy ? null : _openDocument,
                      icon: const Icon(Icons.folder_open_outlined),
                    ),
                  if (windowWidth >= 700)
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
                bottom: windowWidth >= 700 && _sessions.length > 1
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(46),
                        child: _DocumentTabStrip(
                          sessions: _sessions,
                          activeIndex: _activeSessionIndex,
                          onSelected: _switchToSession,
                          onClosed: (index) => unawaited(_closeSession(index)),
                        ),
                      )
                    : null,
              ),
              body: DropTarget(
                enable: !kIsWeb,
                onDragEntered: (_) => setState(() => _draggingFiles = true),
                onDragExited: (_) => setState(() => _draggingFiles = false),
                onDragDone: (details) => unawaited(_openDroppedFiles(details)),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        if (windowWidth >= 900)
                          if (_editingController case final editing?)
                            ListenableBuilder(
                              listenable: editing,
                              builder: (context, _) => DocumentDesktopMenuBar(
                                canUndo: editing.canUndo,
                                canRedo: editing.canRedo,
                                canSave: _modified,
                                onOpen: _openShortcut,
                                onSave: _saveShortcut,
                                onSaveAs: _saveAsShortcut,
                                onPrint: _printShortcut,
                                onClose: _closeTabShortcut,
                                onUndo: _undoShortcut,
                                onRedo: _redoShortcut,
                                onFitPage: () =>
                                    _setViewerFit(PdfViewerFit.page),
                                onFitWidth: () =>
                                    _setViewerFit(PdfViewerFit.width),
                                onActualSize:
                                    _activeSession!.viewerController.resetZoom,
                                onVerticalLayout: () => _setPageLayout(
                                  const PdfPageLayout.verticalContinuous(),
                                ),
                                onHorizontalLayout: () => _setPageLayout(
                                  const PdfPageLayout.horizontalContinuous(),
                                ),
                                onRotateLeft: () => _activeSession!
                                    .viewerController
                                    .rotateView(-90),
                                onRotateRight: () => _activeSession!
                                    .viewerController
                                    .rotateView(90),
                                onAllTools: _allToolsShortcut,
                                onCommand: (command) =>
                                    _runDocumentCommand(command, editing),
                              ),
                            ),
                        Expanded(
                          child: Stack(
                            children: [
                              if (document == null)
                                _EmptyState(
                                  onOpen: _busy ? null : _openDocument,
                                  onFillAndSign: _busy
                                      ? null
                                      : () => _openDocument(
                                          startTool: PdfEditTool.select,
                                        ),
                                  onCreateFromImages: _busy
                                      ? null
                                      : _createFromImages,
                                  onMergePdfs: _busy ? null : _mergePdfs,
                                  onScanDocument:
                                      _busy || !isDocumentScannerSupported
                                      ? null
                                      : _scanDocument,
                                  recentDocuments: _recentDocuments,
                                  onOpenRecent: _busy ? null : _openRecent,
                                  onRecentAction: _busy
                                      ? null
                                      : (recent, action) => unawaited(
                                          _handleRecentAction(recent, action),
                                        ),
                                )
                              else
                                _buildDocumentWorkspace(
                                  context,
                                  document,
                                  _editingController!,
                                  windowWidth >= 700,
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
                      ],
                    ),
                    if (_draggingFiles)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            child: Center(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.file_download_outlined,
                                        size: 44,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Drop PDFs to open',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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
    for (final session in _sessions) {
      session.controller.dispose();
      session.viewerController.dispose();
    }
    unawaited(widget.recoveryService.dispose());
    super.dispose();
  }
}

final class _DocumentSession {
  _DocumentSession({
    required this.document,
    required this.controller,
    required this.password,
    required this.recoveryBaseSource,
  }) : modified = false,
       workspaceMode = DocumentWorkspaceMode.read,
       viewerController = PdfViewerController(),
       viewerFit = PdfViewerFit.page,
       pageLayout = const PdfPageLayout.verticalContinuous(),
       viewerGeneration = 0;

  PdfOpenedDocument document;
  PdfEditingController controller;
  String password;
  PdfDocumentSource recoveryBaseSource;
  bool modified;
  DocumentWorkspaceMode workspaceMode;
  final PdfViewerController viewerController;
  PdfViewerFit viewerFit;
  PdfPageLayout pageLayout;
  int viewerGeneration;
}

class _DocumentTabStrip extends StatelessWidget {
  const _DocumentTabStrip({
    required this.sessions,
    required this.activeIndex,
    required this.onSelected,
    required this.onClosed,
  });

  final List<_DocumentSession> sessions;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onClosed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: Material(
        color: colors.surfaceContainerLow,
        child: ListView.separated(
          key: const Key('document-tab-strip'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          itemCount: sessions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, index) {
            final session = sessions[index];
            final selected = index == activeIndex;
            return Material(
              color: selected ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                key: Key('document-tab-$index'),
                borderRadius: BorderRadius.circular(9),
                onTap: () => onSelected(index),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 150,
                    maxWidth: 260,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 17,
                          color: selected ? colors.primary : colors.outline,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '${session.document.source.displayName}'
                            '${session.modified ? ' *' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        IconButton(
                          key: Key('close-document-tab-$index'),
                          tooltip:
                              'Close ${session.document.source.displayName}',
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          onPressed: () => onClosed(index),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
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
    required this.onRecentAction,
  });

  final VoidCallback? onOpen;
  final VoidCallback? onFillAndSign;
  final VoidCallback? onCreateFromImages;
  final VoidCallback? onMergePdfs;
  final VoidCallback? onScanDocument;
  final List<RecentDocument> recentDocuments;
  final ValueChanged<RecentDocument>? onOpenRecent;
  final void Function(RecentDocument, _RecentAction)? onRecentAction;

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
                                        trailing: PopupMenuButton<_RecentAction>(
                                          key: Key(
                                            'recent-menu-${recentDocuments[i].id}',
                                          ),
                                          tooltip: 'Recent document actions',
                                          enabled: onRecentAction != null,
                                          onSelected: (action) =>
                                              onRecentAction?.call(
                                                recentDocuments[i],
                                                action,
                                              ),
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: recentDocuments[i].pinned
                                                  ? _RecentAction.unpin
                                                  : _RecentAction.pin,
                                              child: ListTile(
                                                leading: Icon(
                                                  recentDocuments[i].pinned
                                                      ? Icons.push_pin_outlined
                                                      : Icons.push_pin,
                                                ),
                                                title: Text(
                                                  recentDocuments[i].pinned
                                                      ? 'Unpin'
                                                      : 'Pin',
                                                ),
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: _RecentAction.reveal,
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.folder_open_outlined,
                                                ),
                                                title: Text('Show in folder'),
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: _RecentAction.remove,
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.remove_circle_outline,
                                                ),
                                                title: Text(
                                                  'Remove from recents',
                                                ),
                                              ),
                                            ),
                                          ],
                                          icon: Icon(
                                            recentDocuments[i].pinned
                                                ? Icons.push_pin
                                                : Icons.more_horiz,
                                            color: recentDocuments[i].pinned
                                                ? colors.primary
                                                : colors.onSurfaceVariant,
                                          ),
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
