import 'dart:convert';
import 'dart:typed_data';

/// Practice content is versioned JSON; binary payloads are loaded separately.
enum PracticeKind { writing, photo, conversation }

class LocalPracticeEntry {
  LocalPracticeEntry({
    required this.id,
    required this.kind,
    required Map<String, dynamic> data,
    required this.createdAt,
    required this.updatedAt,
    this.done = false,
  }) : data = _freeze(jsonDecode(jsonEncode(data))) as Map<String, dynamic>;
  final String id;
  final PracticeKind kind;
  final Map<String, dynamic> data;
  final DateTime createdAt, updatedAt;
  final bool done;
  String get title => switch (kind) {
    PracticeKind.writing => '${data['character']} · luyện viết',
    PracticeKind.photo =>
      (data['text'] as String).isEmpty ? 'Ghi chú ảnh' : data['text'] as String,
    PracticeKind.conversation => data['title'] as String,
  };
  Set<String> get mediaIds => {
    if (data['imageId'] case final String id) id,
    if (data['draftAudioId'] case final String id) id,
    for (final t in (data['turns'] as List? ?? []))
      if ((t as Map)['audioId'] case final String id) id,
  };
  LocalPracticeEntry copy({Map<String, dynamic>? data, bool? done}) =>
      LocalPracticeEntry(
        id: id,
        kind: kind,
        data: data ?? this.data,
        createdAt: createdAt,
        updatedAt: updatedAt,
        done: done ?? this.done,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'data': data,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'done': done,
  };
  factory LocalPracticeEntry.fromJson(Map<String, dynamic> j) =>
      LocalPracticeEntry(
        id: j['id'] as String,
        kind: PracticeKind.values.byName(j['kind'] as String),
        data: j['data'] as Map<String, dynamic>,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        done: j['done'] as bool,
      );
}

class LocalMediaInput {
  LocalMediaInput({
    required this.id,
    required this.mime,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String id, mime;
  final Uint8List bytes;
}

class LocalMediaInfo {
  const LocalMediaInfo(
    this.id,
    this.mime,
    this.length,
    this.checksum,
    this.createdAt,
  );
  final String id, mime, checksum;
  final int length;
  final DateTime createdAt;
}

Object? _freeze(Object? value) => switch (value) {
  Map() => Map<String, dynamic>.unmodifiable({
    for (final e in value.entries) e.key as String: _freeze(e.value),
  }),
  List() => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};
