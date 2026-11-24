import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/files/canonical_json.dart';
import '../../../core/local/local_database.dart';
import '../../../core/local/local_models.dart';
import '../../roleplay/data/sample_scenarios.dart';
import '../domain/content_payload.dart';
import '../domain/content_revision.dart';

/// Typed content operations, called only within the Admin commit transaction.
class AdminContentStore {
  AdminContentStore(this.db, this.clock);
  final LocalDatabase db;
  final DateTime Function() clock;
  Future<String?> meta(String key) async => (await (db.select(
    db.localMetadata,
  )..where((r) => r.key.equals(key))).getSingleOrNull())?.value;
  Future<void> setMeta(String key, String value) => db
      .into(db.localMetadata)
      .insertOnConflictUpdate(
        LocalMetadataCompanion.insert(key: key, value: value),
      );
  Future<void> initialize() async {
    if (await meta('adminIdentity') == null) {
      await setMeta(
        'adminIdentity',
        canonicalJson(AdminIdentity(publisherId: const Uuid().v4()).toJson()),
      );
    }
  }

  Future<AdminIdentity> identity() async => AdminIdentity.fromJson(
    jsonDecode((await meta('adminIdentity'))!) as Map<String, dynamic>,
  );
  Future<void> saveLabel(String label) async => setMeta(
    'adminIdentity',
    canonicalJson(
      AdminIdentity(
        publisherId: (await identity()).publisherId,
        label: label,
      ).toJson(),
    ),
  );
  ContentRevision _parse(LocalAdminRevision row) => ContentRevision.fromJson({
    ...jsonDecode(row.dataJson) as Map<String, dynamic>,
    'state': row.state,
    'exported': row.exported,
  });
  Future<List<ContentRevision>> load() async =>
      (await (db.select(db.localAdminRevisions)..orderBy([
                (r) => OrderingTerm.desc(r.revision),
                (r) => OrderingTerm.asc(r.itemId),
              ]))
              .get())
          .map(_parse)
          .toList();
  Future<ContentRevision?> latest(String id) async {
    final row =
        await (db.select(db.localAdminRevisions)
              ..where((r) => r.itemId.equals(id))
              ..orderBy([(r) => OrderingTerm.desc(r.revision)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _parse(row);
  }

  Future<ContentRevision> read(String id, int revision) async {
    final row =
        await (db.select(db.localAdminRevisions)
              ..where((r) => r.itemId.equals(id) & r.revision.equals(revision)))
            .getSingleOrNull();
    if (row == null) {
      throw const LocalDataException('Không tìm thấy phiên bản học liệu.');
    }
    return _parse(row);
  }

  Future<void> _put(ContentRevision record) => db
      .into(db.localAdminRevisions)
      .insertOnConflictUpdate(
        LocalAdminRevisionsCompanion.insert(
          itemId: record.itemId,
          revision: record.revision,
          kind: record.kind.name,
          dataJson: canonicalJson(record.toJson()),
          state: record.state.name,
          exported: Value(record.exported),
        ),
      );

  Future<void> save({
    required String id,
    required int baseRevision,
    required ContentPayload payload,
    String source = '',
    String license = '',
  }) async {
    final old = await latest(id);
    if ((old == null && baseRevision != 0) ||
        (old != null && old.revision != baseRevision)) {
      throw const LocalConflict();
    }
    final kind = await meta('content-kind:$id');
    if ((old != null && old.kind != payload.kind) ||
        (kind != null && kind != payload.kind.name)) {
      throw const LocalDataException(
        'Không được đổi loại học liệu của cùng một mã.',
      );
    }
    if (old != null &&
        canonicalJson(old.payload.toJson()) ==
            canonicalJson(payload.toJson()) &&
        old.source == source.trim() &&
        old.license == license.trim()) {
      return;
    }
    final max = int.tryParse(await meta('content-max:$id') ?? '0') ?? 0;
    final next = (max > (old?.revision ?? 0) ? max : (old?.revision ?? 0)) + 1;
    final record = ContentRevision(
      itemId: id,
      revision: next,
      payload: payload,
      source: source,
      license: license,
      createdAt: clock(),
    );
    final count = await db
        .customSelect('SELECT COUNT(*) AS n FROM local_admin_revisions')
        .getSingle();
    if (count.read<int>('n') >= 10000) {
      throw const LocalDataException(
        'Đã đạt giới hạn 10.000 phiên bản học liệu.',
      );
    }
    await _put(record);
    await setMeta('content-max:$id', '$next');
    await setMeta('content-kind:$id', payload.kind.name);
  }

  Future<void> _requireLatest(String id, int revision) async {
    if ((await latest(id))?.revision != revision) {
      throw const LocalDataException(
        'Chọn phiên bản mới nhất để thực hiện thao tác này.',
      );
    }
  }

  Future<void> review(
    String id,
    int revision,
    String reviewerName,
    String note,
  ) async {
    await _requireLatest(id, revision);
    final old = await read(id, revision);
    if (old.state == ContentState.reviewed &&
        old.review.reviewerName == reviewerName.trim() &&
        old.review.note == note.trim()) {
      return;
    }
    if (old.state != ContentState.draft) {
      throw const LocalDataException(
        'Tạo bản nháp mới để thay khai báo duyệt.',
      );
    }
    final claim = ReviewClaim.declare(
      reviewerName: reviewerName,
      reviewedRevision: revision,
      reviewedAt: clock(),
      note: note,
    );
    await _put(old.withState(ContentState.reviewed, claim: claim));
  }

  Future<void> publish(String id, int revision) async {
    await _requireLatest(id, revision);
    final old = await read(id, revision);
    if (old.state == ContentState.published) return;
    if (old.state != ContentState.reviewed) {
      throw const LocalDataException(
        'Cần khai báo duyệt và nguồn/quyền sử dụng trước khi công bố.',
      );
    }
    final existing =
        await (db.select(db.localAdminRevisions)..where(
              (r) =>
                  r.itemId.equals(id) &
                  r.state.equals(ContentState.published.name),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await _put(_parse(existing).withState(ContentState.superseded));
    }
    await _put(old.withState(ContentState.published));
  }

  Future<void> withdraw(String id, int revision) async {
    final old = await read(id, revision);
    if (old.state == ContentState.withdrawn) return;
    if (old.state != ContentState.published) {
      throw const LocalDataException('Chỉ thu hồi phiên bản đang công bố.');
    }
    await _put(old.withState(ContentState.withdrawn));
  }

  Future<void> delete(String id, int revision) async {
    await _requireLatest(id, revision);
    final old = await read(id, revision);
    if (old.state != ContentState.draft || old.exported) {
      throw const LocalDataException(
        'Chỉ xóa nháp mới nhất chưa được pin vào gói xuất.',
      );
    }
    await (db.delete(
      db.localAdminRevisions,
    )..where((r) => r.itemId.equals(id) & r.revision.equals(revision))).go();
    // Keep allocation/kind tombstones: deleted numbers must never be reused.
  }

  Future<List<String>> insertCsvDrafts(List<VocabularyContent> values) async {
    if (values.isEmpty || values.length > 1000) {
      throw const LocalDataException('CSV cần 1–1.000 từ hợp lệ.');
    }
    final count = await db
        .customSelect('SELECT COUNT(*) AS n FROM local_admin_revisions')
        .getSingle();
    if (count.read<int>('n') + values.length > 10000) {
      throw const LocalDataException(
        'Lần nhập vượt giới hạn 10.000 phiên bản học liệu.',
      );
    }
    final now = clock();
    final records = [
      for (final value in values)
        ContentRevision(
          itemId: const Uuid().v4(),
          revision: 1,
          payload: value,
          createdAt: now,
        ),
    ];
    await db.batch((b) {
      b.insertAll(db.localAdminRevisions, [
        for (final record in records)
          LocalAdminRevisionsCompanion.insert(
            itemId: record.itemId,
            revision: 1,
            kind: record.kind.name,
            dataJson: canonicalJson(record.toJson()),
            state: ContentState.draft.name,
          ),
      ]);
      b.insertAll(db.localMetadata, [
        for (final record in records) ...[
          LocalMetadataCompanion.insert(
            key: 'content-max:${record.itemId}',
            value: '1',
          ),
          LocalMetadataCompanion.insert(
            key: 'content-kind:${record.itemId}',
            value: ContentKind.vocabulary.name,
          ),
        ],
      ]);
    });
    return records.map((r) => r.itemId).toList();
  }

  Future<void> samples() async {
    if (await meta('admin-sample-v1') != null) return;
    final contents = <ContentPayload>[
      VocabularyContent(
        hanzi: '朋友',
        pinyin: 'péngyou',
        vietnamese: 'bạn',
        targetLevel: 1,
      ),
      QuestionContent(
        targetLevel: 1,
        section: 'reading',
        slot: 1,
        prompt: '“你好” có nghĩa là gì?',
        choices: ['Xin chào', 'Tạm biệt', 'Cảm ơn', 'Xin lỗi'],
        correctIndex: 0,
        explanation:
            '你好 là lời chào. Ví dụ nháp chưa được người duyệt xác nhận.',
      ),
      for (final s in sampleScenarios)
        ScenarioContent(
          key: s.id,
          role: s.role,
          partner: s.partner,
          goal: s.goal,
          opening: s.opening,
          sampleReply: s.reply,
          suggestion: s.suggestion,
        ),
    ];
    for (final payload in contents) {
      await save(
        id: const Uuid().v4(),
        baseRevision: 0,
        payload: payload,
        source: 'Ví dụ do nhóm dự án soạn; chưa được kiểm duyệt.',
      );
    }
    await setMeta('admin-sample-v1', 'loaded');
  }
}
