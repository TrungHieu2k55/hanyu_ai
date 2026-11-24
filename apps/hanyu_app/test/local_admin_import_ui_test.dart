import 'package:doanchuyennganh2/features/admin/domain/vocabulary_import.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/admin/application/csv_file_source_provider.dart';
import 'package:doanchuyennganh2/features/admin/application/local_admin_providers.dart';
import 'package:doanchuyennganh2/features/admin/data/csv_file_source.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/admin/domain/local_admin.dart';
import 'package:doanchuyennganh2/features/admin/domain/local_csv_import.dart';
import 'package:doanchuyennganh2/features/admin/local_admin_app.dart';

class QueueCsvSource implements CsvFileSource {
  PickedCsv? next;
  @override
  Future<PickedCsv?> pick() async {
    final value = next;
    next = null;
    return value;
  }
}

class GateAdminRepository extends LocalAdminRepository {
  GateAdminRepository(super.db);
  Completer<void>? gate, previewGate;
  @override
  Future<CsvImportPreview> previewCsv(
    String content,
    VocabularyColumnMapping mapping,
  ) async {
    await previewGate?.future;
    return super.previewCsv(content, mapping);
  }

  @override
  Future<LocalAdminSnapshot> commitCsv(
    CsvImportPreview preview, {
    required bool skipInvalid,
    required String operationId,
  }) async {
    await gate?.future;
    return super.commitCsv(
      preview,
      skipInvalid: skipInvalid,
      operationId: operationId,
    );
  }
}

void main() {
  late GateAdminRepository repo;
  late QueueCsvSource source;
  setUp(() {
    repo = GateAdminRepository(LocalDatabase(NativeDatabase.memory()));
    source = QueueCsvSource();
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
          csvFileSourceProvider.overrideWithValue(source),
        ],
        child: const LocalAdminApp(),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tapFinder(WidgetTester t, Finder f) async {
    await t.pumpAndSettle();
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  Future<void> tap(WidgetTester t, String label) =>
      tapFinder(t, find.text(label).last);
  Future<void> open(WidgetTester t) async {
    await tap(t, 'Quản lý học liệu');
    await tap(t, 'Nhập từ CSV');
  }

  Future<void> paste(WidgetTester t, String csv) async {
    await t.ensureVisible(find.byKey(const ValueKey('csv-source')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('csv-source')), csv);
    await t.pumpAndSettle();
  }

  Future<void> basicPreview(WidgetTester t) async {
    await paste(t, 'h,p,v\n早上,zǎoshang,sáng');
    await tap(t, 'Đọc CSV');
    await tap(t, 'Kiểm tra dữ liệu');
  }

  testWidgets(
    'file cancellation, remapping, partial opt-in and failed commit preserve a retryable wizard',
    (t) async {
      await launch(t);
      await open(t);
      await paste(t, 'bản đang soạn');
      await tap(t, 'Chọn tệp CSV');
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('csv-source')))
            .controller!
            .text,
        'bản đang soạn',
      );
      source.next = const PickedCsv(
        'words.csv',
        '\ufeffmeaning,hanzi,pinyin\r\n"buổi sáng, chào",早上,zǎoshang\r\ntối,晚上,',
      );
      await tap(t, 'Chọn tệp CSV');
      await tap(t, 'Đọc CSV');
      for (final pair in [(0, 'hanzi'), (1, 'pinyin'), (2, 'meaning')]) {
        await tapFinder(t, find.byKey(ValueKey('csv-column-${pair.$1}')));
        await tap(t, pair.$2);
      }
      await tap(t, 'Kiểm tra dữ liệu');
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Không được để trống.'), findsOneWidget);
      expect(
        t.getSize(find.text('Không được để trống.')).width,
        lessThanOrEqualTo(312),
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xem xác nhận nhập'),
            )
            .onPressed,
        isNull,
      );
      await tap(t, 'Chỉ nhập dòng hợp lệ, bỏ qua dòng lỗi');
      await tap(t, 'Xem xác nhận nhập');
      expect((await repo.loadSnapshot()).content, isEmpty);
      await repo.db.customStatement(
        "CREATE TRIGGER fail_csv BEFORE INSERT ON local_admin_revisions BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await tap(t, 'Xác nhận nhập vào Admin');
      expect(
        find.textContaining('Chưa nhận được xác nhận lưu'),
        findsOneWidget,
      );
      expect((await repo.loadSnapshot()).imports, isEmpty);
      await repo.db.customStatement('DROP TRIGGER fail_csv');
      await tap(t, 'Xác nhận nhập vào Admin');
      final data = await repo.loadSnapshot();
      expect(data.content, hasLength(1));
      expect(data.imports.single.mapping, [1, 2, 0]);
      expect(data.imports.single.skippedRows, 1);
      expect(find.text('Đã lưu 1 từ nháp vào Admin.'), findsOneWidget);
      await tap(t, 'Về thư viện học liệu');
      await tap(t, 'Lịch sử nhập CSV (1)');
      await tap(t, 'Đã nhập 1 từ nháp');
      expect(find.text('Đã lưu 1 từ nháp vào Admin.'), findsOneWidget);
    },
  );
  testWidgets(
    'stale preview forces explicit fresh validation instead of importing duplicates',
    (t) async {
      await launch(t, width: 1366, scale: 1);
      await open(t);
      await basicPreview(t);
      await tap(t, 'Xem xác nhận nhập');
      var data = await repo.loadSnapshot();
      await repo.saveRevision(
        id: const Uuid().v4(),
        baseRevision: 0,
        payload: VocabularyContent(
          hanzi: '早上',
          pinyin: 'zǎoshang',
          vietnamese: 'đã có',
        ),
        revision: data.revision,
        operationId: 'other',
      );
      await tap(t, 'Xác nhận nhập vào Admin');
      expect(find.textContaining('Dữ liệu đã thay đổi'), findsOneWidget);
      repo.previewGate = Completer<void>();
      await tap(t, 'Kiểm tra lại với dữ liệu mới');
      expect(find.text('Đang kiểm tra…'), findsOneWidget);
      expect(t.takeException(), isNull);
      repo.previewGate!.complete();
      await t.pumpAndSettle();
      expect(find.text('0 bản ghi hợp lệ · 1 bản ghi có lỗi'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xem xác nhận nhập'),
            )
            .onPressed,
        isNull,
      );
      expect((await repo.loadSnapshot()).content, hasLength(1));
      expect((await repo.loadSnapshot()).imports, isEmpty);
    },
  );
  testWidgets(
    'pending commit blocks back/double tap and never shows success before persistence',
    (t) async {
      await launch(t);
      await open(t);
      await basicPreview(t);
      await tap(t, 'Xem xác nhận nhập');
      repo.gate = Completer<void>();
      final button = find.widgetWithText(
        FilledButton,
        'Xác nhận nhập vào Admin',
      );
      await t.ensureVisible(button);
      await t.pumpAndSettle();
      final callback = t.widget<FilledButton>(button).onPressed!;
      callback();
      callback();
      await t.pumpAndSettle();
      expect(find.text('Đang lưu…'), findsOneWidget);
      expect(find.textContaining('Đã lưu 1 từ nháp'), findsNothing);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('Đang lưu…'), findsOneWidget);
      expect((await repo.loadSnapshot()).content, isEmpty);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect((await repo.loadSnapshot()).imports, hasLength(1));
      expect((await repo.loadSnapshot()).content, hasLength(1));
      expect(find.text('Đã lưu 1 từ nháp vào Admin.'), findsOneWidget);
    },
  );
}
