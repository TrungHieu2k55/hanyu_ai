// Optional reference captures; not browser or device evidence.
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/features/admin/local_admin_app.dart';
import 'package:doanchuyennganh2/features/admin/application/local_admin_providers.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/local_admin.dart';
import 'package:doanchuyennganh2/features/support/domain/local_feedback.dart';

import 'support/reference_images.dart';

void main() {
  testWidgets('render feedback mobile and Admin inbox/detail', (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loadReferenceFonts(tester);
    final learner = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
    );
    final admin = LocalAdminRepository(LocalDatabase(NativeDatabase.memory()));
    final id = const Uuid().v4();
    var data = await learner.load();
    data = await learner.saveFeedback(
      id: id,
      reportRevision: 0,
      body: 'Ví dụ câu 朋友 cần kiểm tra lại nghĩa Việt và cách dùng.',
      context: FeedbackContext({
        'contentId': 'word:sample',
        'contentVersion': 'sample-v1-unreviewed',
        'label': '朋友 · péngyou',
        'route': '/words/word:sample',
      }),
      revision: data.revision,
      operationId: 'capture-report',
    );
    var a = await admin.loadSnapshot();
    a = await admin.importFeedback(
      data.feedback.single,
      revision: a.revision,
      operationId: 'capture-inbox',
    );
    await admin.updateInbox(
      id,
      1,
      InboxStatus.closed,
      resolution: 'Đã ghi nhận để người kiểm duyệt kiểm tra lại. Học liệu hiện chưa tự thay đổi.',
      actorLabel: 'Nhóm học liệu (khai báo local)',
      revision: a.revision,
      operationId: 'capture-close',
    );
    Future<void> tap(String label) async {
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    for (final width in [360.0, 390.0, 1366.0]) {
      tester.view.physicalSize = Size(width, width > 900 ? 768 : 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = width == 360
          ? 1.5
          : 1;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              localRepositoryProvider.overrideWithValue(learner),
              localAdminRepositoryProvider.overrideWithValue(admin),
            ],
            child: width > 900 ? const LocalAdminApp() : const LocalHanyuApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (width > 900) {
        await captureReference(
          tester,
          key,
          '../../specs/005-local-admin-content/evidence/inbox-1366.png',
        );
        await tap(data.feedback.single.body);
        await captureReference(
          tester,
          key,
          '../../specs/005-local-admin-content/evidence/inbox-result-1366.png',
        );
      } else {
        await tap('Cá nhân');
        await tap('Báo lỗi của bạn');
        await captureReference(
          tester,
          key,
          '../../specs/005-local-admin-content/evidence/feedback-list-${width.toInt()}.png',
        );
        await tap(data.feedback.single.body);
        await captureReference(
          tester,
          key,
          '../../specs/005-local-admin-content/evidence/feedback-edit-${width.toInt()}.png',
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
    await learner.close();
    await admin.close();
  }, skip: !const bool.fromEnvironment('CAPTURE_UI'));
}
