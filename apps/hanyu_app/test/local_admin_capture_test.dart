// Optional widget references, not browser/device acceptance.
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
    'capture typed Admin library/editor/detail/backup at mobile and desktop sizes',
    (t) async {
      await loadReferenceFonts(t);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = LocalAdminRepository(LocalDatabase(NativeDatabase.memory()));
      final data = await repo.loadSnapshot();
      await repo.seedSamples(
        revision: data.revision,
        operationId: 'reference-samples',
      );
      Future<void> tap(String text) async {
        final f = find.text(text).last;
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        await t.tap(f);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      for (final width in [360.0, 390.0, 1366.0]) {
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
        await captureReference(
          t,
          key,
          '../../specs/005-local-admin-content/evidence/content-library-${width.toInt()}.png',
        );
        await tap('朋友');
        await captureReference(
          t,
          key,
          '../../specs/005-local-admin-content/evidence/content-detail-${width.toInt()}.png',
        );
        await t.tap(find.byType(BackButton));
        await t.pumpAndSettle();
        if (width == 390) {
          await tap('Thêm câu hỏi');
          await captureReference(
            t,
            key,
            '../../specs/005-local-admin-content/evidence/content-question-390.png',
          );
          await t.ensureVisible(find.text('Lưu phiên bản nháp'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        if (width == 1366) {
          await tap('Nguồn và backup Admin');
          await captureReference(
            t,
            key,
            '../../specs/005-local-admin-content/evidence/content-backup-1366.png',
          );
        }
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      }
      await repo.close();
    },
    skip: !const bool.fromEnvironment('CAPTURE_UI'),
  );
}
