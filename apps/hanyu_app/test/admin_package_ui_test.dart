import 'package:doanchuyennganh2/core/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/files/local_file_transfer.dart';
import 'package:doanchuyennganh2/core/files/file_transfer_provider.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/admin/application/local_admin_providers.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/presentation/content_package_export_screen.dart';
import 'package:doanchuyennganh2/features/content/domain/content_package.dart';

class PackageFiles implements LocalFileTransfer {
  FileHandoff result = FileHandoff.canceled;
  final saved = <LocalJsonFile>[];
  @override
  Future<LocalJsonFile?> pick(LocalJsonKind kind) async => null;
  @override
  Future<FileHandoff> save(LocalJsonFile file) async {
    saved.add(file);
    return result;
  }
}

void main() {
  late LocalAdminRepository repo;
  late PackageFiles files;
  setUp(() {
    repo = LocalAdminRepository(LocalDatabase(NativeDatabase.memory()));
    files = PackageFiles();
  });
  tearDown(() => repo.close());
  Future<void> launch(WidgetTester t) async {
    t.view.physicalSize = const Size(360, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
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
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContentPackageExportScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String text) async {
    final f = find.text(text).last;
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'trial preview/cancel/acknowledge/freeze/re-export at 360 and 150% text',
    (t) async {
      var s = await repo.loadSnapshot();
      s = await repo.seedSamples(revision: s.revision, operationId: 'seed');
      await launch(t);
      await tap(t, 'Chọn toàn bộ');
      await tap(t, 'Xem trước gói');
      expect((await repo.loadSnapshot()).packages, isEmpty);
      await tap(t, 'Quay lại chọn nội dung');
      expect((await repo.loadSnapshot()).packages, isEmpty);
      await tap(t, 'Xem trước gói');
      final button = find.widgetWithText(FilledButton, 'Lưu phiên bản gói');
      expect(t.widget<FilledButton>(button).onPressed, isNull);
      await tap(t, 'Tôi hiểu gói dùng thử có thể chứa nội dung chưa duyệt.');
      await tap(t, 'Lưu phiên bản gói');
      expect((await repo.loadSnapshot()).packages, hasLength(1));
      await tap(t, 'Xuất lại v1');
      expect(
        find.text('Đã hủy xuất file. Phiên bản vẫn được giữ để xuất lại.'),
        findsOneWidget,
      );
      expect((await repo.loadSnapshot()).packages, hasLength(1));
      files.result = FileHandoff.handedOff;
      await tap(t, 'Xuất lại v1');
      expect(files.saved, hasLength(2));
      expect(files.saved[0].bytes, files.saved[1].bytes);
      expect(ContentPackage.fromFile(files.saved.last).mode, PackageMode.trial);
      expect(
        find.text('Đã bàn giao file cho hệ thống. Hãy kiểm tra nơi lưu file.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'empty and reviewed mode do not invent publishable learning material',
    (t) async {
      await repo.loadSnapshot();
      await launch(t);
      expect(find.text('Chưa có học liệu phù hợp'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xem trước gói'),
            )
            .onPressed,
        isNull,
      );
      await t.ensureVisible(find.byKey(const ValueKey('package-mode')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('package-mode')));
      await t.pumpAndSettle();
      await t.tap(find.text('Đã khai báo duyệt').last);
      await t.pumpAndSettle();
      expect(find.text('Chưa có học liệu phù hợp'), findsOneWidget);
      expect((await repo.loadSnapshot()).packages, isEmpty);
    },
  );
}
