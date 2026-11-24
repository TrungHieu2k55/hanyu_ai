import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/core/files/local_file_transfer.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/features/support/domain/local_feedback.dart';
import 'package:doanchuyennganh2/features/admin/domain/local_admin.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late DriftLocalRepository learner;
  late LocalAdminRepository admin;
  late String id;
  final now = DateTime.utc(2026, 11, 22, 8);
  setUp(() {
    id = const Uuid().v4();
    learner = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => now,
    );
    admin = LocalAdminRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => now.add(const Duration(minutes: 1)),
    );
  });
  tearDown(() async {
    await learner.close();
    await admin.close();
  });

  Future<FeedbackReport> save({
    String body = 'Nghĩa từ cần kiểm tra',
    bool draft = false,
  }) async {
    final s = await learner.load();
    return (await learner.saveFeedback(
      id: id,
      reportRevision: 0,
      body: body,
      draft: draft,
      context: FeedbackContext({
        'contentId': 'word:1',
        'contentVersion': 'sample-v1',
        'label': '朋友',
        'route': '/words/word:1',
      }),
      revision: s.revision,
      operationId: 'save',
    )).feedback.single;
  }

  Future<LocalJsonFile> exported(FeedbackReport report) async {
    var s = await learner.load();
    s = await learner.prepareFeedbackExport(
      id,
      report.revision,
      revision: s.revision,
      operationId: 'prepare',
    );
    final file = await learner.feedbackExportFile(id, report.revision);
    await learner.markFeedbackExported(
      id,
      report.revision,
      report.checksum,
      revision: s.revision,
      operationId: 'export',
    );
    return file;
  }

  test(
    'two independent DBs complete file handoff, duplicate and result loop',
    () async {
      final report = await save();
      final file = await exported(report);
      var a = await admin.loadSnapshot();
      final parsed = FeedbackReport.fromFile(file);
      a = await admin.importFeedback(
        parsed,
        revision: a.revision,
        operationId: 'receive',
      );
      final duplicate = await admin.importFeedback(
        parsed,
        revision: a.revision,
        operationId: 'receive-again',
      );
      expect(duplicate.inbox, hasLength(1));
      a = await admin.updateInbox(
        id,
        1,
        InboxStatus.inProgress,
        revision: duplicate.revision,
        operationId: 'triage',
      );
      a = await admin.updateInbox(
        id,
        1,
        InboxStatus.closed,
        resolution: 'Đã ghi nhận để kiểm tra học liệu.',
        actorLabel: 'Nhóm học liệu',
        revision: a.revision,
        operationId: 'close',
      );
      expect((await learner.load()).feedback.single.outcome, isNull);
      final receipt = await learner.previewFeedbackReceipt(
        await admin.exportFeedbackReceipt(id, 1),
      );
      final current = await learner.load();
      final done = await learner.importFeedbackReceipt(
        receipt,
        revision: current.revision,
        operationId: 'result',
      );
      expect(done.feedback.single.state, FeedbackState.resolvedImported);
      expect(done.feedback.single.outcome!.actorLabel, 'Nhóm học liệu');
      final again = await learner.importFeedbackReceipt(
        receipt,
        revision: done.revision,
        operationId: 'result-again',
      );
      expect(again.feedback, hasLength(1));
      expect(
        await learner.db.select(learner.db.localAdminInbox).get(),
        isEmpty,
      );
      expect(await admin.db.select(admin.db.localWords).get(), isEmpty);
    },
  );

  test('pin freezes bytes before handoff; edits create a new revision even after cancel', () async {
    final report = await save();
    var data = await learner.load();
    data = await learner.prepareFeedbackExport(
      id,
      1,
      revision: data.revision,
      operationId: 'prepare',
    );
    final file = await learner.feedbackExportFile(id, 1);
    expect(data.feedback.single.state, FeedbackState.recorded);
    data = await learner.saveFeedback(
      id: id,
      reportRevision: 1,
      body: 'Bản sửa',
      context: report.context,
      revision: data.revision,
      operationId: 'edit',
    );
    expect(data.feedback, hasLength(2));
    expect(data.feedback.first.revision, 2);
    expect(
      (await learner.feedbackExportFile(id, 1)).bytes,
      orderedEquals(file.bytes),
    );
    await expectLater(
      learner.saveFeedback(
        id: id,
        reportRevision: 1,
        body: 'Ghi đè bản cũ',
        revision: data.revision,
        operationId: 'stale-report',
      ),
      throwsA(isA<LocalConflict>()),
    );
  });

  test(
    'blank drafts persist but cannot export; complete report validates bounds',
    () async {
      final draft = await save(body: '', draft: true);
      expect(draft.state, FeedbackState.draft);
      final s = await learner.load();
      await expectLater(
        learner.prepareFeedbackExport(
          id,
          1,
          revision: s.revision,
          operationId: 'invalid',
        ),
        throwsA(isA<LocalDataException>()),
      );
      await expectLater(
        learner.saveFeedback(
          id: const Uuid().v4(),
          reportRevision: 0,
          body: '人' * 2001,
          revision: s.revision,
          operationId: 'long',
        ),
        throwsA(isA<LocalDataException>()),
      );
      expect(
        () => FeedbackContext({'note': 'private'}),
        throwsA(isA<LocalDataException>()),
      );
      expect(
        () => FeedbackContext({'label': '人' * 1000}),
        throwsA(isA<LocalDataException>()),
      );
    },
  );

  test(
    'tampered report, wrong format and unknown fields are rejected before DB',
    () async {
      final report = await save();
      final file = report.toFile();
      final json = jsonDecode(file.text) as Map<String, dynamic>;
      (json['report'] as Map)['body'] = 'Changed';
      expect(
        () => FeedbackReport.fromFile(
          LocalJsonFile.fromBytes(
            utf8.encode(jsonEncode(json)),
            name: 'bad.json',
            kind: LocalJsonKind.feedback,
          ),
        ),
        throwsA(isA<LocalDataException>()),
      );
      json['format'] = 'hanyu-content-package';
      expect(
        () => FeedbackReport.fromFile(
          LocalJsonFile.fromBytes(
            utf8.encode(jsonEncode(json)),
            name: 'bad.json',
            kind: LocalJsonKind.feedback,
          ),
        ),
        throwsA(isA<LocalDataException>()),
      );
      final foreign = jsonDecode(file.text) as Map<String, dynamic>;
      foreign['media'] = 'secret';
      expect(
        () => FeedbackReport.fromFile(
          LocalJsonFile.fromBytes(
            utf8.encode(jsonEncode(foreign)),
            name: 'bad.json',
            kind: LocalJsonKind.feedback,
          ),
        ),
        throwsA(isA<LocalDataException>()),
      );
      expect((await admin.loadSnapshot()).inbox, isEmpty);
    },
  );

  test('same key with changed valid checksum conflicts; higher revision stays separate', () async {
    final report = await save();
    var a = await admin.loadSnapshot();
    a = await admin.importFeedback(
      report,
      revision: a.revision,
      operationId: 'first',
    );
    final changed = FeedbackReport.create(
      id: id,
      revision: 1,
      body: 'Khác',
      createdAt: now,
      updatedAt: now,
      state: FeedbackState.recorded,
    );
    await expectLater(
      admin.importFeedback(
        changed,
        revision: a.revision,
        operationId: 'conflict',
      ),
      throwsA(isA<LocalDataException>()),
    );
    final next = FeedbackReport.create(
      id: id,
      revision: 2,
      body: 'Bản mới',
      createdAt: now,
      updatedAt: now,
      state: FeedbackState.recorded,
    );
    a = await admin.importFeedback(
      next,
      revision: a.revision,
      operationId: 'next',
    );
    expect(a.inbox, hasLength(2));
    expect(a.inbox.every((i) => i.status == InboxStatus.open), isTrue);
  });

  test('receipt rejects old version, other report, altered checksum and conflicting outcome', () async {
    final report = await save();
    final wrong = FeedbackReceipt(
      reportId: id,
      reportRevision: 2,
      reportChecksum: report.checksum,
      resolution: 'Đã xem',
      actorLabel: 'A',
      closedAt: now,
    );
    final s = await learner.load();
    await expectLater(
      learner.importFeedbackReceipt(
        wrong,
        revision: s.revision,
        operationId: 'wrong',
      ),
      throwsA(isA<LocalDataException>()),
    );
    final good = FeedbackReceipt(
      reportId: id,
      reportRevision: 1,
      reportChecksum: report.checksum,
      resolution: 'Đã xem',
      actorLabel: 'A',
      closedAt: now,
    );
    final committed = await learner.importFeedbackReceipt(
      good,
      revision: s.revision,
      operationId: 'good',
    );
    final altered = FeedbackReceipt(
      reportId: id,
      reportRevision: 1,
      reportChecksum: report.checksum,
      resolution: 'Ghi đè',
      actorLabel: 'B',
      closedAt: now,
    );
    await expectLater(
      learner.importFeedbackReceipt(
        altered,
        revision: committed.revision,
        operationId: 'altered',
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      (await learner.load()).feedback.single.outcome!.resolution,
      'Đã xem',
    );
  });

  test(
    'failed learner/Admin writes roll back revision and retry same intent',
    () async {
      var s = await learner.load();
      await learner.db.customStatement(
        "CREATE TRIGGER fail_feedback BEFORE INSERT ON local_feedback_reports BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await expectLater(
        learner.saveFeedback(
          id: id,
          reportRevision: 0,
          body: 'Nháp',
          revision: s.revision,
          operationId: 'retry',
        ),
        throwsA(anything),
      );
      expect((await learner.load()).feedback, isEmpty);
      expect((await learner.load()).revision, s.revision);
      await learner.db.customStatement('DROP TRIGGER fail_feedback');
      s = await learner.saveFeedback(
        id: id,
        reportRevision: 0,
        body: 'Nháp',
        revision: s.revision,
        operationId: 'retry',
      );
      var a = await admin.loadSnapshot();
      await admin.db.customStatement(
        "CREATE TRIGGER fail_inbox BEFORE INSERT ON local_admin_inbox BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await expectLater(
        admin.importFeedback(
          s.feedback.single,
          revision: a.revision,
          operationId: 'retry',
        ),
        throwsA(anything),
      );
      expect((await admin.loadSnapshot()).revision, a.revision);
      await admin.db.customStatement('DROP TRIGGER fail_inbox');
      a = await admin.importFeedback(
        s.feedback.single,
        revision: a.revision,
        operationId: 'retry',
      );
      expect(a.inbox, hasLength(1));
      await expectLater(
        admin.updateInbox(
          id,
          1,
          InboxStatus.closed,
          resolution: '',
          actorLabel: '',
          revision: a.revision,
          operationId: 'empty',
        ),
        throwsA(isA<LocalDataException>()),
      );
      expect(
        (await admin.loadSnapshot()).inbox.single.status,
        InboxStatus.open,
      );
    },
  );

  test('file backed learner report, pin and Admin closed receipt survive reopening', () async {
    final dir = await Directory.systemTemp.createTemp('hanyu-e-feedback-');
    addTearDown(() => dir.delete(recursive: true));
    final lfile = File('${dir.path}/learner.sqlite'),
        afile = File('${dir.path}/admin.sqlite');
    final l = DriftLocalRepository(
      LocalDatabase(NativeDatabase(lfile)),
      clock: () => now,
    );
    final a = LocalAdminRepository(
      LocalDatabase(NativeDatabase(afile)),
      clock: () => now,
    );
    var s = await l.load();
    s = await l.saveFeedback(
      id: id,
      reportRevision: 0,
      body: 'Bản lưu',
      revision: s.revision,
      operationId: 'save',
    );
    s = await l.prepareFeedbackExport(
      id,
      1,
      revision: s.revision,
      operationId: 'pin',
    );
    final file = await l.feedbackExportFile(id, 1);
    var data = await a.loadSnapshot();
    data = await a.importFeedback(
      FeedbackReport.fromFile(file),
      revision: data.revision,
      operationId: 'receive',
    );
    await a.updateInbox(
      id,
      1,
      InboxStatus.closed,
      resolution: 'Đã xem',
      actorLabel: 'Nhóm',
      revision: data.revision,
      operationId: 'close',
    );
    await l.close();
    await a.close();
    final l2 = DriftLocalRepository(LocalDatabase(NativeDatabase(lfile)));
    final a2 = LocalAdminRepository(LocalDatabase(NativeDatabase(afile)));
    addTearDown(l2.close);
    addTearDown(a2.close);
    expect((await l2.load()).feedback.single.body, 'Bản lưu');
    expect(
      (await l2.feedbackExportFile(id, 1)).bytes,
      orderedEquals(file.bytes),
    );
    expect((await a2.loadSnapshot()).inbox.single.status, InboxStatus.closed);
    expect(
      await l2.previewFeedbackReceipt(await a2.exportFeedbackReceipt(id, 1)),
      isA<FeedbackReceipt>(),
    );
  });
  test(
    'inbox prospective 8 MiB limit rolls back insertion and receipt',
    () async {
      final report = await save();
      final data = await admin.loadSnapshot();
      await admin.db.customStatement(
        'INSERT INTO local_metadata (key,value) VALUES (?,?)',
        ['capacity-fixture', 'x' * (8 * 1024 * 1024)],
      );
      await expectLater(
        admin.importFeedback(
          report,
          revision: data.revision,
          operationId: 'capacity',
        ),
        throwsA(isA<LocalDataException>()),
      );
      expect((await admin.loadSnapshot()).inbox, isEmpty);
      expect((await admin.loadSnapshot()).revision, data.revision);
      expect(await admin.db.select(admin.db.localReceipts).get(), isEmpty);
    },
  );
}
