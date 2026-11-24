import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/profile/domain/local_profile.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late DriftLocalRepository repo;
  setUp(
    () => repo = DriftLocalRepository(LocalDatabase(NativeDatabase.memory())),
  );
  tearDown(() => repo.close());

  test('profile validates HSK, minutes, Unicode name and help version', () {
    expect(LocalProfile(name: '  Hiếu  ').validated().name, 'Hiếu');
    expect(
      () => const LocalProfile(level: 4).validated(),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => const LocalProfile(minutes: 12).validated(),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => LocalProfile(name: '人' * 81).validated(),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => LocalProfile(helpVersionSeen: 'v' * 41).validated(),
      throwsA(isA<LocalDataException>()),
    );
  });

  test(
    'profile and help persist after file database close without an account',
    () async {
      final dir = await Directory.systemTemp.createTemp('hanyu-e-profile-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/local.sqlite');
      final first = DriftLocalRepository(LocalDatabase(NativeDatabase(file)));
      var data = await first.load();
      data = await first.saveProfile(
        const LocalProfile(
          name: '  Hiếu ',
          level: 3,
          minutes: 20,
          sound: false,
        ),
        revision: data.revision,
        operationId: 'profile',
      );
      await first.saveHelpSeen(
        LocalProfile.currentHelpVersion,
        revision: data.revision,
        operationId: 'help',
      );
      await first.close();
      final second = DriftLocalRepository(LocalDatabase(NativeDatabase(file)));
      addTearDown(second.close);
      data = await second.load();
      expect(data.preferences.name, 'Hiếu');
      expect(data.preferences.level, 3);
      expect(data.preferences.minutes, 20);
      expect(data.preferences.sound, false);
      expect(data.helpVersionSeen, LocalProfile.currentHelpVersion);
      expect(
        (await second.db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%account%'",
            )
            .get()),
        isEmpty,
      );
    },
  );

  test(
    'help marker requires commit, retries once and respects stale revision',
    () async {
      final initial = await repo.load();
      expect(initial.helpVersionSeen, isNull);
      await repo.db.customStatement(
        "CREATE TRIGGER fail_help BEFORE INSERT ON local_metadata WHEN NEW.key = 'helpVersionSeen' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        repo.saveHelpSeen(
          'v1',
          revision: initial.revision,
          operationId: 'help',
        ),
        throwsA(anything),
      );
      expect((await repo.load()).helpVersionSeen, isNull);
      expect((await repo.load()).revision, initial.revision);
      await repo.db.customStatement('DROP TRIGGER fail_help');
      final saved = await repo.saveHelpSeen(
        'v1',
        revision: initial.revision,
        operationId: 'help',
      );
      expect(
        (await repo.saveHelpSeen(
          'v1',
          revision: initial.revision,
          operationId: 'help',
        )).revision,
        saved.revision,
      );
      await expectLater(
        repo.saveHelpSeen(
          'v2',
          revision: initial.revision,
          operationId: 'other',
        ),
        throwsA(isA<LocalConflict>()),
      );
      await expectLater(
        repo.saveHelpSeen('v2', revision: saved.revision, operationId: 'help'),
        throwsA(isA<LocalDataException>()),
      );
    },
  );

  Future<void> launch(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localRepositoryProvider.overrideWithValue(repo)],
        child: const LocalHanyuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String text) async {
    await t.pumpAndSettle();
    final f = find.text(text).last;
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'cancel restores saved form; tab guard preserves unsaved draft at 150%',
    (tester) async {
      await launch(tester, scale: 1.5);
      await tap(tester, 'Cá nhân');
      await tap(tester, 'Mục tiêu và âm thanh');
      await tester.enterText(find.byType(TextField), 'Chưa lưu');
      await tap(tester, 'Học');
      await tap(tester, 'Ở lại');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Chưa lưu',
      );
      await tap(tester, 'Hủy thay đổi');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect((await repo.load()).preferences.name, '');
      await tester.enterText(find.byType(TextField), 'Hiếu');
      await tap(tester, 'Lưu cài đặt');
      expect((await repo.load()).preferences.name, 'Hiếu');
      await tap(tester, 'Học');
      expect(find.text('Rời khi chưa lưu?'), findsNothing);
    },
  );

  testWidgets(
    'help is not marked by viewing; privacy and explicit completion work',
    (tester) async {
      await launch(tester);
      await tap(tester, 'Cá nhân');
      await tap(tester, 'Hướng dẫn sử dụng');
      expect((await repo.load()).helpVersionSeen, isNull);
      await tap(tester, 'Thông tin riêng tư');
      expect(find.text('Dữ liệu ở đâu?'), findsOneWidget);
      expect((await repo.load()).helpVersionSeen, isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tap(tester, 'Đã đọc hướng dẫn');
      expect(
        (await repo.load()).helpVersionSeen,
        LocalProfile.currentHelpVersion,
      );
      expect(find.text('Đã ghi nhận trên thiết bị.'), findsOneWidget);
    },
  );

  testWidgets('failed profile commit keeps draft and offers explicit refresh', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, 'Cá nhân');
    await tap(tester, 'Mục tiêu và âm thanh');
    await tester.enterText(find.byType(TextField), 'Bản đang sửa');
    final initial = await repo.load();
    await repo.savePreferences(
      const LocalPreferences(name: 'Nơi khác'),
      revision: initial.revision,
      operationId: 'external',
    );
    await tap(tester, 'Lưu cài đặt');
    expect(find.textContaining('Dữ liệu đã thay đổi'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Bản đang sửa',
    );
    await tap(tester, 'Tải bản mới, giữ nội dung đang sửa');
    await tap(tester, 'Lưu cài đặt');
    expect((await repo.load()).preferences.name, 'Bản đang sửa');
  });
}
