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
  String get homeTitle => 'Home';

  @override
  String get homePrompt => 'What would you like to do?';

  @override
  String get recentDocuments => 'Recent documents';

  @override
  String get actionBrowse => 'Browse';

  @override
  String get privacyFooter =>
      'Your documents stay with you — private and on-device.';

  @override
  String get actionFillAndSign => 'Fill & Sign';

  @override
  String get fillAndSignSubtitle => 'Complete forms and add your signature';

  @override
  String get actionOpen => 'Open PDF';

  @override
  String get openSubtitle => 'View and edit';

  @override
  String get actionScanShort => 'Scan';

  @override
  String get scanSubtitle => 'Use your camera';

  @override
  String get photosTitle => 'Photos';

  @override
  String get photosSubtitle => 'Create a PDF';

  @override
  String get combineTitle => 'Combine';

  @override
  String get actionMergePdfs => 'Merge PDFs';
}
