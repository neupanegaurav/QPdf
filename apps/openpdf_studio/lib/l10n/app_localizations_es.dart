// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'QPdf';

  @override
  String get homeTitle => 'Inicio';

  @override
  String get homePrompt => '¿Qué te gustaría hacer?';

  @override
  String get recentDocuments => 'Documentos recientes';

  @override
  String get actionBrowse => 'Examinar';

  @override
  String get privacyFooter =>
      'Tus documentos se quedan contigo: privados y en el dispositivo.';

  @override
  String get actionFillAndSign => 'Rellenar y firmar';

  @override
  String get fillAndSignSubtitle => 'Completa formularios y añade tu firma';

  @override
  String get actionOpen => 'Abrir PDF';

  @override
  String get openSubtitle => 'Ver y editar';

  @override
  String get actionScanShort => 'Escanear';

  @override
  String get scanSubtitle => 'Usa tu cámara';

  @override
  String get photosTitle => 'Fotos';

  @override
  String get photosSubtitle => 'Crear un PDF';

  @override
  String get combineTitle => 'Combinar';

  @override
  String get actionMergePdfs => 'Combinar PDF';
}
