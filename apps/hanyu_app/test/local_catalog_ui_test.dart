import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/files/file_transfer_provider.dart';
import 'package:doanchuyennganh2/core/files/local_file_transfer.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';

import 'content_package_contract_test.dart' as fixture;
import 'support/reference_images.dart';

import 'package:flutter/services.dart';

class _PackageFilePicker implements LocalFileTransfer {
  LocalJsonFile? file;
  @override
  Future<LocalJsonFile?> pick(LocalJsonKind kind) async {
    expect(kind, LocalJsonKind.contentPackage);
    return file;
  }

  @override
  Future<FileHandoff> save(LocalJsonFile file) async => FileHandoff.unavailable;
}

void main() {
  testWidgets(
    'real learner route supports preview, explicit install and removal at 360 / 150%',
    (t) async {
      final repo = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
      addTearDown(repo.close);
      addTearDown(() => t.pumpWidget(const SizedBox()));
      t.view.physicalSize = const Size(360, 844);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final file = fixture
          .pack(
            records: [
              fixture.record(
                100,
                payload: VocabularyContent(
                  hanzi: '词语',
                  pinyin: 'cíyǔ',
                  vietnamese: 'Từ trong gói thử',
                ),
              ),
            ],
          )
          .toFile();
      final picker = _PackageFilePicker()..file = file;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            localRepositoryProvider.overrideWithValue(repo),
            localFileTransferProvider.overrideWithValue(picker),
          ],
          child: const LocalHanyuApp(),
        ),
      );
      await t.pumpAndSettle();
      Future<void> tap(String title) async {
        final target = find.text(title).last;
        await t.ensureVisible(target);
        await t.pumpAndSettle();
        await t.tap(target);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: title);
      }

      await tap('Gói học liệu');
      await tap('Chọn file gói học liệu');
      expect((await repo.load()).catalog.packages, isEmpty);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận cài gói'),
            )
            .onPressed,
        isNull,
      );
      await tap('Đóng xem trước');
      expect((await repo.load()).catalog.packages, isEmpty);
      await tap('Chọn file gói học liệu');
      await tap('Tôi hiểu gói dùng thử có thể chưa được duyệt.');
      await tap('Xác nhận cài gói');
      expect((await repo.load()).catalog.active?.version, 1);
      await tap('Học');
      expect(find.text('词语'), findsOneWidget);
      await tap('Gói học liệu');
      await tap('Gỡ gói');
      await tap('Hủy');
      expect((await repo.load()).catalog.packages, hasLength(1));
      await tap('Gỡ gói');
      await tap('Xác nhận gỡ');
      expect((await repo.load()).catalog.packages, isEmpty);
    },
  );
  for (final width in [360.0, 390.0, 1366.0]) {
    testWidgets('catalog reference capture at $width', (t) async {
      final picker = _PackageFilePicker()
        ..file = fixture
            .pack(
              records: [
                fixture.record(
                  100,
                  payload: VocabularyContent(
                    hanzi: '词语',
                    pinyin: 'cíyǔ',
                    vietnamese: 'Một ví dụ có mô tả dài để kiểm tra cách xuống dòng trên màn nhỏ',
                  ),
                ),
              ],
            )
            .toFile();
      await loadReferenceFonts(t);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
      t.view.physicalSize = Size(width, width == 1366 ? 768 : 844);
      t.platformDispatcher.textScaleFactorTestValue = width == 360 ? 1.5 : 1;
      final capture = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: ProviderScope(
            overrides: [
              localRepositoryProvider.overrideWithValue(repo),
              localFileTransferProvider.overrideWithValue(picker),
            ],
            child: const LocalHanyuApp(),
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> tap(String title) async {
        final target = find.text(title).last;
        await t.ensureVisible(target);
        await t.pumpAndSettle();
        await t.tap(target);
        await t.pumpAndSettle();
      }

      await tap('Gói học liệu');
      await tap('Chọn file gói học liệu');
      await t.ensureVisible(find.text('Xem trước · v1'));
      await t.pumpAndSettle();
      await captureReference(
        t,
        capture,
        '../../specs/005-local-admin-content/evidence/learner-package-${width.toInt()}.png',
      );
      if (width == 1366) {
        final before = FocusManager.instance.primaryFocus;
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, isNot(same(before)));
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await repo.close();
    }, skip: !const bool.fromEnvironment('CAPTURE_UI'));
  }
}
