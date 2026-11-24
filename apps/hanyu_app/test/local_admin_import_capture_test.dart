// Optional widget reference captures; not OS picker or browser evidence.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/admin/application/local_admin_providers.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/local_admin_app.dart';

import 'support/reference_images.dart';

void main() {
  testWidgets(
    'capture durable CSV source, validation, confirmation, result and history',
    (t) async {
      await loadReferenceFonts(t);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      Future<void> tap(String label) async {
        final target = find.text(label).last;
        await t.ensureVisible(target);
        await t.pumpAndSettle();
        await t.tap(target);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      for (final width in [360.0, 390.0, 1366.0]) {
        final repo = LocalAdminRepository(
          LocalDatabase(NativeDatabase.memory()),
        );
        t.view.physicalSize = Size(width, width > 900 ? 768 : 844);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = width == 360 ? 1.5 : 1;
        final key = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [localAdminRepositoryProvider.overrideWithValue(repo)],
              child: const LocalAdminApp(),
            ),
          ),
        );
        await t.pumpAndSettle();
        await tap('Quản lý học liệu');
        await tap('Nhập từ CSV');
        await t.enterText(
          find.byKey(const ValueKey('csv-source')),
          'hanzi,pinyin,vietnamese\n早上,zǎoshang,"buổi sáng, lời chào"\n晚上,,buổi tối',
        );
        await t.pumpAndSettle();
        if (width == 390) {
          await captureReference(
            t,
            key,
            '../../specs/005-local-admin-content/evidence/csv-source-390.png',
          );
        }
        await tap('Đọc CSV');
        await tap('Kiểm tra dữ liệu');
        expect(
          find.text('1 bản ghi hợp lệ · 1 bản ghi có lỗi'),
          findsOneWidget,
        );
        if (width != 390) {
          await captureReference(
            t,
            key,
            '../../specs/005-local-admin-content/evidence/csv-validation-${width.toInt()}.png',
          );
        }
        await tap('Chỉ nhập dòng hợp lệ, bỏ qua dòng lỗi');
        await tap('Xem xác nhận nhập');
        if (width == 360) {
          await captureReference(
            t,
            key,
            '../../specs/005-local-admin-content/evidence/csv-confirmation-360.png',
          );
        }
        await tap('Xác nhận nhập vào Admin');
        expect(find.text('Đã lưu 1 từ nháp vào Admin.'), findsOneWidget);
        if (width == 390) {
          await captureReference(
            t,
            key,
            '../../specs/005-local-admin-content/evidence/csv-result-390.png',
          );
        }
        await tap('Về thư viện học liệu');
        await tap('Lịch sử nhập CSV (1)');
        if (width == 1366) {
          await captureReference(
            t,
            key,
            '../../specs/005-local-admin-content/evidence/csv-history-1366.png',
          );
        }
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await repo.close();
      }
    },
    skip: !const bool.fromEnvironment('CAPTURE_UI'),
  );
}
