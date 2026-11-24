import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> saveArchiveFile(Uint8List bytes) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/zip',
            name: 'hanyu-local-backup.zip',
          ),
        ],
        fileNameOverrides: ['hanyu-local-backup.zip'],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
  final location = await getSaveLocation(
    suggestedName: 'hanyu-local-backup.zip',
  );
  if (location == null) return false;
  await File(location.path).writeAsBytes(bytes, flush: true);
  return true;
}
