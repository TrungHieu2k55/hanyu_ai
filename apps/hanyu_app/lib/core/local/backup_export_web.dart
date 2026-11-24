import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<bool> saveArchiveFile(Uint8List bytes) async {
  await XFile.fromData(
    bytes,
    mimeType: 'application/zip',
    name: 'hanyu-local-backup.zip',
  ).saveTo('hanyu-local-backup.zip');
  return true;
}
