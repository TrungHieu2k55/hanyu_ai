import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/extended_learning/study_lesson.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<(GoRouter, DriftLocalRepository)> start(
  WidgetTester tester,
  Size size,
  double scale,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final repo = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
  final container = ProviderContainer(
    overrides: [localRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await repo.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const LocalHanyuApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (container.read(localRouterProvider), repo);
}

Future<void> open(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: path);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  for (final (width, height, scale) in [
    (360.0, 800.0, 1.5),
    (390.0, 844.0, 1.0),
    (768.0, 900.0, 1.3),
    (1366.0, 768.0, 1.0),
  ]) {
    testWidgets('extended study routes at $width and text scale $scale', (
      tester,
    ) async {
      final (router, _) = await start(tester, Size(width, height), scale);
      for (final path in [
        '/practice/lessons',
        for (final lesson in studyLessons.where((item) => item.level == 1))
          '/practice/lessons/${lesson.id}',
        '/learn/decks',
        '/learn/history',
        '/progress/goals',
        '/progress/mistakes',
        '/profile/reminder',
        '/profile/offline',
      ]) {
        await open(tester, router, path);
        expect(find.text('Không tìm thấy trang này.'), findsNothing);
      }
    });
  }

  testWidgets('sentence practice updates mistakes and daily goal', (
    tester,
  ) async {
    final (router, repo) = await start(tester, const Size(390, 844), 1);
    await open(tester, router, '/practice');
    await tap(tester, find.text('Mở danh mục bài luyện'));
    await tap(tester, find.text('Ghép câu đi học'));
    for (final word in ['学校', '去', '我']) {
      await tap(tester, find.widgetWithText(OutlinedButton, word));
    }
    await tap(tester, find.text('Kiểm tra câu trả lời'));
    expect(find.text('Thử lại nhé'), findsOneWidget);
    await tap(tester, find.text('Làm lại'));
    for (final word in ['我', '去', '学校']) {
      await tap(tester, find.widgetWithText(OutlinedButton, word));
    }
    await tap(tester, find.text('Kiểm tra câu trả lời'));
    expect(find.text('Trả lời đúng'), findsOneWidget);
    await open(tester, router, '/progress/mistakes');
    expect(find.text('Ghép câu đi học'), findsOneWidget);
    await open(tester, router, '/progress/goals');
    expect(find.text('1 / 5 hoạt động'), findsOneWidget);
    final attempts = (await repo.loadStudyPreview()).attempts;
    expect(attempts.map((row) => row.correct), [true, false]);
  });

  testWidgets('manage local deck, lookup history, reminder and offline pack', (
    tester,
  ) async {
    final (router, repo) = await start(tester, const Size(390, 844), 1);
    final initial = await repo.load();
    await repo.saveWord(
      '1',
      true,
      revision: initial.revision,
      operationId: 'test-saved-word',
    );
    // Refresh the app snapshot after the test seeds a saved word.
    final context = tester.element(find.byType(LocalHanyuApp));
    await ProviderScope.containerOf(context)
        .read(localControllerProvider.notifier)
        .reload();
    await open(tester, router, '/learn/words');
    await tap(tester, find.text('你好'));
    await open(tester, router, '/learn/history');
    expect(find.text('你好'), findsOneWidget);
    await open(tester, router, '/learn/decks');
    await tap(tester, find.text('Tạo bộ từ'));
    await tester.enterText(find.byType(TextFormField), 'Đi học');
    await tap(tester, find.widgetWithText(FilledButton, 'Lưu'));
    await tap(tester, find.text('Đi học'));
    await tap(tester, find.widgetWithText(CheckboxListTile, '你好'));
    expect((await repo.loadStudyPreview()).decks.single.words, ['1']);
    await open(tester, router, '/profile/reminder');
    await tap(tester, find.byType(SwitchListTile));
    await tap(tester, find.text('Lưu lịch học'));
    expect(find.text('Đã lưu lịch trên thiết bị.'), findsOneWidget);
    expect((await repo.loadStudyPreview()).reminder.enabled, isTrue);
    await open(tester, router, '/profile/offline');
    await tap(tester, find.text('Lưu gói mẫu'));
    await tap(tester, find.text('Mở gói'));
    expect(find.text('Gói mẫu HSK 1'), findsOneWidget);
    expect((await repo.loadStudyPreview()).offlineLevels, [1]);
  });
}
