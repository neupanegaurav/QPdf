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
  String get actionOpen => 'Abrir PDF';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionSaveCopy => 'Guardar una copia';

  @override
  String get actionFillAndSign => 'Rellenar y firmar';

  @override
  String get actionMergePdfs => 'Combinar PDF';

  @override
  String get actionImagesToPdf => 'Imágenes a PDF';

  @override
  String get actionScan => 'Escanear documento';

  @override
  String get recentDocuments => 'Documentos recientes';
}
