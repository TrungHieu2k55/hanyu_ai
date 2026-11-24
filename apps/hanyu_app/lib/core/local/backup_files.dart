import 'backup_export.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';

import 'local_models.dart';

abstract interface class BackupFiles {
  Future<bool> save(String content);
  Future<bool> saveArchive(Uint8List bytes);
  Future<Uint8List?> pickArchive();
  Future<String?> pick();
}

class LocalBackupFiles implements BackupFiles {
  const LocalBackupFiles();
  @override
  Future<bool> saveArchive(Uint8List bytes) => saveArchiveFile(bytes);
  @override
  Future<Uint8List?> pickArchive() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Hanyu ZIP / JSON',
          extensions: ['zip', 'json'],
          mimeTypes: ['application/zip', 'application/json'],
          uniformTypeIdentifiers: ['public.zip-archive', 'public.json'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 60 * 1024 * 1024) {
      throw const LocalDataException('Backup vượt 60 MiB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 60 * 1024 * 1024) {
      throw const LocalDataException('Backup vượt 60 MiB.');
    }
    return bytes;
  }

  @override
  Future<bool> save(String content) async {
    const name = 'hanyu-local-backup.json';
    String path = name;
    if (!kIsWeb) {
      final location = await getSaveLocation(suggestedName: name);
      if (location == null) return false;
      path = location.path;
    }
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      mimeType: 'application/json',
      name: name,
    ).saveTo(path);
    return true;
  }

  @override
  Future<String?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Hanyu backup',
          extensions: ['json'],
          mimeTypes: ['application/json'],
          uniformTypeIdentifiers: ['public.json'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 10 * 1024 * 1024) {
      throw const LocalDataException('Backup vượt giới hạn 10 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw const LocalDataException('Backup vượt giới hạn 10 MB.');
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      throw const LocalDataException('Backup không phải UTF-8 hợp lệ.');
    }
  }
}
