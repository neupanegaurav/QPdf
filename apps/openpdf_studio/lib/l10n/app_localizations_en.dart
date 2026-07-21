// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'QPdf';

  @override
  String get actionOpen => 'Open PDF';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaveCopy => 'Save a copy';

  @override
  String get actionFillAndSign => 'Fill & Sign';

  @override
  String get actionMergePdfs => 'Merge PDFs';

  @override
  String get actionImagesToPdf => 'Images to PDF';

  @override
  String get actionScan => 'Scan document';

  @override
  String get recentDocuments => 'Recent documents';
}
