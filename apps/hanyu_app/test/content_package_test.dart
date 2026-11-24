import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/core/local/practice_archive.dart';
import 'package:doanchuyennganh2/features/admin/data/admin_package_store.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/content/application/learning_catalog.dart';
import 'package:doanchuyennganh2/features/content/domain/content_package.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';

import 'content_package_contract_test.dart' as fixture;
import 'support/practice_fixtures.dart' as practice;

import 'package:doanchuyennganh2/features/exam/data/local_exam_packages.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late DriftLocalRepository learner;
  setUp(
    () =>
        learner = DriftLocalRepository(LocalDatabase(NativeDatabase.memory())),
  );
  tearDown(() => learner.close());
  final rejected = throwsA(isA<LocalDataException>());

  test(
    'Admin to learner handoff, retained progress, downgrade and v5 restore',
    () async {
      final admin = LocalAdminRepository(
        LocalDatabase(NativeDatabase.memory()),
      );
      addTearDown(admin.close);
      var a = await admin.loadSnapshot();
      final item = fixture.uid(100), packageId = fixture.uid(200);
      a = await admin.saveRevision(
        id: item,
        baseRevision: 0,
        payload: fixture.record(100).payload,
        revision: a.revision,
        operationId: 'word',
      );
      final frozen = await admin.preparePackage(
        packageId: packageId,
        mode: PackageMode.trial,
        selection: [PackageSelection(itemId: item, revision: 1)],
      );
      a = await admin.commitPackage(
        frozen,
        acceptTrial: true,
        operationId: 'export',
      );
      final file = await admin.exportPackage(packageId, 1);
      final preview = await learner.preparePackageInstall(file);
      final id = preview.package.wordId(item);
      expect((await learner.load()).find(id), isNull);
      await expectLater(
        learner.installPackage(preview, operationId: 'trial'),
        rejected,
      );
      var state = await learner.installPackage(
        preview,
        operationId: 'install',
        acceptTrial: true,
        activate: true,
      );
      expect(state.catalog.active?.packageId, packageId);
      expect(catalogWords(state).map((w) => w.entry.id), [id]);
      final same = await learner.installPackage(
        preview,
        operationId: 'install',
        acceptTrial: true,
        activate: true,
      );
      expect(same.revision, state.revision);
      state = await learner.saveWord(
        id,
        true,
        revision: state.revision,
        operationId: 'save',
      );
      state = await learner.saveNote(
        id,
        'Ghi chú riêng',
        revision: state.revision,
        operationId: 'note',
      );
      state = await learner.saveHelpSeen(
        'local-help-v1',
        revision: state.revision,
        operationId: 'help',
      );
      state = await learner.saveFeedback(
        id: fixture.uid(888),
        reportRevision: 0,
        body: 'Kiểm tra ví dụ',
        operationId: 'feedback',
        revision: state.revision,
      );
      final updated = ContentPackage.create(
        publisherId: a.identity.publisherId,
        packageId: packageId,
        mode: PackageMode.trial,
        version: 2,
        exportedAt: fixture.now,
        records: [fixture.record(101)],
      );
      final next = await learner.preparePackageInstall(updated.toFile());
      expect(next.removed, {item});
      state = await learner.installPackage(
        next,
        operationId: 'update',
        acceptTrial: true,
      );
      expect(state.find(id)!.note, 'Ghi chú riêng');
      expect(state.find(id)!.saved, isTrue);
      expect(state.catalog.retainedWords, contains(id));
      expect(
        await learner.db.select(learner.db.localSchedules).get(),
        hasLength(1),
      );
      await expectLater(learner.preparePackageInstall(file), rejected);
      state = await learner.startReview(
        revision: state.revision,
        operationId: 'review',
      );
      state = await learner.savePractice(
        practice.photo(),
        media: [practice.picture()],
        revision: state.revision,
        operationId: 'photo',
      );
      final active = state.catalog.activePackageId;
      state = await learner.activatePackage(
        null,
        revision: state.revision,
        operationId: 'sample',
      );
      state = await learner.startExam(
        localExamPackages.first.id,
        LocalExamMode.readingPractice,
        revision: state.revision,
        operationId: 'reading',
      );
      state = await learner.activatePackage(
        active,
        revision: state.revision,
        operationId: 'catalog',
      );
      final bytes = await learner.exportArchive();
      expect(PracticeArchive.decode(bytes).data['version'], 5);
      final dest = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
      addTearDown(dest.close);
      final restored = await dest.restoreArchive(
        bytes,
        revision: (await dest.load()).revision,
        operationId: 'restore',
      );
      expect(restored.find(id)!.note, 'Ghi chú riêng');
      expect(restored.catalog.active!.version, 2);
      expect(restored.catalog.receiptHistory, hasLength(2));
      expect(restored.feedback.single.body, 'Kiểm tra ví dụ');
      expect(restored.helpVersionSeen, 'local-help-v1');
      expect(restored.exams.attempts.single.questions, hasLength(10));
      expect(restored.practice.single.id, 'photo');
      expect(await dest.readMedia('image'), practice.picture().bytes);

      expect(await dest.db.select(dest.db.localSchedules).get(), hasLength(1));
      state = await learner.removePackage(
        packageId,
        revision: state.revision,
        operationId: 'remove',
      );
      expect(state.catalog.active, isNull);
      expect(state.find(id)?.note, 'Ghi chú riêng');
      await expectLater(learner.preparePackageInstall(file), rejected);
      expect(await admin.db.select(admin.db.localWords).get(), isEmpty);
    },
  );

  test('different publisher cannot replace a known package and SQL errors roll back', () async {
    await learner.load();
    final p = fixture.pack();
    final preview = await learner.preparePackageInstall(p.toFile());
    await learner.db.customStatement(
      "CREATE TRIGGER reject_catalog BEFORE INSERT ON local_installed_packages BEGIN SELECT RAISE(ABORT, 'injected'); END",
    );
    await expectLater(
      learner.installPackage(
        preview,
        acceptTrial: true,
        operationId: 'install',
      ),
      throwsA(anything),
    );
    expect((await learner.load()).revision, preview.baseRevision);
    expect((await learner.load()).find(p.wordId(fixture.uid(100))), isNull);
    await learner.db.customStatement('DROP TRIGGER reject_catalog');
    await learner.installPackage(
      preview,
      acceptTrial: true,
      operationId: 'install',
    );
    final foreign = ContentPackage.create(
      publisherId: fixture.uid(999),
      packageId: p.packageId,
      mode: p.mode,
      version: 2,
      exportedAt: p.exportedAt,
      records: p.records,
    );
    await expectLater(
      learner.preparePackageInstall(foreign.toFile()),
      rejected,
    );
  });

  test('reading requires ten slots, retains in-progress questions and blocks full exam', () async {
    QuestionContent question(int i, String prompt) => QuestionContent(
      targetLevel: 1,
      section: 'reading',
      slot: i + 1,
      prompt: prompt,
      choices: ['a', 'b', 'c', 'd'],
      correctIndex: 0,
      explanation: 'Giải thích',
    );
    Future<LocalSnapshot> install(int v, int count, String prompt) async {
      final package = fixture.pack(
        version: v,
        records: List.generate(
          count,
          (i) => fixture.record(500 + i, payload: question(i, prompt)),
        ),
      );
      final preview = await learner.preparePackageInstall(package.toFile());
      return learner.installPackage(
        preview,
        acceptTrial: true,
        activate: true,
        operationId: 'install-$v',
      );
    }

    var s = await install(1, 9, 'Thiếu câu');
    final id = catalogExams(s.catalog).single.id;
    await expectLater(
      learner.startExam(
        id,
        LocalExamMode.readingPractice,
        revision: s.revision,
        operationId: 'missing',
      ),
      rejected,
    );
    s = await install(2, 10, 'Câu đọc cũ');
    await expectLater(
      learner.startExam(
        id,
        LocalExamMode.fullExam,
        revision: s.revision,
        operationId: 'full',
      ),
      rejected,
    );
    s = await learner.startExam(
      id,
      LocalExamMode.readingPractice,
      revision: s.revision,
      operationId: 'read',
    );
    expect(s.exams.attempts.single.questions, hasLength(10));
    s = await install(3, 10, 'Câu đọc mới');
    expect(s.exams.attempts.single.questions.first.prompt, 'Câu đọc cũ');
    expect(
      catalogExams(s.catalog).single.questions.first.prompt,
      'Câu đọc mới',
    );
  });

  test(
    'learner SQLite stores 2245 vocabulary definitions across three packages',
    () async {
      for (var n = 0; n < 3; n++) {
        final p = fixture.pack(
          id: 10 + n,
          records: List.generate(
            n == 2 ? 245 : 1000,
            (i) => fixture.record(100 + n * 1000 + i),
          ),
        );
        final preview = await learner.preparePackageInstall(p.toFile());
        await learner.installPackage(
          preview,
          acceptTrial: true,
          activate: true,
          operationId: 'pack-$n',
        );
      }
      final s = await learner.load();
      expect(s.catalog.managedWordCount, 2245);
      expect(
        s.words.where((w) => w.entry.id.startsWith('content:')),
        hasLength(2245),
      );
      expect(catalogWords(s), hasLength(245));
    },
  );
  test(
    'stale install preview and malformed v5 backup leave stored data unchanged',
    () async {
      final before = await learner.load();
      final preview = await learner.preparePackageInstall(
        fixture.pack().toFile(),
      );
      final snapshot = await learner.saveNote(
        before.words.first.entry.id,
        'Giữ lại ghi chú',
        revision: before.revision,
        operationId: 'note',
      );
      await expectLater(
        learner.installPackage(
          preview,
          acceptTrial: true,
          operationId: 'stale',
        ),
        throwsA(isA<LocalConflict>()),
      );
      final archive = PracticeArchive.decode(await learner.exportArchive());
      final corrupt = PracticeArchive.encode({
        ...archive.data,
        'catalog': {},
      }, archive.media);
      await expectLater(
        learner.restoreArchive(
          corrupt,
          revision: snapshot.revision,
          operationId: 'invalid',
        ),
        rejected,
      );
      final after = await learner.load();
      expect(after.revision, snapshot.revision);
      expect(after.words.first.note, 'Giữ lại ghi chú');
      expect(after.catalog.packages, isEmpty);
    },
  );

  test('legacy ZIP v4 imports through the v5 archive reader', () async {
    final before = await learner.load();
    final snapshot = await learner.saveNote(
      before.words.first.entry.id,
      'Ghi chú v4',
      revision: before.revision,
      operationId: 'old-note',
    );
    final archive = PracticeArchive.decode(await learner.exportArchive());
    final legacyData = {...archive.data, 'version': 4}
      ..remove('catalog')
      ..remove('helpVersionSeen')
      ..remove('feedback')
      ..remove('feedbackPins');
    final restored = await learner.restoreArchive(
      PracticeArchive.encode(legacyData, archive.media),
      revision: snapshot.revision,
      operationId: 'restore-v4',
    );
    expect(restored.words.first.note, 'Ghi chú v4');
    expect(restored.catalog.packages, isEmpty);
  });
}
