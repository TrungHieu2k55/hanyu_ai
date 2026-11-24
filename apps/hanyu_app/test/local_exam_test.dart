import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show MigrationStrategy, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/exam/data/local_exam_packages.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';

class LegacyV2Database extends LocalDatabase {
  LegacyV2Database(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(localWords);
      await m.createTable(localMetadata);
      await m.createTable(localReceipts);
      await m.createTable(localSchedules);
      await m.createTable(localReviewSessions);
      await m.createTable(localReviewEvents);
    },
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late DriftLocalRepository repo;
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2026, 11, 19, 8);
    repo = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => now,
    );
  });
  tearDown(() => repo.close());
  Future<LocalSnapshot> begin() async {
    final d = await repo.load();
    return repo.startExam(
      'local-level-1',
      LocalExamMode.readingPractice,
      revision: d.revision,
      operationId: 'start',
    );
  }

  test('60 unique draft questions include 30 reading and 30 listening; no full exam is ready', () {
    final all = localExamPackages.expand((p) => p.questions).toList();
    expect(all.length, 60);
    expect(all.map((q) => q.id).toSet().length, 60);
    expect(all.where((q) => q.section == ExamSection.reading).length, 30);
    expect(
      all
          .where((q) => q.section == ExamSection.listening)
          .every((q) => q.audioRef == null && q.transcript != null),
      isTrue,
    );
    expect(localExamPackages.every((p) => !p.readyForFullExam), isTrue);
  });
  test('unreviewed or missing-audio full exam cannot create attempt', () async {
    final d = await repo.load();
    await expectLater(
      repo.startExam(
        'local-level-1',
        LocalExamMode.fullExam,
        revision: d.revision,
        operationId: 'full',
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.load()).exams.attempts, isEmpty);
  });
  test(
    'start retry and second start resume the same unfinished attempt',
    () async {
      final initial = await repo.load();
      var d = await repo.startExam(
        'local-level-1',
        LocalExamMode.readingPractice,
        revision: initial.revision,
        operationId: 'start',
      );
      final first = d.exams.attempts.single;
      d = await repo.startExam(
        'local-level-1',
        LocalExamMode.readingPractice,
        revision: initial.revision,
        operationId: 'start',
      );
      expect(d.exams.attempts.single.id, first.id);
      d = await repo.startExam(
        'local-level-1',
        LocalExamMode.readingPractice,
        revision: d.revision,
        operationId: 'another-start',
      );
      expect(d.exams.attempts, hasLength(1));
      expect(d.exams.attempts.single.questions, hasLength(10));
      expect(
        d.exams.attempts.single.deadline.difference(first.startedAt),
        const Duration(minutes: 20),
      );
    },
  );
  test(
    'answers and cursor are saved and reload does not extend deadline',
    () async {
      var d = await begin();
      final attempt = d.exams.attempts.single;
      d = await repo.saveExamAnswer(
        attempt.id,
        0,
        attempt.questions[0].correct,
        revision: d.revision,
        operationId: 'answer',
      );
      d = await repo.moveExam(
        attempt.id,
        1,
        revision: d.revision,
        operationId: 'move',
      );
      now = now.add(const Duration(minutes: 5));
      final reloaded = await repo.load();
      expect(
        reloaded.exams.attempts.single.answers[0],
        attempt.questions[0].correct,
      );
      expect(reloaded.exams.attempts.single.position, 1);
      expect(reloaded.exams.attempts.single.deadline, attempt.deadline);
    },
  );
  test(
    'blank submit is graded once and later answers cannot alter frozen result',
    () async {
      var d = await begin();
      final id = d.exams.attempts.single.id;
      d = await repo.submitExam(
        id,
        revision: d.revision,
        operationId: 'submit',
      );
      final revision = d.revision;
      expect(d.exams.find(id)!.correctCount, 0);
      expect(d.exams.find(id)!.blanks, 10);
      d = await repo.submitExam(
        id,
        revision: revision - 1,
        operationId: 'submit',
      );
      expect(d.revision, revision);
      d = await repo.saveExamAnswer(
        id,
        0,
        1,
        revision: d.revision,
        operationId: 'late-answer',
      );
      expect(d.exams.find(id)!.answers, isEmpty);
      expect(d.exams.find(id)!.correctCount, 0);
    },
  );
  test(
    'deadline reload freezes only saved answers and does not expire twice',
    () async {
      var d = await begin();
      final a = d.exams.attempts.single;
      d = await repo.saveExamAnswer(
        a.id,
        0,
        a.questions[0].correct,
        revision: d.revision,
        operationId: 'one',
      );
      now = a.deadline;
      d = await repo.load();
      expect(d.exams.find(a.id)!.timedOut, isTrue);
      expect(d.exams.find(a.id)!.correctCount, 1);
      final revision = d.revision;
      expect((await repo.load()).revision, revision);
    },
  );
  test(
    'answer at deadline is ignored; just before deadline is accepted',
    () async {
      var d = await begin();
      final a = d.exams.attempts.single;
      now = a.deadline.subtract(const Duration(milliseconds: 1));
      d = await repo.saveExamAnswer(
        a.id,
        0,
        a.questions[0].correct,
        revision: d.revision,
        operationId: 'before',
      );
      now = a.deadline;
      d = await repo.saveExamAnswer(
        a.id,
        1,
        a.questions[1].correct,
        revision: d.revision,
        operationId: 'at',
      );
      expect(d.exams.find(a.id)!.answers.length, 1);
      expect(d.exams.find(a.id)!.correctCount, 1);
    },
  );
  test('invalid answer and write failure cannot partially alter answers or revision', () async {
    var d = await begin();
    final a = d.exams.attempts.single;
    await expectLater(
      repo.saveExamAnswer(
        a.id,
        0,
        99,
        revision: d.revision,
        operationId: 'bad',
      ),
      throwsA(isA<LocalDataException>()),
    );
    await repo.db.customStatement(
      "CREATE TRIGGER fail_exam BEFORE UPDATE OF answers_json ON local_exam_attempts BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
    );
    await expectLater(
      repo.saveExamAnswer(
        a.id,
        0,
        1,
        revision: d.revision,
        operationId: 'retry',
      ),
      throwsA(anything),
    );
    expect((await repo.load()).revision, d.revision);
    await repo.db.customStatement('DROP TRIGGER fail_exam');
    d = await repo.saveExamAnswer(
      a.id,
      0,
      1,
      revision: d.revision,
      operationId: 'retry',
    );
    expect(d.exams.find(a.id)!.answers[0], 1);
  });
  test('retake creates new ID and keeps old result snapshot', () async {
    var d = await begin();
    final old = d.exams.attempts.single.id;
    d = await repo.submitExam(old, revision: d.revision, operationId: 'submit');
    now = now.add(const Duration(seconds: 1));
    d = await repo.startExam(
      'local-level-1',
      LocalExamMode.readingPractice,
      revision: d.revision,
      operationId: 'retake',
    );
    expect(d.exams.attempts, hasLength(2));
    expect(d.exams.find(old)!.done, isTrue);
    expect(d.exams.attempts.where((a) => !a.done).single.id, isNot(old));
  });
  test('v3 backup keeps score and cursor; wrong score rolls back; v2 import clears attempts', () async {
    var d = await begin();
    final a = d.exams.attempts.single;
    d = await repo.saveExamAnswer(
      a.id,
      0,
      a.questions[0].correct,
      revision: d.revision,
      operationId: 'answer',
    );
    d = await repo.submitExam(
      a.id,
      revision: d.revision,
      operationId: 'submit',
    );
    final backup = await repo.exportBackup();
    d = await repo.restoreBackup(
      backup,
      revision: d.revision,
      operationId: 'restore',
    );
    expect(d.exams.find(a.id)!.correctCount, 1);
    final corrupted = jsonDecode(backup) as Map<String, dynamic>;
    corrupted['exams'][0]['correctCount'] = 999;
    await expectLater(
      repo.restoreBackup(
        jsonEncode(corrupted),
        revision: d.revision,
        operationId: 'bad-restore',
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.load()).exams.find(a.id)!.correctCount, 1);
    final old = jsonDecode(backup) as Map<String, dynamic>;
    old['version'] = 2;
    old.remove('exams');
    d = await repo.restoreBackup(
      jsonEncode(old),
      revision: d.revision,
      operationId: 'old',
    );
    expect(d.exams.attempts, isEmpty);
  });
  test('migration v2→v3 keeps notes schedules and review events', () async {
    final dir = await Directory.systemTemp.createTemp('hanyu-v2-exams-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v2.sqlite');
    final old = LegacyV2Database(NativeDatabase(file));
    await old
        .into(old.localWords)
        .insert(
          LocalWordsCompanion.insert(
            id: '1',
            hanzi: '你好',
            pinyin: 'nǐ hǎo',
            meaning: 'xin chào',
            personal: false,
            saved: const Value(true),
            note: const Value('v2 note'),
          ),
        );
    for (final m in {
      'seed': 'sample-v1-unreviewed',
      'revision': '5',
      'preferences': jsonEncode({
        'name': 'Local',
        'level': 1,
        'minutes': 15,
        'sound': true,
      }),
    }.entries) {
      await old
          .into(old.localMetadata)
          .insert(LocalMetadataCompanion.insert(key: m.key, value: m.value));
    }
    await old
        .into(old.localSchedules)
        .insert(
          LocalSchedulesCompanion.insert(
            wordId: '1',
            dueAt: now.add(const Duration(days: 1)),
            repetitions: const Value(1),
            intervalDays: const Value(1),
          ),
        );
    final card = {
      'id': '1',
      'hanzi': '你好',
      'pinyin': 'nǐ hǎo',
      'meaning': 'xin chào',
      'personal': false,
      'exampleHanzi': '',
      'exampleVietnamese': '',
    };
    await old
        .into(old.localReviewSessions)
        .insert(
          LocalReviewSessionsCompanion.insert(
            id: 'legacy',
            cardsJson: jsonEncode([card]),
            createdAt: now,
            position: const Value(1),
            finishedAt: Value(now),
          ),
        );
    await old
        .into(old.localReviewEvents)
        .insert(
          LocalReviewEventsCompanion.insert(
            id: 'legacy:0',
            sessionId: 'legacy',
            wordId: '1',
            position: 0,
            quality: 4,
            acceptedAt: now,
          ),
        );
    await old.close();
    final migrated = DriftLocalRepository(
      LocalDatabase(NativeDatabase(file)),
      clock: () => now,
    );
    addTearDown(migrated.close);
    final d = await migrated.load();
    expect(d.find('1')!.note, 'v2 note');
    expect(d.review.eventCount, 1);
    expect(d.review.dueCount, 0);
    expect(d.exams.attempts, isEmpty);
  });
}
