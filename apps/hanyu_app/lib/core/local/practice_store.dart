import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../features/practice/domain/local_practice.dart';
import 'local_database.dart';
import 'practice_validation.dart';

class PracticeStore {
  PracticeStore(this.db, this.clock);
  final LocalDatabase db;
  final DateTime Function() clock;
  Future<List<LocalPracticeEntry>> load() async => [
    for (final row in await (db.select(
      db.localPracticeEntries,
    )..orderBy([(r) => OrderingTerm.desc(r.updatedAt)])).get())
      LocalPracticeEntry(
        id: row.id,
        kind: PracticeKind.values.byName(row.kind),
        data: jsonDecode(row.dataJson) as Map<String, dynamic>,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        done: row.done,
      ),
  ];
  Future<List<LocalMediaInfo>> mediaInfo() async {
    // Never hydrate blobs into application snapshots or list screens.
    final rows = await db
        .customSelect(
          'SELECT id, mime, length(bytes) AS size, checksum, created_at FROM local_media',
        )
        .get();
    return [
      for (final row in rows)
        LocalMediaInfo(
          row.read<String>('id'),
          row.read<String>('mime'),
          row.read<int>('size'),
          row.read<String>('checksum'),
          DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('created_at') * 1000,
            isUtc: true,
          ),
        ),
    ];
  }

  Future<Uint8List?> readMedia(String id) async {
    final row = await (db.select(
      db.localMedia,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    if (sha256.convert(row.bytes).toString() != row.checksum) {
      practiceError('Ảnh/audio bị hỏng. Văn bản đã lưu vẫn còn.');
    }
    return row.bytes;
  }

  Future<void> clear() async {
    await db.delete(db.localPracticeEntries).go();
    await db.delete(db.localMedia).go();
  }

  Future<void> putMedia(LocalMediaInput m) async {
    validateMedia(m);
    final existing = await (db.select(
      db.localMedia,
    )..where((r) => r.id.equals(m.id))).getSingleOrNull();
    final hash = sha256.convert(m.bytes).toString();
    if (existing != null) {
      if (existing.checksum != hash || existing.mime != m.mime) {
        practiceError('ID tệp đã dùng cho nội dung khác.');
      }
      return;
    }
    final usage = await db
        .customSelect(
          'SELECT COALESCE(SUM(length(bytes)),0) AS total, COUNT(*) AS files FROM local_media',
        )
        .getSingle();
    final total = usage.read<int>('total');
    if (usage.read<int>('files') >= maxMediaEntries) {
      practiceError(
        'Tối đa 1.000 tệp ảnh/audio. Xóa nội dung không cần sau khi xuất backup.',
      );
    }
    if (total + m.bytes.length > mediaBudget) {
      practiceError(
        'Ảnh/audio đã đạt giới hạn 50 MiB. Hãy xuất backup hoặc bỏ tệp không cần.',
      );
    }
    await db
        .into(db.localMedia)
        .insert(
          LocalMediaCompanion.insert(
            id: m.id,
            mime: m.mime,
            bytes: m.bytes,
            checksum: hash,
            createdAt: clock().toUtc(),
          ),
        );
  }

  Future<void> _write(LocalPracticeEntry entry) async {
    validatePractice(entry);
    final media = {for (final m in await mediaInfo()) m.id: m};
    for (final id in entry.mediaIds) {
      final m = media[id];
      if (m == null ||
          (entry.kind == PracticeKind.photo
              ? !m.mime.startsWith('image/')
              : m.mime != 'audio/wav')) {
        practiceError('Ảnh/audio được tham chiếu không tồn tại hoặc sai loại.');
      }
    }
    await db
        .into(db.localPracticeEntries)
        .insertOnConflictUpdate(
          LocalPracticeEntriesCompanion.insert(
            id: entry.id,
            kind: entry.kind.name,
            dataJson: jsonEncode(entry.data),
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            done: Value(entry.done),
          ),
        );
  }

  Future<void> save(
    LocalPracticeEntry input,
    List<LocalMediaInput> media,
  ) async {
    final entries = await load();
    final old = entries.where((e) => e.id == input.id).firstOrNull;
    if (old == null && entries.length >= maxPracticeEntries) {
      practiceError('Tối đa 10.000 bản thực hành trên thiết bị.');
    }
    if (old != null && (old.done || old.kind != input.kind)) {
      practiceError('Lượt đã hoàn thành không sửa được. Hãy tạo lượt mới.');
    }
    if (input.kind == PracticeKind.conversation &&
        jsonEncode(input.data['turns']) !=
            jsonEncode(old?.data['turns'] ?? [])) {
      practiceError('Lượt nói chỉ được thêm qua bước xác nhận.');
    }
    if (old != null &&
        input.kind == PracticeKind.photo &&
        old.data['original'] != input.data['original']) {
      practiceError('Bản chữ đầu tiên được giữ nguyên.');
    }
    if (media.any((m) => !input.mediaIds.contains(m.id))) {
      practiceError('Tệp phải thuộc nội dung đang lưu.');
    }
    for (final m in media) {
      await putMedia(m);
    }
    final now = clock().toUtc();
    await _write(
      LocalPracticeEntry(
        id: input.id,
        kind: input.kind,
        data: input.data,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        done: input.done,
      ),
    );
    await prune();
  }

  Future<void> confirmTurn(String id) async {
    final e = (await load()).where((e) => e.id == id).firstOrNull;
    if (e == null || e.kind != PracticeKind.conversation || e.done) {
      practiceError('Phiên không còn mở.');
    }
    final turns = List<Map<String, dynamic>>.from(e.data['turns'] as List);
    final text = (e.data['draft'] as String).trim();
    if (text.isEmpty || turns.length >= 8) {
      practiceError('Cần bản chữ tự nhập, tối đa tám lượt.');
    }
    turns.add({
      'text': text,
      'audioId': e.data['draftAudioId'],
      'at': clock().toUtc().toIso8601String(),
    });
    await _write(
      LocalPracticeEntry(
        id: e.id,
        kind: e.kind,
        createdAt: e.createdAt,
        updatedAt: clock().toUtc(),
        done: turns.length == 8,
        data: {...e.data, 'draft': '', 'draftAudioId': null, 'turns': turns},
      ),
    );
  }

  Future<void> delete(String id) async {
    await (db.delete(
      db.localPracticeEntries,
    )..where((e) => e.id.equals(id))).go();
    await prune();
  }

  Future<void> prune() async {
    final refs = {for (final e in await load()) ...e.mediaIds};
    for (final m in await mediaInfo()) {
      if (!refs.contains(m.id)) {
        await (db.delete(db.localMedia)..where((r) => r.id.equals(m.id))).go();
      }
    }
  }

  Future<void> restore(List raw, List<LocalMediaInput> media) =>
      applyRestore(preparePracticeRestore(raw, media));

  Future<void> applyRestore(PreparedPracticeRestore prepared) async {
    await db.batch((b) {
      b.insertAll(db.localMedia, [
        for (final m in prepared.media)
          LocalMediaCompanion.insert(
            id: m.id,
            mime: m.mime,
            bytes: m.bytes,
            checksum: sha256.convert(m.bytes).toString(),
            createdAt: clock().toUtc(),
          ),
      ]);
      b.insertAll(db.localPracticeEntries, [
        for (final e in prepared.entries)
          LocalPracticeEntriesCompanion.insert(
            id: e.id,
            kind: e.kind.name,
            dataJson: jsonEncode(e.data),
            createdAt: e.createdAt,
            updatedAt: e.updatedAt,
            done: Value(e.done),
          ),
      ]);
    });
  }
}
