import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions, MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/review/domain/sm2.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';

class LegacyV1Database extends LocalDatabase {
  LegacyV1Database(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(localWords);
      await m.createTable(localMetadata);
      await m.createTable(localReceipts);
    },
  );
}

const privateWord = VocabularyItem(
  id: 'personal:review',
  level: null,
  personal: true,
  hanzi: '雨伞',
  pinyin: 'yǔsǎn',
  vietnamese: 'ô',
  exampleHanzi: '',
  exampleVietnamese: '',
);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late DateTime now;
  late DriftLocalRepository repo;
  setUp(() {
    now = DateTime.utc(2026, 11, 19, 8);
    repo = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => now,
    );
  });
  tearDown(() => repo.close());
  Future<LocalSnapshot> begin() async {
    var d = await repo.load();
    d = await repo.putWord(
      privateWord,
      revision: d.revision,
      operationId: 'create',
    );
    d = await repo.saveWord(
      privateWord.id,
      true,
      revision: d.revision,
      operationId: 'save',
    );
    return repo.startReview(revision: d.revision, operationId: 'start');
  }

  test('SM-2 reference vectors preserve previous EF and half-up intervals', () {
    final cases = [
      (0, 0, 2.5, MemoryRating.remembered, 1, 1, 2.5),
      (1, 1, 2.5, MemoryRating.remembered, 2, 6, 2.5),
      (2, 6, 2.5, MemoryRating.remembered, 3, 15, 2.5),
      (2, 6, 2.5, MemoryRating.hard, 3, 15, 2.36),
      (2, 6, 2.5, MemoryRating.easy, 3, 15, 2.6),
      (3, 15, 2.5, MemoryRating.forgot, 0, 1, 1.7),
      (2, 5, 2.5, MemoryRating.remembered, 3, 13, 2.5),
      (2, 6, 1.3, MemoryRating.hard, 3, 8, 1.3),
    ];
    for (final c in cases) {
      final result = ReviewSchedule(
        repetitions: c.$1,
        intervalDays: c.$2,
        ease: c.$3,
      ).next(c.$4);
      expect(result.repetitions, c.$5);
      expect(result.intervalDays, c.$6);
      expect(result.ease, closeTo(c.$7, 1e-10));
    }
  });

  test(
    'reveal required; one rating atomically completes session and updates due',
    () async {
      var d = await begin();
      final session = d.review.active!;
      await expectLater(
        repo.rateReview(
          session.id,
          0,
          MemoryRating.remembered,
          revision: d.revision,
          operationId: 'hidden',
        ),
        throwsA(isA<LocalConflict>()),
      );
      d = await repo.revealReview(
        session.id,
        0,
        revision: d.revision,
        operationId: 'reveal',
      );
      final oldRevision = d.revision;
      d = await repo.rateReview(
        session.id,
        0,
        MemoryRating.remembered,
        revision: d.revision,
        operationId: 'rating',
      );
      expect(d.review.active, isNull);
      expect(d.review.sessions.single.qualities, [4]);
      expect(d.review.eventCount, 1);
      expect(d.review.dueCount, 0);
      final duplicate = await repo.rateReview(
        session.id,
        0,
        MemoryRating.remembered,
        revision: oldRevision,
        operationId: 'rating',
      );
      expect(duplicate.review.eventCount, 1);
      expect(duplicate.revision, d.revision);
      final schedule = await repo.db.select(repo.db.localSchedules).getSingle();
      expect(schedule.dueAt.toUtc(), now.add(const Duration(days: 1)));
      expect(schedule.repetitions, 1);
      now = now.add(const Duration(hours: 24));
      expect((await repo.load()).review.dueCount, 1);
    },
  );

  test('paused session keeps reveal and immutable card after changing/deleting source', () async {
    var d = await begin();
    final session = d.review.active!;
    d = await repo.revealReview(
      session.id,
      0,
      revision: d.revision,
      operationId: 'reveal',
    );
    d = await repo.deleteWord(
      privateWord.id,
      revision: d.revision,
      operationId: 'delete',
    );
    final reopened = await repo.load();
    expect(reopened.review.active!.revealed, isTrue);
    expect(reopened.review.active!.cards.single.vietnamese, 'ô');
    d = await repo.rateReview(
      session.id,
      0,
      MemoryRating.hard,
      revision: d.revision,
      operationId: 'rate-deleted',
    );
    expect(d.review.eventCount, 1);
    expect(d.find(privateWord.id), isNull);
    expect(await repo.db.select(repo.db.localSchedules).get(), isEmpty);
  });

  test(
    'un-saving a source preserves history and does not re-enable its schedule',
    () async {
      var d = await begin();
      final session = d.review.active!;
      d = await repo.saveWord(
        privateWord.id,
        false,
        revision: d.revision,
        operationId: 'unsave',
      );
      d = await repo.revealReview(
        session.id,
        0,
        revision: d.revision,
        operationId: 'reveal',
      );
      d = await repo.rateReview(
        session.id,
        0,
        MemoryRating.easy,
        revision: d.revision,
        operationId: 'rate',
      );
      expect(d.review.dueCount, 0);
      expect(
        (await repo.db.select(repo.db.localSchedules).getSingle()).active,
        isFalse,
      );
    },
  );

  test('v2 backup roundtrip keeps reveal events and due; invalid history rolls back', () async {
    var d = await begin();
    final session = d.review.active!;
    d = await repo.revealReview(
      session.id,
      0,
      revision: d.revision,
      operationId: 'reveal',
    );
    d = await repo.rateReview(
      session.id,
      0,
      MemoryRating.remembered,
      revision: d.revision,
      operationId: 'rate',
    );
    final backup = await repo.exportBackup();
    d = await repo.restoreBackup(
      backup,
      revision: d.revision,
      operationId: 'restore',
    );
    expect(d.review.eventCount, 1);
    expect(d.review.sessions.single.completed, isTrue);
    final broken = jsonDecode(backup) as Map<String, dynamic>;
    (broken['review']['events'] as List).clear();
    await expectLater(
      repo.restoreBackup(
        jsonEncode(broken),
        revision: d.revision,
        operationId: 'broken',
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.load()).review.eventCount, 1);
  });

  test('v1 backup imports words and initializes fresh schedules', () async {
    var d = await begin();
    final old = jsonDecode(await repo.exportBackup()) as Map<String, dynamic>;
    old['version'] = 1;
    old.remove('review');
    d = await repo.restoreBackup(
      jsonEncode(old),
      revision: d.revision,
      operationId: 'v1',
    );
    expect(d.review.sessions, isEmpty);
    expect(d.review.dueCount, 1);
    expect(d.find(privateWord.id)!.saved, isTrue);
  });

  test(
    'migration v1→v2 keeps word note preferences and backfills saved queue',
    () async {
      final dir = await Directory.systemTemp.createTemp('hanyu-migration-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/old.sqlite');
      final old = LegacyV1Database(NativeDatabase(file));
      for (final word in sampleVocabulary) {
        await old
            .into(old.localWords)
            .insert(
              LocalWordsCompanion.insert(
                id: word.id,
                hanzi: word.hanzi,
                pinyin: word.pinyin,
                meaning: word.vietnamese,
                personal: false,
              ),
            );
      }
      await old.customStatement(
        "UPDATE local_words SET saved=1,note='legacy note' WHERE id='1'",
      );
      for (final item in {
        'seed': 'sample-v1-unreviewed',
        'revision': '7',
        'preferences': jsonEncode({
          'name': 'Hiếu',
          'level': 2,
          'minutes': 20,
          'sound': false,
        }),
      }.entries) {
        await old
            .into(old.localMetadata)
            .insert(
              LocalMetadataCompanion.insert(key: item.key, value: item.value),
            );
      }
      await old.close();
      final migrated = DriftLocalRepository(
        LocalDatabase(NativeDatabase(file)),
        clock: () => now,
      );
      addTearDown(migrated.close);
      final d = await migrated.load();
      expect(d.revision, 7);
      expect(d.find('1')!.note, 'legacy note');
      expect(d.review.dueCount, 1);
      expect(d.preferences.name, 'Hiếu');
    },
  );
}
