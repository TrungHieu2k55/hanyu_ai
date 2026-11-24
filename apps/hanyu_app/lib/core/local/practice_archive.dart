import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../features/practice/domain/local_practice.dart';
import 'practice_validation.dart';

class DecodedPracticeArchive {
  const DecodedPracticeArchive(this.data, this.media);
  final Map<String, dynamic> data;
  final List<LocalMediaInput> media;
}

class PracticeArchive {
  static Uint8List encode(
    Map<String, dynamic> data,
    List<LocalMediaInput> media,
  ) {
    final json = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    if (json.length > 10 * 1024 * 1024) {
      practiceError('Dữ liệu JSON vượt 10 MiB.');
    }
    final entries = <String, Uint8List>{
      'data.json': json,
      for (final m in media) 'media/${m.id}': m.bytes,
    };
    final manifest = {
      'format': 'hanyu-local-archive',
      'version': data['version'],
      'files': [
        for (final e in entries.entries)
          {
            'path': e.key,
            'length': e.value.length,
            'sha256': sha256.convert(e.value).toString(),
            if (e.key.startsWith('media/'))
              'mime': media.firstWhere((m) => 'media/${m.id}' == e.key).mime,
          },
      ],
    };
    entries['manifest.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest)),
    );
    if (entries.values.fold<int>(0, (n, b) => n + b.length) > backupBudget) {
      practiceError('Backup vượt 60 MiB.');
    }
    final a = Archive();
    for (final e in entries.entries) {
      a.add(ArchiveFile(e.key, e.value.length, e.value));
    }
    final bytes = ZipEncoder().encode(a);
    if (bytes.length > backupBudget) practiceError('Backup vượt 60 MiB.');
    return Uint8List.fromList(bytes);
  }

  static DecodedPracticeArchive decode(Uint8List bytes) {
    if (bytes.length > backupBudget) practiceError('Backup vượt 60 MiB.');
    final names = <String>{};
    var sum = 0, count = 0;
    // Inspect headers before any decompression, rejecting duplicate names here
    // because Archive itself intentionally collapses duplicates.
    final directory = ZipDirectory();
    for (final h in directory.headers(
      InputMemoryStream(bytes),
      verify: true,
      files: false,
    )) {
      final name = h.filename;
      if (++count > 1002 ||
          !names.add(name) ||
          !(name == 'manifest.json' ||
              name == 'data.json' ||
              RegExp(r'^media/[a-zA-Z0-9:_-]{1,100}$').hasMatch(name)) ||
          h.generalPurposeBitFlag & 1 != 0 ||
          (h.externalFileAttributes >> 16) & 0xf000 == 0xa000) {
        practiceError(
          'ZIP có tên trùng, đường dẫn hoặc loại tệp không hợp lệ.',
        );
      }
      sum += h.uncompressedSize;
      if (sum > backupBudget ||
          h.uncompressedSize >
              (name.startsWith('media/')
                  ? 5 * 1024 * 1024
                  : 10 * 1024 * 1024)) {
        practiceError('Dữ liệu giải nén vượt giới hạn.');
      }
    }
    if (!names.containsAll(['manifest.json', 'data.json'])) {
      practiceError('ZIP thiếu manifest hoặc dữ liệu.');
    }
    final a = ZipDecoder().decodeBytes(bytes, verify: true, throwOnError: true);
    final files = <String, Uint8List>{};
    for (final f in a) {
      if (!f.isFile || f.isSymbolicLink) {
        practiceError('ZIP chứa mục không hợp lệ.');
      }
      files[f.name] = f.readBytes()!;
    }
    final manifest = jsonDecode(
      utf8.decode(files['manifest.json']!),
    ) as Map<String, dynamic>;
    if (manifest['format'] != 'hanyu-local-archive' ||
        (manifest['version'] is! int ||
            ![4, 5].contains(manifest['version'])) ||
        manifest['files'] is! List) {
      practiceError('Manifest không hợp lệ.');
    }
    final declared = <String>{};
    final media = <LocalMediaInput>[];
    for (final raw in manifest['files'] as List) {
      final entry = raw as Map<String, dynamic>,
          path = entry['path'] as String,
          b = files[path];
      if (!declared.add(path) ||
          path == 'manifest.json' ||
          b == null ||
          b.length != entry['length'] ||
          sha256.convert(b).toString() != entry['sha256']) {
        practiceError('Tệp thiếu hoặc checksum sai.');
      }
      if (path.startsWith('media/')) {
        media.add(
          LocalMediaInput(
            id: path.substring(6),
            mime: entry['mime'] as String,
            bytes: b,
          ),
        );
      }
    }
    if (declared.length != files.length - 1 ||
        !declared.contains('data.json')) {
      practiceError('Danh sách tệp không khớp manifest.');
    }
    final data =
        jsonDecode(utf8.decode(files['data.json']!)) as Map<String, dynamic>;
    if (data['version'] is! int || data['version'] != manifest['version']) {
      practiceError('Phiên bản dữ liệu và manifest không khớp.');
    }
    return DecodedPracticeArchive(data, media);
  }
}
