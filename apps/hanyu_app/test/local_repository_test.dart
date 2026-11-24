import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

VocabularyItem word([String id = 'personal:test']) => VocabularyItem(
  id: id,
  level: null,
  personal: true,
  hanzi: '雨伞',
  pinyin: 'yǔsǎn',
  vietnamese: 'ô đi mưa',
  exampleHanzi: '',
  exampleVietnamese: '',
);

void main() {
  // File and in-memory test executors are independent and explicitly closed.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late DriftLocalRepository repository;
  setUp(
    () => repository = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
    ),
  );
  tearDown(() => repository.close());

  test(
    'seed is versioned once, reopening does not reset private data',
    () async {
      final first = await repository.load();
      final saved = await repository.saveNote(
        first.words.first.entry.id,
        'Ghi chú riêng',
        revision: first.revision,
        operationId: 'note',
      );
      final reopened = await repository.load();
      expect(reopened.words.length, first.words.length);
      expect(reopened.revision, saved.revision);
      expect(reopened.words.first.note, 'Ghi chú riêng');
    },
  );

  test(
    'file-backed word saved flag and note survive closing database',
    () async {
      final dir = await Directory.systemTemp.createTemp('hanyu-persistence-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/test.sqlite');
      final local = DriftLocalRepository(LocalDatabase(NativeDatabase(file)));
      var data = await local.load();
      data = await local.putWord(
        word(),
        revision: data.revision,
        operationId: 'create',
      );
      data = await local.saveWord(
        word().id,
        true,
        revision: data.revision,
        operationId: 'save',
      );
      await local.saveNote(
        word().id,
        'Ghi chú sau mở lại',
        revision: data.revision,
        operationId: 'note',
      );
      await local.close();
      final next = DriftLocalRepository(LocalDatabase(NativeDatabase(file)));
      addTearDown(next.close);
      final reloaded = await next.load();
      expect(reloaded.find(word().id)!.saved, isTrue);
      expect(reloaded.find(word().id)!.note, 'Ghi chú sau mở lại');
    },
  );

  test(
    'same receipt is idempotent and different payload is rejected',
    () async {
      final initial = await repository.load();
      final first = await repository.putWord(
        word(),
        revision: initial.revision,
        operationId: 'same',
      );
      final duplicate = await repository.putWord(
        word(),
        revision: initial.revision,
        operationId: 'same',
      );
      expect(duplicate.revision, first.revision);
      expect(duplicate.words.where((w) => w.entry.personal), hasLength(1));
      await expectLater(
        repository.saveWord(
          word().id,
          true,
          revision: first.revision,
          operationId: 'same',
        ),
        throwsA(isA<LocalDataException>()),
      );
    },
  );

  test('stale writer cannot overwrite a committed change', () async {
    final initial = await repository.load();
    await repository.saveNote(
      initial.words.first.entry.id,
      'First writer',
      revision: initial.revision,
      operationId: 'a',
    );
    await expectLater(
      repository.saveNote(
        initial.words.first.entry.id,
        'Stale writer',
        revision: initial.revision,
        operationId: 'b',
      ),
      throwsA(isA<LocalConflict>()),
    );
    expect((await repository.load()).words.first.note, 'First writer');
  });

  test(
    'write failure rolls back revision and allows same operation retry',
    () async {
      final initial = await repository.load();
      await repository.db.customStatement(
        "CREATE TRIGGER fail_note BEFORE UPDATE OF note ON local_words BEGIN SELECT RAISE(ABORT, 'storage failure'); END",
      );
      await expectLater(
        repository.saveNote(
          initial.words.first.entry.id,
          'Draft',
          revision: initial.revision,
          operationId: 'retry',
        ),
        throwsA(anything),
      );
      expect((await repository.load()).revision, initial.revision);
      await repository.db.customStatement('DROP TRIGGER fail_note');
      final committed = await repository.saveNote(
        initial.words.first.entry.id,
        'Draft',
        revision: initial.revision,
        operationId: 'retry',
      );
      expect(committed.words.first.note, 'Draft');
    },
  );

  test(
    'editing preserves saved state and note, duplicates do not create rows',
    () async {
      var data = await repository.load();
      data = await repository.putWord(
        word(),
        revision: data.revision,
        operationId: 'create',
      );
      data = await repository.saveWord(
        word().id,
        true,
        revision: data.revision,
        operationId: 'save',
      );
      data = await repository.saveNote(
        word().id,
        'Own note',
        revision: data.revision,
        operationId: 'note',
      );
      final edited = VocabularyItem(
        id: word().id,
        level: null,
        personal: true,
        hanzi: '雨伞',
        pinyin: 'yǔsǎn',
        vietnamese: 'ô',
        exampleHanzi: '',
        exampleVietnamese: '',
      );
      data = await repository.putWord(
        edited,
        revision: data.revision,
        operationId: 'edit',
      );
      expect(data.find(word().id)!.saved, isTrue);
      expect(data.find(word().id)!.note, 'Own note');
      await expectLater(
        repository.putWord(
          word('personal:other'),
          revision: data.revision,
          operationId: 'duplicate',
        ),
        throwsA(isA<LocalDataException>()),
      );
    },
  );

  test('backup roundtrip is atomic and does not replay old receipts', () async {
    var data = await repository.load();
    data = await repository.putWord(
      word(),
      revision: data.revision,
      operationId: 'create',
    );
    data = await repository.saveNote(
      word().id,
      'Backed up',
      revision: data.revision,
      operationId: 'note',
    );
    final backup = await repository.exportBackup();
    data = await repository.deleteWord(
      word().id,
      revision: data.revision,
      operationId: 'delete',
    );
    data = await repository.restoreBackup(
      backup,
      revision: data.revision,
      operationId: 'restore',
    );
    expect(data.find(word().id)!.note, 'Backed up');
    expect(
      (await repository.restoreBackup(
        backup,
        revision: data.revision - 1,
        operationId: 'restore',
      )).revision,
      data.revision,
    );
  });

  test('invalid backups leave current data intact', () async {
    final initial = await repository.load();
    final payload =
        jsonDecode(await repository.exportBackup()) as Map<String, dynamic>;
    payload['words'] = [payload['words'][0], payload['words'][0]];
    for (final backup in [
      'not json',
      jsonEncode({'format': 'other'}),
      jsonEncode(payload),
    ]) {
      await expectLater(
        repository.restoreBackup(
          backup,
          revision: initial.revision,
          operationId: 'invalid',
        ),
        throwsA(isA<LocalDataException>()),
      );
      expect((await repository.load()).revision, initial.revision);
    }
  });

  test('preferences are validated and survive reload', () async {
    final initial = await repository.load();
    await repository.savePreferences(
      const LocalPreferences(name: 'Hiếu', level: 2, minutes: 20, sound: false),
      revision: initial.revision,
      operationId: 'settings',
    );
    final result = await repository.load();
    expect(result.preferences.name, 'Hiếu');
    expect(result.preferences.sound, isFalse);
    await expectLater(
      repository.savePreferences(
        const LocalPreferences(level: 8),
        revision: result.revision,
        operationId: 'bad-settings',
      ),
      throwsA(isA<LocalDataException>()),
    );
  });
}
