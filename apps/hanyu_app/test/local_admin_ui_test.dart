import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/files/local_file_transfer.dart';
import 'package:doanchuyennganh2/core/files/file_transfer_provider.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/admin/application/local_admin_providers.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_revision.dart';
import 'package:doanchuyennganh2/features/admin/local_admin_app.dart';

class AdminFiles implements LocalFileTransfer {
  LocalJsonFile? next;
  final saved = <LocalJsonFile>[];
  @override
  Future<LocalJsonFile?> pick(LocalJsonKind kind) async {
    final file = next;
    next = null;
    return file;
  }

  @override
  Future<FileHandoff> save(LocalJsonFile file) async {
    saved.add(file);
    return FileHandoff.handedOff;
  }
}

void main() {
  late LocalAdminRepository repo;
  late AdminFiles files;
  setUp(() {
    repo = LocalAdminRepository(LocalDatabase(NativeDatabase.memory()));
    files = AdminFiles();
  });
  tearDown(() => repo.close());
  Future<void> launch(
    WidgetTester t, {
    double width = 360,
    double scale = 1.5,
  }) async {
    t.view.physicalSize = Size(width, width > 900 ? 768 : 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          localAdminRepositoryProvider.overrideWithValue(repo),
          localFileTransferProvider.overrideWithValue(files),
        ],
        child: const LocalAdminApp(),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await t.pump(const Duration(milliseconds: 500));
    } else {
      await t.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester t, String label) async {
    await settle(t);
    final target = find.text(label).last;
    await t.ensureVisible(target);
    await settle(t);
    await t.tap(target);
    await settle(t);
    expect(t.takeException(), isNull, reason: label);
  }

  Future<void> enter(WidgetTester t, String key, String value) async {
    final target = find.byKey(ValueKey(key));
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.enterText(target, value);
    await t.pumpAndSettle();
  }

  Future<void> back(WidgetTester t) async {
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'word CRUD guard/review/publish/edit/withdraw works at 360 with 150% text',
    (t) async {
      await launch(t);
      await tap(t, 'Quản lý học liệu');
      await tap(t, 'Thêm từ vựng');
      await enter(t, 'admin-hanzi', '朋友');
      await enter(t, 'admin-pinyin', 'péngyou');
      await enter(t, 'admin-vietnamese', 'bạn');
      await back(t);
      expect(find.text('Rời khi chưa lưu?'), findsOneWidget);
      await tap(t, 'Ở lại');
      await enter(t, 'admin-source', 'Nhóm tự soạn');
      await enter(t, 'admin-license', 'Cho phép dùng trong đồ án');
      await tap(t, 'Lưu phiên bản nháp');
      expect(
        (await repo.loadSnapshot()).content.single.review.status,
        ReviewStatus.unreviewed,
      );
      await back(t);
      await tap(t, '朋友');
      await tap(t, 'Khai báo duyệt nội dung');
      await enter(t, 'admin-reviewer', 'Người khai báo');
      await enter(t, 'admin-review-note', 'Đã đối chiếu nội dung');
      await tap(t, 'Lưu khai báo duyệt');
      await tap(t, 'Công bố phiên bản này');
      await tap(t, 'Xác nhận');
      expect(
        (await repo.loadSnapshot()).content.single.state,
        ContentState.published,
      );
      await tap(t, 'Sửa thành bản nháp mới');
      await enter(t, 'admin-vietnamese', 'người bạn');
      await tap(t, 'Lưu phiên bản nháp');
      await back(t);
      await back(t);
      await tap(t, '朋友');
      var s = await repo.loadSnapshot();
      expect(
        s.content.where((c) => c.state == ContentState.published),
        hasLength(1),
      );
      expect(
        s.content.singleWhere((c) => c.revision == 2).review.status,
        ReviewStatus.unreviewed,
      );
      await tap(t, 'Khai báo duyệt nội dung');
      await enter(t, 'admin-reviewer', 'A');
      await enter(t, 'admin-review-note', 'Đã kiểm tra bản 2');
      await tap(t, 'Lưu khai báo duyệt');
      await tap(t, 'Công bố phiên bản này');
      await tap(t, 'Xác nhận');
      await tap(t, 'Thu hồi phiên bản này');
      await tap(t, 'Xác nhận');
      s = await repo.loadSnapshot();
      expect(s.content.any((c) => c.state == ContentState.published), false);
    },
  );
  testWidgets(
    'question has four choices and scenario has complete multilingual fields',
    (t) async {
      await launch(t, width: 1366, scale: 1);
      await tap(t, 'Quản lý học liệu');
      await tap(t, 'Thêm câu hỏi');
      await enter(t, 'admin-prompt', '你好 có nghĩa là gì?');
      for (var i = 0; i < 4; i++) {
        await enter(
          t,
          'admin-choice$i',
          ['Xin chào', 'Tạm biệt', 'Cảm ơn', 'Xin lỗi'][i],
        );
      }
      await enter(t, 'admin-explanation', '你好 là lời chào');
      await tap(t, 'Lưu phiên bản nháp');
      await back(t);
      await tap(t, 'Thêm tình huống');
      await enter(t, 'admin-role', 'Nhân viên');
      await enter(t, 'admin-partner', 'Khách');
      await enter(t, 'admin-goal', 'Chào hỏi');
      for (var i = 0; i < 3; i++) {
        await enter(t, 'admin-opening$i', ['你好', 'nǐ hǎo', 'Xin chào'][i]);
        await enter(t, 'admin-reply$i', ['谢谢', 'xièxie', 'Cảm ơn'][i]);
      }
      await tap(t, 'Lưu phiên bản nháp');
      final s = await repo.loadSnapshot();
      expect(
        (s.content.singleWhere((c) => c.kind == ContentKind.question).payload
                as QuestionContent)
            .choices,
        hasLength(4),
      );
      expect(
        (s.content.singleWhere((c) => c.kind == ContentKind.scenario).payload
                as ScenarioContent)
            .sampleReply,
        hasLength(3),
      );
    },
  );
  testWidgets(
    'Admin backup has preview/cancel/explicit replacement and identity label persistence',
    (t) async {
      await launch(t, width: 1366, scale: 1);
      await tap(t, 'Quản lý học liệu');
      await tap(t, 'Nguồn và backup Admin');
      await enter(t, 'admin-publisher-label', 'Nhóm thử nghiệm');
      await tap(t, 'Lưu tên nguồn');
      await tap(t, 'Xuất backup Admin');
      final backup = files.saved.single;
      var s = await repo.loadSnapshot();
      s = await repo.seedSamples(
        revision: s.revision,
        operationId: 'external-samples',
      );
      final before = s.identity.publisherId;
      await tap(t, 'Tải trạng thái, giữ tên đang sửa');
      files.next = backup;
      await tap(t, 'Chọn backup Admin để xem trước');
      expect((await repo.loadSnapshot()).content, hasLength(6));
      await tap(t, 'Hủy xem trước backup');
      expect((await repo.loadSnapshot()).content, hasLength(6));
      files.next = backup;
      await tap(t, 'Chọn backup Admin để xem trước');
      await tap(t, 'Khôi phục backup này');
      await tap(t, 'Thay dữ liệu Admin');
      final after = await repo.loadSnapshot();
      expect(after.content, isEmpty);
      expect(after.identity.publisherId, before);
      expect(after.identity.label, 'Nhóm thử nghiệm');
    },
  );
}
