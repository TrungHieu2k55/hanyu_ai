import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/admin/application/vocabulary_import_controller.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_revision.dart';
import 'package:doanchuyennganh2/features/admin/domain/vocabulary_import.dart';

const mapping = VocabularyColumnMapping(hanzi: 0, pinyin: 1, vietnamese: 2);
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late LocalAdminRepository repo;
  setUp(
    () => repo = LocalAdminRepository(LocalDatabase(NativeDatabase.memory())),
  );
  tearDown(() => repo.close());
  test('BOM/quoted commas/newlines/escaped quotes produce durable unreviewed drafts', () async {
    await repo.loadSnapshot();
    final preview = await repo.previewCsv(
      '\ufeffh,p,v\r\n你好,nǐ hǎo,"xin chào, bạn"\r\n学习,xuéxí,"học\r\ntập ""mới"""',
      mapping,
    );
    final done = await repo.commitCsv(
      preview,
      skipInvalid: false,
      operationId: 'quoted',
    );
    expect(done.content, hasLength(2));
    expect(done.imports.single.acceptedCount, 2);
    expect(
      done.content.every(
        (r) =>
            r.state == ContentState.draft &&
            r.review.status == ReviewStatus.unreviewed &&
            r.source.isEmpty &&
            r.license.isEmpty,
      ),
      true,
    );
    expect(
      done.content.map((r) => (r.payload as VocabularyContent).vietnamese),
      contains('học\ntập "mới"'),
    );
  });
  test('partial input requires explicit opt in; source bounds and duplicates have row issues', () async {
    await repo.loadSnapshot();
    final preview = await repo.previewCsv(
      'h,p,v\n早上,zǎoshang,sáng\n晚上,,tối\n早上,ZǍOSHANG,trùng\n${'人' * 31},rén,dài',
      mapping,
    );
    expect(preview.report.drafts, hasLength(1));
    expect(preview.report.rejectedRecords, 3);
    await expectLater(
      repo.commitCsv(preview, skipInvalid: false, operationId: 'must-confirm'),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.loadSnapshot()).content, isEmpty);
    final done = await repo.commitCsv(
      preview,
      skipInvalid: true,
      operationId: 'partial',
    );
    expect(done.content, hasLength(1));
    expect(done.imports.single.skippedRows, 3);
    expect(done.imports.single.totalRows, 4);
  });
  test('stale preview and in-transaction duplicate recheck never overwrite current data', () async {
    var s = await repo.loadSnapshot();
    final preview = await repo.previewCsv('h,p,v\n朋友,péngyou,bạn', mapping);
    s = await repo.saveRevision(
      id: const Uuid().v4(),
      baseRevision: 0,
      payload: VocabularyContent(
        hanzi: '朋友',
        pinyin: 'péngyou',
        vietnamese: 'bản có trước',
      ),
      revision: s.revision,
      operationId: 'other',
    );
    await expectLater(
      repo.commitCsv(preview, skipInvalid: false, operationId: 'stale'),
      throwsA(isA<LocalConflict>()),
    );
    final current = await repo.previewCsv(
      'h,p,v\n朋友,péngyou,bạn\n学习,xuéxí,học',
      mapping,
    );
    expect(current.report.drafts, hasLength(1));
    expect(current.report.rejectedRecords, 1);
    final emptyPreview = await repo.previewCsv(
      'h,p,v\n早上,zǎoshang,sáng',
      mapping,
    );
    // Fault-injected writer bypasses CAS; commit must still recheck duplicate keys.
    await repo.contentStore.save(
      id: const Uuid().v4(),
      baseRevision: 0,
      payload: VocabularyContent(
        hanzi: '早上',
        pinyin: 'zǎoshang',
        vietnamese: 'đã có',
      ),
    );
    await expectLater(
      repo.commitCsv(emptyPreview, skipInvalid: false, operationId: 'recheck'),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.loadSnapshot()).content, hasLength(2));
    expect((await repo.loadSnapshot()).imports, isEmpty);
  });
  test('SQL failure rolls back every draft/counter/summary/receipt; same intent retries once', () async {
    await repo.loadSnapshot();
    final preview = await repo.previewCsv(
      'h,p,v\n早上,zǎoshang,sáng\n晚上,wǎnshang,tối',
      mapping,
    );
    await repo.db.customStatement(
      r"CREATE TRIGGER fail_csv BEFORE INSERT ON local_admin_revisions WHEN json_extract(NEW.data_json,'$.payload.hanzi')='晚上' BEGIN SELECT RAISE(ABORT,'full'); END",
    );
    await expectLater(
      repo.commitCsv(preview, skipInvalid: false, operationId: 'retry'),
      throwsA(anything),
    );
    final intact = await repo.loadSnapshot();
    expect(intact.content, isEmpty);
    expect(intact.imports, isEmpty);
    expect(intact.revision, preview.revision);
    expect(await repo.db.select(repo.db.localReceipts).get(), isEmpty);
    await repo.db.customStatement('DROP TRIGGER fail_csv');
    final done = await repo.commitCsv(
      preview,
      skipInvalid: false,
      operationId: 'retry',
    );
    final again = await repo.commitCsv(
      preview,
      skipInvalid: false,
      operationId: 'retry',
    );
    expect(again.revision, done.revision);
    expect(again.content, hasLength(2));
    expect(again.imports, hasLength(1));
    await expectLater(
      repo.commitCsv(preview, skipInvalid: true, operationId: 'retry'),
      throwsA(isA<LocalDataException>()),
    );
  });
  test('controller completes only after persistence; double tap and lost response retry keep one batch', () async {
    await repo.loadSnapshot();
    var first = true;
    final gate = Completer<void>();
    final controller = VocabularyImportController(
      repository: repo,
      persist: (p, skip, op) async {
        await gate.future;
        final snapshot = await repo.commitCsv(
          p,
          skipInvalid: skip,
          operationId: op,
        );
        if (first) {
          first = false;
          throw StateError('lost response');
        }
        return snapshot;
      },
    );
    addTearDown(controller.dispose);
    controller.updateContent('h,p,v\n早上,zǎoshang,sáng');
    controller.parse();
    await controller.validate();
    controller.next();
    final pending = controller.complete();
    expect(controller.committed, false);
    expect(controller.step, ImportStep.confirmation);
    expect(await controller.complete(), isNull);
    gate.complete();
    expect(await pending, isNull);
    expect(controller.committed, false);
    expect((await repo.loadSnapshot()).content, hasLength(1));
    final result = await controller.complete();
    expect(result!.acceptedCount, 1);
    expect(controller.committed, true);
    expect(controller.step, ImportStep.result);
    expect((await repo.loadSnapshot()).content, hasLength(1));
    expect((await repo.loadSnapshot()).imports, hasLength(1));
  });
  test('mapping is part of preview and canonical duplicate key has no delimiter collision', () async {
    await repo.loadSnapshot();
    final p = await repo.previewCsv(
      'v,h,p\nbạn,人|a,b\nngười,人,a|b',
      const VocabularyColumnMapping(hanzi: 1, pinyin: 2, vietnamese: 0),
    );
    expect(p.report.drafts, hasLength(2));
    final done = await repo.commitCsv(
      p,
      skipInvalid: false,
      operationId: 'mapping',
    );
    expect(done.content, hasLength(2));
    await expectLater(
      repo.previewCsv(
        'h,p,v\n人,rén,người',
        const VocabularyColumnMapping(hanzi: 0, pinyin: 0, vietnamese: 2),
      ),
      throwsA(isA<CsvImportProblem>()),
    );
  });
  test('file backed batch summary and receipt survive close, backup/restore and replay', () async {
    final dir = await Directory.systemTemp.createTemp('hanyu-csv-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/admin.sqlite');
    final first = LocalAdminRepository(LocalDatabase(NativeDatabase(file)));
    await first.loadSnapshot();
    final preview = await first.previewCsv('h,p,v\n早上,zǎoshang,sáng', mapping);
    await first.commitCsv(preview, skipInvalid: false, operationId: 'persist');
    final backup = await first.exportBackup();
    await first.close();
    final next = LocalAdminRepository(LocalDatabase(NativeDatabase(file)));
    addTearDown(next.close);
    final reopened = await next.loadSnapshot();
    expect(reopened.imports.single.operationId, 'persist');
    var target = await repo.loadSnapshot();
    target = await repo.restoreBackup(
      repo.prepareBackupRestore(backup),
      revision: target.revision,
      operationId: 'restore',
    );
    final again = await repo.commitCsv(
      preview,
      skipInvalid: false,
      operationId: 'persist',
    );
    expect(again.content, hasLength(1));
    expect(again.revision, target.revision);
  });
  test('1,000 rows fit, 1,001 and UTF-8 size overflow fail before mutation', () async {
    await repo.loadSnapshot();
    final input =
        'h,p,v\n${List.generate(1000, (i) => '字$i,zì $i,nghĩa $i').join('\n')}';
    final preview = await repo.previewCsv(input, mapping);
    expect(preview.report.drafts, hasLength(1000));
    final done = await repo.commitCsv(
      preview,
      skipInvalid: false,
      operationId: 'thousand',
    );
    expect(done.content, hasLength(1000));
    await expectLater(
      repo.previewCsv('$input\n字1000,zì 1000,nghĩa', mapping),
      throwsA(isA<CsvImportProblem>()),
    );
    await expectLater(
      repo.previewCsv('h,p,v\n人,rén,${'人' * 180000}', mapping),
      throwsA(isA<CsvImportProblem>()),
    );
    expect((await repo.loadSnapshot()).content, hasLength(1000));
  });
}
