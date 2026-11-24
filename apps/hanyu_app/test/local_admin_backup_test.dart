import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/core/files/canonical_json.dart';
import 'package:doanchuyennganh2/core/files/local_file_transfer.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/admin/domain/local_admin.dart';
import 'package:doanchuyennganh2/features/support/domain/local_feedback.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late LocalAdminRepository source, target;
  setUp(() {
    source = LocalAdminRepository(LocalDatabase(NativeDatabase.memory()));
    target = LocalAdminRepository(LocalDatabase(NativeDatabase.memory()));
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });
  test('Admin backup preserves identity/reviews/inbox/receipts and byte-identical exports', () async {
    var s = await source.loadSnapshot();
    final id = const Uuid().v4();
    s = await source.saveRevision(
      id: id,
      baseRevision: 0,
      payload: VocabularyContent(
        hanzi: '人',
        pinyin: 'rén',
        vietnamese: 'người',
      ),
      source: 'Tự soạn',
      license: 'Dùng trong đồ án',
      revision: s.revision,
      operationId: 'content',
    );
    s = await source.recordReview(
      id,
      1,
      reviewerName: 'A',
      note: 'Đã đối chiếu',
      revision: s.revision,
      operationId: 'review',
    );
    s = await source.publishRevision(
      id,
      1,
      revision: s.revision,
      operationId: 'publish',
    );
    final record = s.content.single.toJson()
      ..remove('exported')
      ..remove('createdAt');
    final packageId = const Uuid().v4();
    final payload = {
      'format': 'hanyu-content-package',
      'formatVersion': 1,
      'publisherId': s.identity.publisherId,
      'packageId': packageId,
      'version': 1,
      'mode': 'reviewed',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'records': [record],
    };
    final checksum = canonicalChecksum(payload),
        bytes = utf8.encode(
          canonicalJson({...payload, 'checksum': canonicalChecksum(payload)}),
        );
    await source.db.customStatement(
      'UPDATE local_admin_revisions SET exported=1 WHERE item_id=?',
      [id],
    );
    await source.db.customStatement(
      'INSERT INTO local_admin_packages (package_id,version,bytes,checksum) VALUES (?,?,?,?)',
      [packageId, 1, bytes, checksum],
    );
    final now = DateTime.now().toUtc();
    final report = FeedbackReport.create(
      id: const Uuid().v4(),
      revision: 1,
      body: 'Cần kiểm tra',
      createdAt: now,
      updatedAt: now,
      state: FeedbackState.recorded,
    );
    s = await source.importFeedback(
      report,
      revision: s.revision,
      operationId: 'inbox',
    );
    s = await source.updateInbox(
      report.id,
      1,
      InboxStatus.closed,
      resolution: 'Đã xem',
      actorLabel: 'A',
      revision: s.revision,
      operationId: 'close',
    );
    final backup = await source.exportBackup();
    final before = await target.loadSnapshot();
    final prepared = target.prepareBackupRestore(backup);
    expect((await target.loadSnapshot()).content, isEmpty);
    final after = await target.restoreBackup(
      prepared,
      revision: before.revision,
      operationId: 'restore',
    );
    expect(after.identity.publisherId, s.identity.publisherId);
    expect(after.content.single.review.reviewerName, 'A');
    expect(after.content.single.exported, true);
    expect(after.inbox.single.receipt!.resolution, 'Đã xem');
    expect(
      (await target.db.select(target.db.localAdminPackages).get()).single.bytes,
      orderedEquals(bytes),
    );
    expect(await target.db.select(target.db.localWords).get(), isEmpty);
    expect(
      (await target.restoreBackup(
        prepared,
        revision: before.revision,
        operationId: 'restore',
      )).revision,
      after.revision,
    );
  });
  test('wrong format/tamper and duplicate published records fail preflight without deletion', () async {
    var s = await source.loadSnapshot();
    s = await source.seedSamples(revision: s.revision, operationId: 'samples');
    final backup = await source.exportBackup();
    final j = jsonDecode(backup.text) as Map<String, dynamic>;
    j['format'] = 'hanyu-local';
    expect(
      () => target.prepareBackupRestore(
        LocalJsonFile.fromBytes(
          utf8.encode(jsonEncode(j)),
          name: 'wrong.json',
          kind: LocalJsonKind.adminBackup,
        ),
      ),
      throwsA(isA<LocalDataException>()),
    );
    final before = await target.loadSnapshot();
    expect(
      (await target.loadSnapshot()).identity.publisherId,
      before.identity.publisherId,
    );
    expect((await target.loadSnapshot()).content, isEmpty);
  });
  test(
    'restore SQL failure rolls back old data and permits same operation retry',
    () async {
      var s = await source.loadSnapshot();
      s = await source.seedSamples(
        revision: s.revision,
        operationId: 'samples',
      );
      final prepared = target.prepareBackupRestore(await source.exportBackup());
      var current = await target.loadSnapshot();
      current = await target.saveIdentityLabel(
        'Không được mất',
        revision: current.revision,
        operationId: 'label',
      );
      final identity = current.identity.publisherId;
      await target.db.customStatement(
        "CREATE TRIGGER fail_restore BEFORE INSERT ON local_admin_revisions BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await expectLater(
        target.restoreBackup(
          prepared,
          revision: current.revision,
          operationId: 'restore',
        ),
        throwsA(anything),
      );
      final intact = await target.loadSnapshot();
      expect(intact.identity.publisherId, identity);
      expect(intact.identity.label, 'Không được mất');
      expect(intact.revision, current.revision);
      await target.db.customStatement('DROP TRIGGER fail_restore');
      final restored = await target.restoreBackup(
        prepared,
        revision: current.revision,
        operationId: 'restore',
      );
      expect(restored.content, hasLength(6));
    },
  );
  test(
    'valid-checksum backup with two published revisions is rejected before SQL',
    () async {
      var s = await source.loadSnapshot();
      final id = const Uuid().v4();
      s = await source.saveRevision(
        id: id,
        baseRevision: 0,
        payload: VocabularyContent(
          hanzi: '人',
          pinyin: 'rén',
          vietnamese: 'người',
        ),
        source: 'Tự soạn',
        license: 'Được dùng',
        revision: s.revision,
        operationId: 'draft',
      );
      s = await source.recordReview(
        id,
        1,
        reviewerName: 'A',
        note: 'Đã xem',
        revision: s.revision,
        operationId: 'review',
      );
      await source.publishRevision(
        id,
        1,
        revision: s.revision,
        operationId: 'publish',
      );
      final j = jsonDecode(
        (await source.exportBackup()).text,
      ) as Map<String, dynamic>;
      final rows = j['content'] as List;
      final duplicate =
          jsonDecode(jsonEncode(rows.single)) as Map<String, dynamic>;
      duplicate['revision'] = 2;
      (duplicate['review'] as Map)['reviewedRevision'] = 2;
      rows.add(duplicate);
      (j['metadata'] as Map)['content-max:$id'] = '2';
      j.remove('checksum');
      j['checksum'] = canonicalChecksum(j);
      final file = LocalJsonFile.fromBytes(
        utf8.encode(canonicalJson(j)),
        name: 'bad-admin.json',
        kind: LocalJsonKind.adminBackup,
      );
      final before = await target.loadSnapshot();
      expect(
        () => target.prepareBackupRestore(file),
        throwsA(isA<LocalDataException>()),
      );
      final after = await target.loadSnapshot();
      expect(after.identity.publisherId, before.identity.publisherId);
      expect(after.content, isEmpty);
    },
  );
}
