// Widget captures only: not a browser/OS file handoff or physical-device test.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/theme/app_theme.dart';
import 'package:doanchuyennganh2/features/admin/application/local_admin_providers.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/presentation/content_package_export_screen.dart';

import 'support/reference_images.dart';

void main() {
  testWidgets('capture package selector, preview and frozen history', (
    t,
  ) async {
    await loadReferenceFonts(t);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [360.0, 390.0, 1366.0]) {
      final repo = LocalAdminRepository(LocalDatabase(NativeDatabase.memory()));
      var s = await repo.loadSnapshot();
      s = await repo.seedSamples(revision: s.revision, operationId: 'seed');
      t.view.physicalSize = Size(width, width > 900 ? 768 : 844);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = width == 360 ? 1.5 : 1;
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [localAdminRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: const ContentPackageExportScreen(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> tap(String label) async {
        final target = find.text(label).last;
        await t.ensureVisible(target);
        await t.pumpAndSettle();
        await t.tap(target);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      await captureReference(
        t,
        key,
        '../../specs/005-local-admin-content/evidence/package-selector-${width.toInt()}.png',
      );
      await tap('Chọn toàn bộ');
      await tap('Xem trước gói');
      await t.ensureVisible(find.text('Xem trước · v1'));
      await t.pumpAndSettle();
      await captureReference(
        t,
        key,
        '../../specs/005-local-admin-content/evidence/package-preview-${width.toInt()}.png',
      );
      await tap('Tôi hiểu gói dùng thử có thể chứa nội dung chưa duyệt.');
      await tap('Lưu phiên bản gói');
      await t.ensureVisible(find.text('Phiên bản đã lưu (1)'));
      await t.pumpAndSettle();
      await captureReference(
        t,
        key,
        '../../specs/005-local-admin-content/evidence/package-history-${width.toInt()}.png',
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await repo.close();
    }
  }, skip: !const bool.fromEnvironment('CAPTURE_UI'));
}
