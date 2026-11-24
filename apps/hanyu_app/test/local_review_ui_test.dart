import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';

Future<void> tapReview(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'durable review resumes next card, rejects repeat taps, and completes only after final card',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = DriftLocalRepository(
        LocalDatabase(NativeDatabase.memory()),
      );
      addTearDown(repository.close);
      var d = await repository.load();
      d = await repository.saveWord(
        '1',
        true,
        revision: d.revision,
        operationId: 'one',
      );
      await repository.saveWord(
        '2',
        true,
        revision: d.revision,
        operationId: 'two',
      );
      Future<void> launch() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [localRepositoryProvider.overrideWithValue(repository)],
            child: const LocalHanyuApp(),
          ),
        );
        await tester.pumpAndSettle();
      }

      await launch();
      await tapReview(tester, 'Ôn tập');
      await tapReview(tester, 'Bắt đầu ôn từ đến hạn');
      expect(find.text('Thẻ 1 / 2'), findsOneWidget);
      await tapReview(tester, 'Lật thẻ xem nghĩa');
      await tester.ensureVisible(find.text('Nhớ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhớ'));
      await tester.tap(find.text('Nhớ'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Thẻ 2 / 2'), findsOneWidget);
      expect((await repository.load()).review.eventCount, 1);
      await tapReview(tester, 'Tạm dừng phiên ôn');
      expect(find.text('Tiếp tục phiên ôn'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await launch();
      await tapReview(tester, 'Ôn tập');
      await tapReview(tester, 'Tiếp tục phiên ôn');
      expect(find.text('Thẻ 2 / 2'), findsOneWidget);
      await tapReview(tester, 'Lật thẻ xem nghĩa');
      await tapReview(tester, 'Dễ');
      expect(find.text('Đã hoàn thành phiên ôn'), findsOneWidget);
      expect((await repository.load()).review.eventCount, 2);
      await tapReview(tester, 'Về lịch ôn');
      expect(find.text('0 từ đến hạn'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
