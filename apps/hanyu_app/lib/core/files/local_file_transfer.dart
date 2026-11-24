import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../local/local_models.dart';
import 'local_file_transfer_platform.dart' as platform;
export 'local_file_handoff.dart';
import 'local_file_handoff.dart';

enum LocalJsonKind {
  feedback(64 * 1024),
  contentPackage(2 * 1024 * 1024),
  adminBackup(10 * 1024 * 1024);

  const LocalJsonKind(this.maxBytes);
  final int maxBytes;
}

/// Validated UTF-8 JSON bytes. An envelope/domain validator still owns semantics.
class LocalJsonFile {
  LocalJsonFile._(this.name, Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  factory LocalJsonFile.fromBytes(
    Uint8List bytes, {
    required String name,
    required LocalJsonKind kind,
  }) {
    if (bytes.isEmpty || bytes.length > kind.maxBytes) {
      throw const LocalDataException('Tệp rỗng hoặc vượt dung lượng cho phép.');
    }
    if (name.runes.length > 120 ||
        !name.toLowerCase().endsWith('.json') ||
        RegExp(r'[\x00-\x1f/\\]').hasMatch(name)) {
      throw const LocalDataException('Tên tệp JSON không hợp lệ.');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
    } on FormatException {
      throw const LocalDataException(
        'Tệp phải là đối tượng JSON UTF-8 hợp lệ.',
      );
    }
    return LocalJsonFile._(name, bytes);
  }

  final String name;
  final Uint8List bytes;
  static const mime = 'application/json';
  String get text => utf8.decode(bytes);
}

abstract interface class LocalFileTransfer {
  Future<LocalJsonFile?> pick(LocalJsonKind kind);
  Future<FileHandoff> save(LocalJsonFile file);
}

/// Injectable OS boundary: widgets and repositories never call picker/share APIs.
class DeviceLocalFileTransfer implements LocalFileTransfer {
  DeviceLocalFileTransfer({
    Future<XFile?> Function()? picker,
    Future<FileHandoff> Function(LocalJsonFile)? handoff,
  }) : _picker = picker ?? _pickJson,
       _handoff =
           handoff ?? ((file) => platform.handoffJson(file.bytes, file.name));

  final Future<XFile?> Function() _picker;
  final Future<FileHandoff> Function(LocalJsonFile) _handoff;

  static Future<XFile?> _pickJson() => openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'Hanyu JSON',
        extensions: ['json'],
        mimeTypes: [LocalJsonFile.mime],
        uniformTypeIdentifiers: ['public.json'],
      ),
    ],
  );

  @override
  Future<LocalJsonFile?> pick(LocalJsonKind kind) async {
    final file = await _picker();
    if (file == null) return null;
    if (await file.length() > kind.maxBytes) {
      throw const LocalDataException('Tệp vượt dung lượng cho phép.');
    }
    // Recheck after reading: a picker length is not trusted as a validation bound.
    return LocalJsonFile.fromBytes(
      await file.readAsBytes(),
      name: file.name,
      kind: kind,
    );
  }

  @override
  Future<FileHandoff> save(LocalJsonFile file) => _handoff(file);
}
