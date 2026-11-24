import 'package:crypto/crypto.dart';

import 'support/practice_fixtures.dart';

import 'package:doanchuyennganh2/features/exam/data/local_exam_packages.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart'
    show MigrationStrategy, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/practice_archive.dart';
import 'package:doanchuyennganh2/core/local/practice_validation.dart';
import 'package:doanchuyennganh2/core/media/practice_media.dart';
import 'package:doanchuyennganh2/features/practice/domain/local_practice.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';

class V3PracticeFixture extends LocalDatabase {
  V3PracticeFixture(super.executor);
  @override
  int get schemaVersion => 3;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(localWords);
      await m.createTable(localMetadata);
      await m.createTable(localReceipts);
      await m.createTable(localSchedules);
      await m.createTable(localReviewSessions);
      await m.createTable(localReviewEvents);
      await m.createTable(localExamAttempts);
    },
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late DriftLocalRepository repo;
  late LocalSnapshot data;
  setUp(() async {
    repo = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => practiceNow,
    );
    data = await repo.load();
  });
  tearDown(() => repo.close());
  Future<void> save(
    LocalPracticeEntry e,
    String op, {
    List<LocalMediaInput> media = const [],
  }) async {
    data = await repo.savePractice(
      e,
      media: media,
      revision: data.revision,
      operationId: op,
    );
  }

  test('writing survives reload, completed attempts freeze and receipt retries do not duplicate', () async {
    final start = data.revision;
    await save(writing(), 'draft');
    data = await repo.savePractice(
      writing(),
      revision: start,
      operationId: 'draft',
    );
    expect(data.practice.length, 1);
    expect(data.revision, start + 1);
    expect((await repo.load()).practice.single.data['strokes'], [
      [
        [0.2, 0.3],
        [0.5, 0.8],
      ],
    ]);
    await save(writing(done: true), 'finish');
    await expectLater(
      save(writing(), 'mutate'),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.load()).practice.single.done, isTrue);
    await save(writing(id: 'retake'), 'retake');
    expect(data.practice.length, 2);
  });
  test('empty completed canvas, invalid coordinates and stale revision cannot change saved work', () async {
    await save(writing(), 'saved');
    final old = data.revision;
    for (final strokes in [
      [],
      [
        [
          [1.1, 0.2],
        ],
      ],
    ]) {
      await expectLater(
        save(
          writing(done: true)
              .copy(data: {...writing().data, 'strokes': strokes}),
          'bad:$strokes',
        ),
        throwsA(isA<LocalDataException>()),
      );
    }
    await expectLater(
      repo.savePractice(
        writing(id: 'stale'),
        revision: old - 1,
        operationId: 'stale',
      ),
      throwsA(isA<LocalConflict>()),
    );
    expect((await repo.load()).revision, old);
    expect((await repo.load()).practice.length, 1);
  });
  test('image and text commit together; removing image preserves original and edited text', () async {
    await save(photo(), 'photo', media: [picture()]);
    expect(data.media.single.mime, 'image/png');
    expect(await repo.readMedia('image'), picture().bytes);
    await save(photo(image: null, text: '谢谢'), 'text');
    expect(data.media, isEmpty);
    expect(await repo.readMedia('image'), isNull);
    expect(data.practice.single.data['original'], '你好');
    expect(data.practice.single.data['text'], '谢谢');
    await expectLater(
      save(
        photo(image: null)
            .copy(data: {'original': '改', 'text': '改', 'imageId': null}),
        'original',
      ),
      throwsA(isA<LocalDataException>()),
    );
  });
  test(
    'fake image, broken WAV and missing media rollback all inserts and receipt',
    () async {
      final revision = data.revision;
      for (final m in [
        LocalMediaInput(
          id: 'image',
          mime: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        LocalMediaInput(id: 'image', mime: 'audio/wav', bytes: Uint8List(44)),
      ]) {
        await expectLater(
          save(photo(), 'bad', media: [m]),
          throwsA(isA<LocalDataException>()),
        );
      }
      await expectLater(
        save(photo(), 'missing'),
        throwsA(isA<LocalDataException>()),
      );
      expect((await repo.load()).revision, revision);
      expect((await repo.load()).media, isEmpty);
      await save(photo(), 'bad', media: [picture()]);
      expect(data.practice.length, 1);
    },
  );
  test('database failure rolls back both media and content; retry with same intent succeeds', () async {
    await repo.db.customStatement(
      "CREATE TRIGGER deny_practice BEFORE INSERT ON local_practice_entries BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    await expectLater(
      save(photo(), 'retry', media: [picture()]),
      throwsA(anything),
    );
    expect((await repo.load()).media, isEmpty);
    expect((await repo.load()).revision, data.revision);
    await repo.db.customStatement('DROP TRIGGER deny_practice');
    await save(photo(), 'retry', media: [picture()]);
    expect(data.media.length, 1);
  });
  test('audio draft does not count a turn; confirmation is idempotent and eighth turn closes session', () async {
    await save(conversation(), 'draft', media: [sound()]);
    expect((data.practice.single.data['turns'] as List), isEmpty);
    final before = data.revision;
    data = await repo.confirmPracticeTurn(
      'talk',
      revision: before,
      operationId: 'confirm1',
    );
    data = await repo.confirmPracticeTurn(
      'talk',
      revision: before,
      operationId: 'confirm1',
    );
    expect((data.practice.single.data['turns'] as List).length, 1);
    expect(data.media.length, 1);
    expect(data.practice.single.data['draft'], '');
    for (var i = 2; i <= 8; i++) {
      final current = data.practice.single;
      await save(
        current.copy(data: {...current.data, 'draft': '第$i句'}),
        'draft$i',
      );
      data = await repo.confirmPracticeTurn(
        'talk',
        revision: data.revision,
        operationId: 'confirm$i',
      );
    }
    expect(data.practice.single.done, isTrue);
    expect((data.practice.single.data['turns'] as List).length, 8);
    await expectLater(
      repo.confirmPracticeTurn(
        'talk',
        revision: data.revision,
        operationId: 'nine',
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect(await repo.readMedia('sound'), sound().bytes);
  });
  test('full ZIP roundtrip retains writing/image/audio/turn and existing reading result', () async {
    await save(writing(done: true), 'writing');
    await save(photo(), 'photo', media: [picture()]);
    await save(conversation(), 'talk', media: [sound()]);
    data = await repo.confirmPracticeTurn(
      'talk',
      revision: data.revision,
      operationId: 'turn',
    );
    data = await repo.startExam(
      'local-level-1',
      LocalExamMode.readingPractice,
      revision: data.revision,
      operationId: 'exam',
    );
    final exam = data.exams.attempts.single;
    data = await repo.submitExam(
      exam.id,
      revision: data.revision,
      operationId: 'submit',
    );
    final zip = await repo.exportArchive();
    data = await repo.deletePractice(
      'photo',
      revision: data.revision,
      operationId: 'delete',
    );
    expect(await repo.readMedia('image'), isNull);
    data = await repo.restoreArchive(
      zip,
      revision: data.revision,
      operationId: 'restore',
    );
    expect(data.practice.length, 3);
    expect(data.media.length, 2);
    expect(data.exams.attempts.single.correctCount, 0);
    expect(await repo.readMedia('sound'), sound().bytes);
    expect(await repo.readMedia('image'), picture().bytes);
  });
  test(
    'ZIP tamper, traversal and oversized header are rejected before mutation',
    () async {
      await save(photo(), 'photo', media: [picture()]);
      final zip = await repo.exportArchive();
      final revision = data.revision;
      Uint8List archiveBytes(Archive a) =>
          Uint8List.fromList(ZipEncoder().encode(a));
      final tampered = ZipDecoder().decodeBytes(zip);
      final bad = Archive();
      for (final f in tampered) {
        bad.add(
          f.name == 'media/image'
              ? ArchiveFile(f.name, 3, [1, 2, 3])
              : ArchiveFile(f.name, f.size, f.readBytes()!),
        );
      }
      await expectLater(
        repo.restoreArchive(
          archiveBytes(bad),
          revision: revision,
          operationId: 'tamper',
        ),
        throwsA(isA<LocalDataException>()),
      );
      final traversal = Archive()
        ..add(ArchiveFile('../data.json', 2, [123, 125]));
      await expectLater(
        repo.restoreArchive(
          archiveBytes(traversal),
          revision: revision,
          operationId: 'path',
        ),
        throwsA(isA<LocalDataException>()),
      );
      final broken = Uint8List.fromList(zip);
      final bd = ByteData.sublistView(broken);
      for (var i = 0; i < broken.length - 46; i++) {
        if (bd.getUint32(i, Endian.little) == 0x02014b50) {
          bd.setUint32(i + 24, backupBudget + 1, Endian.little);
          break;
        }
      }
      await expectLater(
        repo.restoreArchive(broken, revision: revision, operationId: 'bomb'),
        throwsA(isA<LocalDataException>()),
      );
      expect((await repo.load()).revision, revision);
      expect(await repo.readMedia('image'), picture().bytes);
    },
  );
  test('valid-manifest invalid record restores nothing; legacy JSON explicitly clears practice media', () async {
    await save(photo(), 'photo', media: [picture()]);
    final zip = await repo.exportArchive();
    final decoded = PracticeArchive.decode(zip);
    (decoded.data['practice'] as List).first['data']['imageId'] = 'missing';
    final bad = PracticeArchive.encode(decoded.data, decoded.media);
    await expectLater(
      repo.restoreArchive(bad, revision: data.revision, operationId: 'bad'),
      throwsA(isA<LocalDataException>()),
    );
    expect(await repo.readMedia('image'), picture().bytes);
    final legacy = Uint8List.fromList(utf8.encode(await repo.exportBackup()));
    data = await repo.restoreArchive(
      legacy,
      revision: data.revision,
      operationId: 'legacy',
    );
    expect(data.practice, isEmpty);
    expect(data.media, isEmpty);
    expect(data.words, isNotEmpty);
  });
  test('50 MiB quota rejects next media atomically', () async {
    await save(photo(), 'photo', media: [picture()]);
    await repo.db.customStatement(
      'UPDATE local_media SET bytes = zeroblob(?)',
      [mediaBudget],
    );
    final newPhoto = LocalPracticeEntry(
      id: 'new-photo',
      kind: PracticeKind.photo,
      createdAt: practiceNow,
      updatedAt: practiceNow,
      data: {'original': '', 'text': '字', 'imageId': 'next'},
    );
    await expectLater(
      save(newPhoto, 'quota', media: [picture('next')]),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.load()).practice.length, 1);
    expect((await repo.load()).media.length, 1);
  });
  test('migration v3 to v4 keeps existing word note', () async {
    final dir = await Directory.systemTemp.createTemp('hanyu-v3-practice-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/data.sqlite');
    final old = V3PracticeFixture(NativeDatabase(file));
    await old
        .into(old.localWords)
        .insert(
          LocalWordsCompanion.insert(
            id: 'personal:old',
            hanzi: '人',
            pinyin: 'rén',
            meaning: 'người',
            personal: true,
            note: const Value('Ghi chú cũ'),
          ),
        );
    for (final e in {
      'seed': 'sample-v1-unreviewed',
      'revision': '7',
      'preferences': jsonEncode({
        'name': 'Người học',
        'level': 1,
        'minutes': 15,
        'sound': true,
      }),
    }.entries) {
      await old
          .into(old.localMetadata)
          .insert(LocalMetadataCompanion.insert(key: e.key, value: e.value));
    }
    final pack = localExamPackages.first;
    await old
        .into(old.localExamAttempts)
        .insert(
          LocalExamAttemptsCompanion.insert(
            id: 'legacy-exam',
            packageId: pack.id,
            packageVersion: pack.version,
            targetLevel: 1,
            mode: LocalExamMode.readingPractice.name,
            questionsJson: jsonEncode(
              pack.questions
                  .where((q) => q.section == ExamSection.reading)
                  .map((q) => q.toJson())
                  .toList(),
            ),
            startedAt: practiceNow,
            deadline: practiceNow.add(const Duration(minutes: 20)),
            submittedAt: Value(practiceNow),
            correctCount: const Value(0),
          ),
        );
    await old.close();
    final migrated = DriftLocalRepository(
      LocalDatabase(NativeDatabase(file)),
      clock: () => practiceNow,
    );
    addTearDown(migrated.close);
    final loaded = await migrated.load();
    expect(loaded.revision, 7);
    expect(loaded.words.single.note, 'Ghi chú cũ');
    expect(loaded.exams.attempts.single.id, 'legacy-exam');
    expect(loaded.exams.attempts.single.correctCount, 0);
    expect(loaded.practice, isEmpty);
    await migrated.savePractice(writing(), revision: 7, operationId: 'new');
    expect((await migrated.load()).practice.length, 1);
  });
  test('published snapshots are deeply immutable and bad audio reference types cannot be stored', () async {
    final e = writing();
    expect(() => (e.data['strokes'] as List).clear(), throwsUnsupportedError);
    final audio = sound();
    expect(() => audio.bytes[0] = 0, throwsUnsupportedError);
    final talk = conversation();
    await expectLater(
      save(talk.copy(data: {...talk.data, 'draftAudioId': 42}), 'bad-ref'),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.load()).practice, isEmpty);
  });
  test(
    'a full 1000-media library cannot create an archive it cannot restore',
    () async {
      final pic = picture(), hash = sha256.convert(picture().bytes).toString();
      await repo.db.batch((b) {
        for (var i = 0; i < 1000; i++) {
          b.insert(
            repo.db.localMedia,
            LocalMediaCompanion.insert(
              id: 'image-$i',
              mime: pic.mime,
              bytes: pic.bytes,
              checksum: hash,
              createdAt: practiceNow,
            ),
          );
          b.insert(
            repo.db.localPracticeEntries,
            LocalPracticeEntriesCompanion.insert(
              id: 'photo-$i',
              kind: 'photo',
              dataJson: jsonEncode({
                'original': '',
                'text': '字',
                'imageId': 'image-$i',
              }),
              createdAt: practiceNow,
              updatedAt: practiceNow,
            ),
          );
        }
      });
      await expectLater(
        save(photo(), 'overflow', media: [picture()]),
        throwsA(isA<LocalDataException>()),
      );
      final current = await repo.load();
      expect(current.media.length, 1000);
      expect(current.revision, data.revision);
      final archive = await repo.exportArchive();
      data = await repo.restoreArchive(
        archive,
        revision: current.revision,
        operationId: 'boundary-restore',
      );
      expect(data.media.length, 1000);
      expect(data.practice.length, 1000);
    },
  );
  test(
    'invalid backup references are rejected before destructive SQL begins',
    () async {
      await save(photo(), 'photo', media: [picture()]);
      final decoded = PracticeArchive.decode(await repo.exportArchive());
      (decoded.data['practice'] as List).first['data']['imageId'] = 'missing';
      final broken = PracticeArchive.encode(decoded.data, decoded.media);
      await repo.db.customStatement(
        "CREATE TRIGGER no_delete BEFORE DELETE ON local_practice_entries BEGIN SELECT RAISE(ABORT, 'destructive SQL reached'); END",
      );
      await expectLater(
        repo.restoreArchive(
          broken,
          revision: data.revision,
          operationId: 'invalid-preflight',
        ),
        throwsA(
          isA<LocalDataException>().having(
            (e) => e.message.toLowerCase(),
            'preflight reference error',
            contains('tham chiếu media'),
          ),
        ),
      );
      expect((await repo.load()).practice.single.id, 'photo');
      await repo.db.customStatement('DROP TRIGGER no_delete');
    },
  );
  test('legacy import cannot introduce an unsupported HSK goal', () async {
    final legacy =
        jsonDecode(await repo.exportBackup()) as Map<String, dynamic>;
    legacy['preferences']['level'] = 4;
    await expectLater(
      repo.restoreBackup(
        jsonEncode(legacy),
        revision: data.revision,
        operationId: 'bad-hsk',
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.load()).preferences.level, 1);
    expect((await repo.load()).revision, data.revision);
  });
  test(
    'invalid review and exam data are preflighted before deletion',
    () async {
      await save(photo(), 'existing-photo', media: [picture()]);
      data = await repo.startExam(
        'local-level-1',
        LocalExamMode.readingPractice,
        revision: data.revision,
        operationId: 'existing-exam',
      );
      final source = await repo.exportBackup();
      await repo.db.customStatement(
        "CREATE TRIGGER no_delete BEFORE DELETE ON local_practice_entries BEGIN SELECT RAISE(ABORT, 'destructive SQL reached'); END",
      );
      final review = jsonDecode(source) as Map<String, dynamic>;
      review['review']['events'] = [
        {'sessionId': 'missing'},
      ];
      await expectLater(
        repo.restoreBackup(
          jsonEncode(review),
          revision: data.revision,
          operationId: 'bad-review',
        ),
        throwsA(
          isA<LocalDataException>().having(
            (e) => e.message,
            'review preflight',
            contains('lịch sử ôn'),
          ),
        ),
      );
      final exam = jsonDecode(source) as Map<String, dynamic>;
      (exam['exams'] as List).first['deadline'] = 'bad-date';
      await expectLater(
        repo.restoreBackup(
          jsonEncode(exam),
          revision: data.revision,
          operationId: 'bad-exam',
        ),
        throwsA(
          isA<LocalDataException>().having(
            (e) => e.message,
            'exam preflight',
            contains('Bài thi'),
          ),
        ),
      );
      expect((await repo.load()).revision, data.revision);
      expect((await repo.load()).practice.length, 1);
      await repo.db.customStatement('DROP TRIGGER no_delete');
    },
  );
  test('WAV encoding obeys content and duration limits', () {
    validateMedia(sound());
    expect(
      () => validateMedia(
        LocalMediaInput(
          id: 'too-long',
          mime: 'audio/wav',
          bytes: pcmToWav(Uint8List(1920002)),
        ),
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => validateMedia(
        LocalMediaInput(
          id: 'empty',
          mime: 'audio/wav',
          bytes: pcmToWav(Uint8List(0)),
        ),
      ),
      throwsA(isA<LocalDataException>()),
    );
  });
}
