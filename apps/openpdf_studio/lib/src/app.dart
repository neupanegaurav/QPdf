import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf_domain/pdf_domain.dart';
import 'package:pdf_engine_api/pdf_engine_api.dart';

import '../l10n/app_localizations.dart';
import 'editor/editor_home.dart';
import 'services/document_file_service.dart';
import 'services/document_recovery_service.dart';
import 'services/recent_documents_service.dart';
import 'theme.dart';

class QPdfApp extends StatefulWidget {
  const QPdfApp({
    required this.engine,
    required this.fileService,
    required this.recoveryService,
    this.recentDocumentsService = const NoopRecentDocumentsService(),
    this.initialDocument,
    this.incomingDocuments = const Stream.empty(),
    super.key,
  });

  final PdfEngine engine;
  final DocumentFileService fileService;
  final DocumentRecoveryService recoveryService;
  final RecentDocumentsService recentDocumentsService;
  final PdfDocumentSource? initialDocument;
  final Stream<PdfDocumentSource> incomingDocuments;

  @override
  State<QPdfApp> createState() => _QPdfAppState();
}

class _QPdfAppState extends State<QPdfApp> {
  StreamSubscription<PdfDocumentSource>? _incomingSubscription;
  PdfDocumentSource? _currentInitialDocument;

  @override
  void initState() {
    super.initState();
    _currentInitialDocument = widget.initialDocument;
    _listenForIncomingDocuments();
  }

  @override
  void didUpdateWidget(covariant QPdfApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incomingDocuments != widget.incomingDocuments) {
      unawaited(_incomingSubscription?.cancel());
      _listenForIncomingDocuments();
    }
    if (oldWidget.initialDocument?.id != widget.initialDocument?.id) {
      _currentInitialDocument = widget.initialDocument;
    }
  }

  void _listenForIncomingDocuments() {
    _incomingSubscription = widget.incomingDocuments.listen((document) {
      if (!mounted) return;
      setState(() => _currentInitialDocument = document);
    });
  }

  @override
  void dispose() {
    unawaited(_incomingSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'QPdf',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: EditorHome(
        engine: widget.engine,
        fileService: widget.fileService,
        recoveryService: widget.recoveryService,
        recentDocumentsService: widget.recentDocumentsService,
        initialDocument: _currentInitialDocument,
      ),
    );
  }
}
