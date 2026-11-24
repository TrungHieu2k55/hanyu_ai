import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'local_file_handoff.dart';

Future<FileHandoff> handoffJson(Uint8List bytes, String name) async {
  await XFile.fromData(
    bytes,
    mimeType: 'application/json',
    name: name,
  ).saveTo(name);
  return FileHandoff.handedOff;
}
