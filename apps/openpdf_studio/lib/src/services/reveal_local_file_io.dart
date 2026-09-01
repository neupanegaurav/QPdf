import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

Future<bool> revealLocalFile(String path) {
  final directory = File(path).parent.uri;
  return launchUrl(directory, mode: LaunchMode.externalApplication);
}
