import 'package:doanchuyennganh2/features/exam/data/local_exam_packages.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/files/file_transfer_provider.dart';
import 'package:doanchuyennganh2/core/files/local_file_transfer.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/features/admin/local_admin_app.dart';
import 'package:doanchuyennganh2/features/admin/application/local_admin_providers.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/support/domain/local_feedback.dart';

class FeedbackFiles implements LocalFileTransfer {
  LocalJsonFile? next;
  FileHandoff outcome = FileHandoff.handedOff;
  final saved = <LocalJsonFile>[];
  @override
  Future<LocalJsonFile?> pick(LocalJsonKind kind) async {
    final result = next;
    next = null;
    return result;
  }

  @override
  Future<FileHandoff> save(LocalJsonFile file) async {
    saved.add(file);
    return outcome;
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late DriftLocalRepository learner;
  late LocalAdminRepository admin;
  late FeedbackFiles files;
  setUp(() {
    learner = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
    admin = LocalAdminRepository(LocalDatabase(NativeDatabase.memory()));
    files = FeedbackFiles();
  });
  tearDown(() async {
    await learner.close();
    await admin.close();
  });
  Future<void> launch(WidgetTester t, {bool administrator = false}) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    t.view.physicalSize = Size(
      administrator ? 1366 : 360,
      administrator ? 768 : 844,
    );
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = administrator ? 1 : 1.5;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          localRepositoryProvider.overrideWithValue(learner),
          localAdminRepositoryProvider.overrideWithValue(admin),
          localFileTransferProvider.overrideWithValue(files),
        ],
        child: administrator ? const LocalAdminApp() : const LocalHanyuApp(),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String label) async {
    await t.pumpAndSettle();
    final target = find.text(label).last;
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: label);
  }

  void cleanup(WidgetTester t) {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => t.pumpWidget(const SizedBox()));
  }

  testWidgets(
    'source report, canceled export, Admin file preview/close and explicit learner result',
    (t) async {
      cleanup(t);
      var s = await learner.load();
      await learner.saveNote(
        '1',
        'Ghi chú riêng không đính kèm',
        revision: s.revision,
        operationId: 'private',
      );
      await launch(t);
      await tap(t, '你好');
      await tap(t, 'Báo lỗi học liệu');
      await t.enterText(
        find.byKey(const ValueKey('feedback-body')),
        'Kiểm tra nghĩa từ này',
      );
      await tap(t, 'Học');
      await tap(t, 'Ở lại');
      await tap(t, 'Lưu báo lỗi');
      expect(
        (await learner.load()).feedback.single.body,
        'Kiểm tra nghĩa từ này',
      );
      files.outcome = FileHandoff.canceled;
      await tap(t, 'Xuất tệp báo lỗi');
      expect(
        (await learner.load()).feedback.single.state,
        FeedbackState.recorded,
      );
      files.outcome = FileHandoff.handedOff;
      await tap(t, 'Xuất tệp báo lỗi');
      expect(
        (await learner.load()).feedback.single.state,
        FeedbackState.exported,
      );
      final reportFile = files.saved.last;
      expect(reportFile.text, isNot(contains('Ghi chú riêng')));
      expect(
        FeedbackReport.fromFile(reportFile).context!.values['contentId'],
        '1',
      );
      files.next = reportFile;
      await launch(t, administrator: true);
      await tap(t, 'Chọn tệp báo lỗi');
      expect((await admin.loadSnapshot()).inbox, isEmpty);
      await tap(t, 'Nhận báo lỗi này');
      await tap(t, 'Kiểm tra nghĩa từ này');
      await tap(t, 'Bắt đầu xử lý');
      await t.enterText(find.byType(TextField).at(0), 'Nhóm học liệu');
      await t.enterText(
        find.byType(TextField).at(1),
        'Đã ghi nhận, chờ kiểm duyệt nội dung.',
      );
      await tap(t, 'Lưu kết quả và đóng');
      await tap(t, 'Xuất tệp kết quả');
      final resultFile = files.saved.last;
      expect((await learner.load()).feedback.single.outcome, isNull);
      await launch(t);
      await tap(t, 'Cá nhân');
      await tap(t, 'Báo lỗi của bạn');
      files.next = resultFile;
      await tap(t, 'Chọn tệp kết quả xử lý');
      expect((await learner.load()).feedback.single.outcome, isNull);
      await tap(t, 'Hủy nhập kết quả');
      expect((await learner.load()).feedback.single.outcome, isNull);
      files.next = resultFile;
      await tap(t, 'Chọn tệp kết quả xử lý');
      await tap(t, 'Nhập kết quả này');
      expect(
        (await learner.load()).feedback.single.state,
        FeedbackState.resolvedImported,
      );
      expect(
        (await learner.load()).find('1')!.note,
        'Ghi chú riêng không đính kèm',
      );
    },
  );
  testWidgets(
    'blank draft persists and SQL error preserves unsaved description',
    (t) async {
      cleanup(t);
      await launch(t);
      await tap(t, 'Cá nhân');
      await tap(t, 'Báo lỗi của bạn');
      await tap(t, 'Tạo báo lỗi');
      await tap(t, 'Lưu nháp');
      expect((await learner.load()).feedback.single.state, FeedbackState.draft);
      expect(find.text('Xuất tệp báo lỗi'), findsNothing);
      await t.enterText(
        find.byKey(const ValueKey('feedback-body')),
        'Bản đang sửa',
      );
      await learner.db.customStatement(
        "CREATE TRIGGER fail_feedback BEFORE INSERT ON local_feedback_reports BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await tap(t, 'Lưu báo lỗi');
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('feedback-body')))
            .controller!
            .text,
        'Bản đang sửa',
      );
      expect((await learner.load()).feedback.single.body, '');
      await learner.db.customStatement('DROP TRIGGER fail_feedback');
      await tap(t, 'Thử lại · Lưu báo lỗi');
      expect(
        (await learner.load()).feedback.single.state,
        FeedbackState.recorded,
      );
    },
  );
  testWidgets(
    'handoff succeeded but status failed: retry records status without another file',
    (t) async {
      cleanup(t);
      await launch(t);
      await tap(t, 'Cá nhân');
      await tap(t, 'Báo lỗi của bạn');
      await tap(t, 'Tạo báo lỗi');
      await t.enterText(
        find.byKey(const ValueKey('feedback-body')),
        'Bản cần chuyển',
      );
      await tap(t, 'Lưu báo lỗi');
      await learner.db.customStatement(
        "CREATE TRIGGER fail_export BEFORE UPDATE ON local_feedback_reports BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await tap(t, 'Xuất tệp báo lỗi');
      expect(files.saved, hasLength(1));
      expect(
        (await learner.load()).feedback.single.state,
        FeedbackState.recorded,
      );
      await learner.db.customStatement('DROP TRIGGER fail_export');
      await tap(t, 'Ghi nhận lại lần xuất');
      expect(files.saved, hasLength(1));
      expect(
        (await learner.load()).feedback.single.state,
        FeedbackState.exported,
      );
    },
  );
  testWidgets(
    'four scenario contexts and missing-audio question keep exact content identity',
    (t) async {
      cleanup(t);
      await launch(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(LocalHanyuApp)),
      );
      final router = container.read(localRouterProvider);
      for (final scenario in [
        'tourism',
        'directions',
        'shopping',
        'business',
      ]) {
        router.go('/conversations/new?scenario=$scenario');
        await t.pumpAndSettle();
        await tap(t, 'Báo lỗi học liệu');
        await t.enterText(
          find.byKey(const ValueKey('feedback-body')),
          'Báo lỗi $scenario',
        );
        await tap(t, 'Lưu báo lỗi');
        final report = (await learner.load()).feedback.firstWhere(
          (r) => r.body == 'Báo lỗi $scenario',
        );
        expect(report.context!.values['contentId'], scenario);
        expect(
          report.context!.values['contentVersion'],
          'sample-v1-unreviewed',
        );
      }
      final pack = localExamPackages.first;
      router.go('/exams/packages/${pack.id}');
      await t.pumpAndSettle();
      await tap(t, 'Câu 1 · Nghe · thiếu audio');
      await tap(t, 'Báo lỗi học liệu');
      await t.enterText(
        find.byKey(const ValueKey('feedback-body')),
        'Kiểm tra câu nghe chưa có audio',
      );
      await tap(t, 'Lưu báo lỗi');
      final report = (await learner.load()).feedback.firstWhere(
        (r) => r.body == 'Kiểm tra câu nghe chưa có audio',
      );
      expect(report.context!.values['contentId'], pack.questions.first.id);
      expect(report.context!.values['contentVersion'], pack.version);
      expect((await learner.load()).exams.attempts, isEmpty);
    },
  );
}
