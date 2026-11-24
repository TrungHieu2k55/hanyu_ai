import 'package:doanchuyennganh2/core/local/review_store.dart';
import 'package:doanchuyennganh2/core/local/exam_store.dart';
import 'package:doanchuyennganh2/core/local/practice_store.dart';

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/database_names.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_commit.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';
import 'package:doanchuyennganh2/features/exam/data/local_exam_packages.dart';

import 'support/practice_fixtures.dart';

class V4Fixture extends LocalDatabase {
  V4Fixture(super.executor);
  @override
  int get schemaVersion => 4;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final table in <TableInfo>[
        localWords,
        localMetadata,
        localReceipts,
        localSchedules,
        localReviewSessions,
        localReviewEvents,
        localExamAttempts,
        localPracticeEntries,
        localMedia,
      ]) {
        await m.createTable(table);
      }
    },
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

  Future<String> oldRows(LocalDatabase db) async {
    final result = <String, Object?>{};
    for (final table in [
      'local_words',
      'local_metadata',
      'local_receipts',
      'local_schedules',
      'local_review_sessions',
      'local_review_events',
      'local_exam_attempts',
      'local_practice_entries',
      'local_media',
    ]) {
      result[table] =
          (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((r) => r.data)
              .toList();
    }
    return jsonEncode(result);
  }

  test('v4 to v5 adds tables/index without changing any A-D row', () async {
    final dir = await Directory.systemTemp.createTemp('hanyu-e-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v4.sqlite');
    final old = V4Fixture(NativeDatabase(file));
    await old
        .into(old.localWords)
        .insert(
          LocalWordsCompanion.insert(
            id: 'legacy-word',
            hanzi: '你好',
            pinyin: 'nǐ hǎo',
            meaning: 'xin chào',
            personal: true,
            saved: const Value(true),
            note: const Value('Ghi chú trước E'),
          ),
        );
    for (final e in {
      'revision': '5',
      'seed': 'sample-v1-unreviewed',
      'preferences': jsonEncode({
        'name': 'Hiếu',
        'level': 1,
        'minutes': 15,
        'sound': true,
      }),
    }.entries) {
      await old
          .into(old.localMetadata)
          .insert(LocalMetadataCompanion.insert(key: e.key, value: e.value));
    }
    final reviews = ReviewStore(old, () => practiceNow);
    await reviews.initializeMissing();
    await reviews.start();
    await ExamStore(
      old,
      () => practiceNow,
    ).start(localExamPackages.first.id, LocalExamMode.readingPractice);
    await PracticeStore(old, () => practiceNow).save(photo(), [picture()]);
    final rows = await oldRows(old);
    await old.close();
    final after = DriftLocalRepository(
      LocalDatabase(NativeDatabase(file)),
      clock: () => practiceNow,
    );
    addTearDown(after.close);
    expect((await after.load()).revision, 5);
    expect(await oldRows(after.db), rows);
    for (final table in [
      'local_feedback_reports',
      'local_admin_revisions',
      'local_admin_inbox',
      'local_admin_packages',
      'local_installed_packages',
      'local_catalog_receipts',
    ]) {
      expect(
        await after.db.customSelect('SELECT * FROM $table').get(),
        isEmpty,
      );
    }
    final indexes = await after.db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='local_admin_current_published'",
        )
        .get();
    expect(indexes, hasLength(1));
    expect(
      (await after.db.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      5,
    );
  });

  test(
    'published revision uniqueness is enforced by SQL for create and migration',
    () async {
      final db = LocalDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      Future<void> insert(int revision, String state) => db
          .into(db.localAdminRevisions)
          .insert(
            LocalAdminRevisionsCompanion.insert(
              itemId: 'item',
              revision: revision,
              kind: 'vocabulary',
              dataJson: '{}',
              state: state,
            ),
          );
      await insert(1, 'published');
      await insert(2, 'draft');
      await expectLater(insert(3, 'published'), throwsA(anything));
      expect(await db.select(db.localAdminRevisions).get(), hasLength(2));
    },
  );

  test('learner and Admin names isolate persisted rows and receipts', () async {
    expect(learnerDatabaseName, 'hanyu_local_v1');
    expect(adminDatabaseName, 'hanyu_admin');
    expect(adminDatabaseName, isNot(learnerDatabaseName));
    final dir = await Directory.systemTemp.createTemp('hanyu-e-isolation-');
    addTearDown(() => dir.delete(recursive: true));
    final learner = DriftLocalRepository(
      LocalDatabase(
        NativeDatabase(File('${dir.path}/$learnerDatabaseName.sqlite')),
      ),
    );
    final admin = LocalDatabase(
      NativeDatabase(File('${dir.path}/$adminDatabaseName.sqlite')),
    );
    addTearDown(learner.close);
    addTearDown(admin.close);
    final initial = await learner.load();
    await learner.saveNote(
      initial.words.first.entry.id,
      'Riêng tư',
      revision: initial.revision,
      operationId: 'private',
    );
    expect(await admin.select(admin.localWords).get(), isEmpty);
    expect(await admin.select(admin.localReceipts).get(), isEmpty);
    await admin
        .into(admin.localMetadata)
        .insert(LocalMetadataCompanion.insert(key: 'revision', value: '0'));
    await LocalCommit(admin).run(
      revision: 0,
      operationId: 'private',
      payload: ['admin'],
      action: () async {},
      snapshot: () async => 1,
    );
    expect((await learner.load()).words.first.note, 'Riêng tư');
  });

  test(
    'shared runner rolls back action on snapshot/receipt failure and retries',
    () async {
      final repo = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
      addTearDown(repo.close);
      final initial = await repo.load();
      final db = repo.db;
      Future<void> action() =>
          db.customStatement("UPDATE local_words SET note='should rollback'");
      Future<int> run({bool failSnapshot = false}) => LocalCommit(db).run(
        revision: initial.revision,
        operationId: 'shared',
        payload: ['intent'],
        action: action,
        snapshot: () async {
          if (failSnapshot) throw StateError('snapshot failure');
          return 1;
        },
      );
      await expectLater(run(failSnapshot: true), throwsStateError);
      expect((await repo.load()).revision, initial.revision);
      expect((await repo.load()).words.first.note, '');
      await db.customStatement(
        "CREATE TRIGGER fail_receipt BEFORE INSERT ON local_receipts BEGIN SELECT RAISE(ABORT, 'full'); END",
      );
      await expectLater(run(), throwsA(anything));
      expect((await repo.load()).revision, initial.revision);
      expect((await repo.load()).words.first.note, '');
      await db.customStatement('DROP TRIGGER fail_receipt');
      expect(await run(), 1);
      expect(await run(), 1);
      expect((await repo.load()).revision, initial.revision + 1);
      expect(await db.select(db.localReceipts).get(), hasLength(1));
    },
  );
}
