import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_revision.dart';

VocabularyContent word([String meaning = 'bạn']) => VocabularyContent(
  hanzi: '朋友',
  pinyin: 'péngyou',
  vietnamese: meaning,
  targetLevel: 1,
);
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late LocalAdminRepository repo;
  late String id;
  final now = DateTime.utc(2026, 11, 22, 10);
  setUp(() {
    id = const Uuid().v4();
    repo = LocalAdminRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => now,
    );
  });
  tearDown(() => repo.close());
  test('payload constraints and immutable collections cover all three content kinds', () {
    expect(
      () => VocabularyContent(hanzi: 'abc', pinyin: 'a', vietnamese: 'b'),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => VocabularyContent(hanzi: '人' * 31, pinyin: 'a', vietnamese: 'b'),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => QuestionContent(
        targetLevel: 1,
        section: 'reading',
        slot: 1,
        prompt: '?',
        choices: ['a', 'b', 'c'],
        correctIndex: 0,
        explanation: 'x',
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => QuestionContent(
        targetLevel: 1,
        section: 'reading',
        slot: 1,
        prompt: '?',
        choices: ['a', 'b', 'c', ' a '],
        correctIndex: 0,
        explanation: 'x',
      ),
      throwsA(isA<LocalDataException>()),
    );
    final choices = ['a', 'b', 'c', 'd'];
    final q = QuestionContent(
      targetLevel: 3,
      section: 'listening',
      slot: 10,
      prompt: '?',
      choices: choices,
      correctIndex: 3,
      explanation: 'x',
    );
    choices[0] = 'changed';
    expect(q.choices.first, 'a');
    expect(() => q.choices.add('e'), throwsUnsupportedError);
    expect(
      () => ScenarioContent(
        key: 'fifth',
        role: 'x',
        partner: 'x',
        goal: 'x',
        opening: ['a', 'b', 'c'],
        sampleReply: ['a', 'b', 'c'],
      ),
      throwsA(isA<LocalDataException>()),
    );
  });
  test(
    'new database is empty and never invents reviewer or verified identity',
    () async {
      final s = await repo.loadSnapshot();
      expect(s.content, isEmpty);
      expect(s.identity.label, '');
      expect(s.identity.publisherId, matches(RegExp(r'^[a-f0-9-]{36}$')));
      expect(
        (await repo.loadSnapshot()).identity.publisherId,
        s.identity.publisherId,
      );
      expect(await repo.db.select(repo.db.localWords).get(), isEmpty);
    },
  );
  test('review/publish/edit preserves payload history and supersedes only on new publish', () async {
    var s = await repo.loadSnapshot();
    s = await repo.saveRevision(
      id: id,
      baseRevision: 0,
      payload: word(),
      source: 'Nhóm tự soạn',
      license: 'Cho phép dùng trong đồ án',
      revision: s.revision,
      operationId: 'create',
    );
    expect(s.content.single.review.status, ReviewStatus.unreviewed);
    await expectLater(
      repo.publishRevision(
        id,
        1,
        revision: s.revision,
        operationId: 'bad-publish',
      ),
      throwsA(isA<LocalDataException>()),
    );
    s = await repo.recordReview(
      id,
      1,
      reviewerName: 'Người khai báo',
      note: 'Đã đối chiếu nguồn',
      revision: s.revision,
      operationId: 'review',
    );
    s = await repo.publishRevision(
      id,
      1,
      revision: s.revision,
      operationId: 'publish',
    );
    s = await repo.saveRevision(
      id: id,
      baseRevision: 1,
      payload: word('người bạn'),
      source: 'Nhóm tự soạn',
      license: 'Cho phép dùng trong đồ án',
      revision: s.revision,
      operationId: 'edit',
    );
    expect(
      s.content.singleWhere((c) => c.revision == 1).state,
      ContentState.published,
    );
    final newer = s.content.singleWhere((c) => c.revision == 2);
    expect(newer.state, ContentState.draft);
    expect(newer.review.status, ReviewStatus.unreviewed);
    expect(
      (s.content.singleWhere((c) => c.revision == 1).payload
              as VocabularyContent)
          .vietnamese,
      'bạn',
    );
    s = await repo.recordReview(
      id,
      2,
      reviewerName: 'Người khai báo',
      note: 'Đối chiếu phiên bản 2',
      revision: s.revision,
      operationId: 'review2',
    );
    s = await repo.publishRevision(
      id,
      2,
      revision: s.revision,
      operationId: 'publish2',
    );
    expect(
      s.content.singleWhere((c) => c.revision == 1).state,
      ContentState.superseded,
    );
    s = await repo.withdrawRevision(
      id,
      2,
      revision: s.revision,
      operationId: 'withdraw',
    );
    expect(s.content.any((c) => c.state == ContentState.published), false);
    expect(
      s.content.singleWhere((c) => c.revision == 1).state,
      ContentState.superseded,
    );
  });
  test(
    'review metadata/source are required, cannot rewrite an old claim',
    () async {
      var s = await repo.loadSnapshot();
      s = await repo.saveRevision(
        id: id,
        baseRevision: 0,
        payload: word(),
        revision: s.revision,
        operationId: 'draft',
      );
      await expectLater(
        repo.recordReview(
          id,
          1,
          reviewerName: '',
          note: '',
          revision: s.revision,
          operationId: 'empty',
        ),
        throwsA(isA<LocalDataException>()),
      );
      await expectLater(
        repo.recordReview(
          id,
          1,
          reviewerName: 'A',
          note: 'B',
          revision: s.revision,
          operationId: 'no-source',
        ),
        throwsA(isA<LocalDataException>()),
      );
      expect(
        (await repo.loadSnapshot()).content.single.state,
        ContentState.draft,
      );
    },
  );
  test(
    'deletion is restricted and never reuses an allocated revision or kind',
    () async {
      var s = await repo.loadSnapshot();
      s = await repo.saveRevision(
        id: id,
        baseRevision: 0,
        payload: word(),
        revision: s.revision,
        operationId: 'one',
      );
      s = await repo.saveRevision(
        id: id,
        baseRevision: 1,
        payload: word('bạn bè'),
        revision: s.revision,
        operationId: 'two',
      );
      await expectLater(
        repo.deleteUnexportedDraft(
          id,
          1,
          revision: s.revision,
          operationId: 'old',
        ),
        throwsA(isA<LocalDataException>()),
      );
      s = await repo.deleteUnexportedDraft(
        id,
        2,
        revision: s.revision,
        operationId: 'delete',
      );
      s = await repo.saveRevision(
        id: id,
        baseRevision: 1,
        payload: word('người bạn'),
        revision: s.revision,
        operationId: 'three',
      );
      expect(s.content.map((c) => c.revision).toSet(), {1, 3});
      await repo.db.customStatement(
        'UPDATE local_admin_revisions SET exported=1 WHERE item_id=? AND revision=3',
        [id],
      );
      await expectLater(
        repo.deleteUnexportedDraft(
          id,
          3,
          revision: s.revision,
          operationId: 'pinned',
        ),
        throwsA(isA<LocalDataException>()),
      );
    },
  );
  test(
    'receipts/CAS and write failure prevent partial content and metadata',
    () async {
      final s = await repo.loadSnapshot();
      await repo.db.customStatement(
        "CREATE TRIGGER fail_content BEFORE INSERT ON local_admin_revisions BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await expectLater(
        repo.saveRevision(
          id: id,
          baseRevision: 0,
          payload: word(),
          revision: s.revision,
          operationId: 'retry',
        ),
        throwsA(anything),
      );
      expect((await repo.loadSnapshot()).revision, s.revision);
      await repo.db.customStatement('DROP TRIGGER fail_content');
      final good = await repo.saveRevision(
        id: id,
        baseRevision: 0,
        payload: word(),
        revision: s.revision,
        operationId: 'retry',
      );
      expect(
        (await repo.saveRevision(
          id: id,
          baseRevision: 0,
          payload: word(),
          revision: s.revision,
          operationId: 'retry',
        )).revision,
        good.revision,
      );
      await expectLater(
        repo.saveRevision(
          id: id,
          baseRevision: 1,
          payload: word('x'),
          revision: s.revision,
          operationId: 'stale',
        ),
        throwsA(isA<LocalConflict>()),
      );
    },
  );
  test('explicit samples load only once and all remain unreviewed', () async {
    var s = await repo.loadSnapshot();
    expect(s.content, isEmpty);
    s = await repo.seedSamples(revision: s.revision, operationId: 'sample');
    expect(s.content, hasLength(6));
    expect(
      s.content.every(
        (c) =>
            c.state == ContentState.draft &&
            c.review.status == ReviewStatus.unreviewed,
      ),
      true,
    );
    s = await repo.seedSamples(revision: s.revision, operationId: 'again');
    expect(s.content, hasLength(6));
  });
  test(
    'file DB preserves identity, revisions and declared review after reopening',
    () async {
      final dir = await Directory.systemTemp.createTemp('hanyu-admin-content-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/admin.sqlite');
      final first = LocalAdminRepository(LocalDatabase(NativeDatabase(file)));
      var s = await first.loadSnapshot();
      final publisher = s.identity.publisherId;
      s = await first.saveIdentityLabel(
        'Nhóm học liệu',
        revision: s.revision,
        operationId: 'label',
      );
      s = await first.saveRevision(
        id: id,
        baseRevision: 0,
        payload: word(),
        source: 'Tự soạn',
        license: 'Cho phép dùng',
        revision: s.revision,
        operationId: 'content',
      );
      await first.recordReview(
        id,
        1,
        reviewerName: 'A',
        note: 'Đã đối chiếu',
        revision: s.revision,
        operationId: 'review',
      );
      await first.close();
      final next = LocalAdminRepository(LocalDatabase(NativeDatabase(file)));
      addTearDown(next.close);
      final loaded = await next.loadSnapshot();
      expect(loaded.identity.publisherId, publisher);
      expect(loaded.identity.label, 'Nhóm học liệu');
      expect(loaded.content.single.review.reviewerName, 'A');
    },
  );
  test(
    'failed second publish restores previous published revision atomically',
    () async {
      var s = await repo.loadSnapshot();
      s = await repo.saveRevision(
        id: id,
        baseRevision: 0,
        payload: word(),
        source: 'Tự soạn',
        license: 'Dùng trong đồ án',
        revision: s.revision,
        operationId: 'one',
      );
      s = await repo.recordReview(
        id,
        1,
        reviewerName: 'A',
        note: 'Đối chiếu',
        revision: s.revision,
        operationId: 'r1',
      );
      s = await repo.publishRevision(
        id,
        1,
        revision: s.revision,
        operationId: 'p1',
      );
      s = await repo.saveRevision(
        id: id,
        baseRevision: 1,
        payload: word('bạn bè'),
        source: 'Tự soạn',
        license: 'Dùng trong đồ án',
        revision: s.revision,
        operationId: 'two',
      );
      s = await repo.recordReview(
        id,
        2,
        reviewerName: 'A',
        note: 'Đối chiếu 2',
        revision: s.revision,
        operationId: 'r2',
      );
      await repo.db.customStatement(
        "CREATE TRIGGER fail_publish BEFORE INSERT ON local_admin_revisions WHEN NEW.revision=2 AND NEW.state='published' BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await expectLater(
        repo.publishRevision(id, 2, revision: s.revision, operationId: 'p2'),
        throwsA(anything),
      );
      var intact = await repo.loadSnapshot();
      expect(intact.revision, s.revision);
      expect(
        intact.content.singleWhere((c) => c.revision == 1).state,
        ContentState.published,
      );
      expect(
        intact.content.singleWhere((c) => c.revision == 2).state,
        ContentState.reviewed,
      );
      await repo.db.customStatement('DROP TRIGGER fail_publish');
      intact = await repo.publishRevision(
        id,
        2,
        revision: s.revision,
        operationId: 'p2',
      );
      expect(
        intact.content.singleWhere((c) => c.revision == 1).state,
        ContentState.superseded,
      );
    },
  );
  test(
    'metadata caps reject overlong claims and accept exact Unicode boundaries',
    () async {
      var s = await repo.loadSnapshot();
      for (final metadata in [
        <String, String>{'source': '人' * 2001, 'license': 'ok'},
        <String, String>{'source': 'ok', 'license': '人' * 301},
      ]) {
        await expectLater(
          repo.saveRevision(
            id: id,
            baseRevision: 0,
            payload: word(),
            source: metadata['source']!,
            license: metadata['license']!,
            revision: s.revision,
            operationId: 'bad-${metadata['source']!.length}',
          ),
          throwsA(isA<LocalDataException>()),
        );
      }
      expect((await repo.loadSnapshot()).content, isEmpty);
      expect(
        () => ReviewClaim.declare(
          reviewerName: '人' * 81,
          reviewedRevision: 1,
          reviewedAt: now,
          note: 'ok',
        ),
        throwsA(isA<LocalDataException>()),
      );
      expect(
        () => ReviewClaim.declare(
          reviewerName: 'A',
          reviewedRevision: 1,
          reviewedAt: now,
          note: '人' * 2001,
        ),
        throwsA(isA<LocalDataException>()),
      );
      await expectLater(
        repo.saveIdentityLabel(
          '人' * 81,
          revision: s.revision,
          operationId: 'bad-label',
        ),
        throwsA(isA<LocalDataException>()),
      );
      s = await repo.saveRevision(
        id: id,
        baseRevision: 0,
        payload: word(),
        source: '人' * 2000,
        license: '人' * 300,
        revision: s.revision,
        operationId: 'exact',
      );
      s = await repo.recordReview(
        id,
        1,
        reviewerName: '人' * 80,
        note: '人' * 2000,
        revision: s.revision,
        operationId: 'exact-review',
      );
      expect(s.content.single.state, ContentState.reviewed);
    },
  );
}
