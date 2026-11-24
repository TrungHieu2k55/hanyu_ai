import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import 'local_file_handoff.dart';

Future<FileHandoff> handoffJson(Uint8List bytes, String name) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: name),
        ],
        fileNameOverrides: [name],
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => FileHandoff.handedOff,
      ShareResultStatus.dismissed => FileHandoff.canceled,
      ShareResultStatus.unavailable => FileHandoff.unavailable,
    };
  }
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return FileHandoff.canceled;
  await File(location.path).writeAsBytes(bytes, flush: true);
  return FileHandoff.handedOff;
}
