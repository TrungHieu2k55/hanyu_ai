import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/practice/presentation/handwriting_lookup_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/handwriting_pad.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/local_vocabulary_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/learner_navigation_bar.dart';
import 'package:doanchuyennganh2/shared/widgets/learner_web_navigation.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class LocalFixture {
  LocalFixture(this.router, this.repo);
  final GoRouter router;
  final DriftLocalRepository repo;

  static Future<LocalFixture> open(
    WidgetTester tester,
    double width,
    double scale, {
    bool due = false,
  }) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    final repo = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
    if (due) {
      final initial = await repo.load();
      await repo.saveWord(
        '1',
        true,
        revision: initial.revision,
        operationId: 'seed-hanyu-review',
      );
    }
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
    return LocalFixture(container.read(localRouterProvider), repo);
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  final f = find.text(label).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> showPage(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: path);
}

void main() {
  for (final (width, scale) in [
    (320.0, 2.0),
    (360.0, 1.5),
    (390.0, 1.0),
    (430.0, 2.0),
    (759.0, 1.0),
    (760.0, 1.5),
    (768.0, 1.0),
    (1023.0, 1.0),
    (1024.0, 1.5),
    (1366.0, 1.0),
  ]) {
    testWidgets('learner adapts at $width and $scale text size', (
      tester,
    ) async {
      final fixture = await LocalFixture.open(tester, width, scale);
      if (width < 760) {
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      }
      await showPage(tester, fixture.router, '/practice');
      final nav = find.byType(LearnerWebNavigation);
      expect(nav, width >= 760 ? findsOneWidget : findsNothing);
      expect(
        find.byType(LearnerNavigationBar),
        width < 760 ? findsOneWidget : findsNothing,
      );
      if (width >= 1024) expect(tester.getSize(nav).width, 232);
      for (final path in [
        '/practice/handwriting',
        '/practice/strokes',
        '/photos/new',
        '/review',
        '/practice/lessons/dictation-tea',
      ]) {
        await showPage(tester, fixture.router, path);
      }
    });
  }

  testWidgets(
    'canvas keeps strokes on rotation and clears them without running a model',
    (tester) async {
      final fixture = await LocalFixture.open(tester, 390, 1.5);
      await showPage(tester, fixture.router, '/practice');
      await tapText(tester, 'Viết tay để tra chữ');
      final pad = find.byType(HandwritingPad);
      final recognise = find.widgetWithText(FilledButton, 'Nhận diện chữ');
      expect(recognise, findsNothing);
      final lookup = find.widgetWithText(FilledButton, 'Tra bằng bàn phím');
      expect(tester.getSize(lookup).height, greaterThanOrEqualTo(48));
      expect(tester.getTopLeft(lookup).dy, lessThan(tester.getTopLeft(pad).dy));
      await tester.dragFrom(
        tester.getCenter(pad),
        const Offset(18, 20),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      expect(tester.widget<HandwritingPad>(pad).strokes, hasLength(1));
      tester.view.physicalSize = const Size(760, 390);
      await tester.pumpAndSettle();
      expect(tester.widget<HandwritingPad>(pad).strokes, hasLength(1));
      await tester.ensureVisible(pad);
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getCenter(pad),
        const Offset(14, 15),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<HandwritingPad>(pad).strokes, hasLength(2));
      await tapText(tester, 'Hoàn tác');
      expect(tester.widget<HandwritingPad>(pad).strokes, hasLength(1));
      await tapText(tester, 'Xóa bảng');
      expect(tester.widget<HandwritingPad>(pad).strokes, isEmpty);
      expect(recognise, findsNothing);
    },
  );

  testWidgets(
    'manual lookup preserves the query with keyboard open on a small phone',
    (tester) async {
      final fixture = await LocalFixture.open(tester, 320, 2);
      await showPage(tester, fixture.router, '/practice/handwriting');
      final f = find.byType(TextField);
      await tester.ensureVisible(f);
      await tester.enterText(f, '你好');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Tra bằng bàn phím');
      expect(
        tester
            .widget<LocalVocabularyScreen>(find.byType(LocalVocabularyScreen))
            .initialQuery,
        '你好',
      );
      expect(find.text('你好'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sample recognition displays its illustration and result outside the real canvas',
    (tester) async {
      final fixture = await LocalFixture.open(tester, 390, 1);
      await showPage(tester, fixture.router, '/preview/handwriting');
      expect(
        tester
            .widget<HandwritingLookupScreen>(
              find.byType(HandwritingLookupScreen),
            )
            .preview,
        isTrue,
      );
      await tester.dragFrom(
        tester.getCenter(find.byType(HandwritingPad)),
        const Offset(15, 20),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Xem mẫu khi không có gợi ý');
      expect(find.text('Chưa có chữ phù hợp'), findsOneWidget);
      await tapText(tester, 'Quay lại, giữ nét viết');
      await tapText(tester, 'Nhận diện chữ');
      expect(find.text('Chọn 人 (mẫu)'), findsOneWidget);
      await tapText(tester, 'Chọn 人 (mẫu)');
      expect(find.text('rén · người'), findsOneWidget);
    },
  );

  testWidgets('guided writing uses the selected character and local strokes', (
    tester,
  ) async {
    final f = await LocalFixture.open(tester, 360, 1.5);
    await showPage(tester, f.router, '/practice');
    await tapText(tester, 'Luyện theo nét');
    await tapText(tester, '人 · rén');
    expect(find.text('Phát nét mẫu'), findsOneWidget);
    await tapText(tester, 'Thử luyện theo hai nét mẫu');
    expect(find.byKey(const ValueKey('guided-writing-canvas')), findsOneWidget);
    for (var stroke = 1; stroke <= 2; stroke++) {
      final pad = find.byKey(const ValueKey('guided-writing-canvas'));
      await tester.ensureVisible(pad);
      await tester.pumpAndSettle();
      await tester.dragFrom(tester.getCenter(pad), const Offset(14, 16));
      await tester.pumpAndSettle();
      await tapText(tester, 'Tự xác nhận nét $stroke');
    }
    expect(find.text('Đã thử hai nét mẫu'), findsOneWidget);
  });

  testWidgets(
    'the photo sample opens in its own preview with no local mutations',
    (tester) async {
      final f = await LocalFixture.open(tester, 390, 1.5);
      await showPage(tester, f.router, '/photos/new');
      await tapText(tester, 'Xem kết quả đọc ảnh mẫu');
      expect(find.text('Đọc ảnh · Khu xem mẫu'), findsOneWidget);
      expect((await f.repo.load()).practice, isEmpty);
    },
  );

  testWidgets('empty review offers a single next step', (tester) async {
    final fixture = await LocalFixture.open(tester, 768, 1);
    await showPage(tester, fixture.router, '/review');
    expect(find.text('Từ trong bộ ôn'), findsNothing);
    expect(find.text('Cập nhật hạn ôn'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    await tapText(tester, 'Mở từ điển');
    expect(find.byType(LocalVocabularyScreen), findsOneWidget);
  });

  testWidgets('sidebar supports Tab and Enter in navigation order', (
    tester,
  ) async {
    final f = await LocalFixture.open(tester, 1366, 1);
    await showPage(tester, f.router, '/practice');
    final sidebar = find.byType(LearnerWebNavigation);
    final learn = find.descendant(of: sidebar, matching: find.text('Học'));
    final review = find.descendant(of: sidebar, matching: find.text('Ôn tập'));
    Focus.of(tester.element(learn)).requestFocus();
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(learn)).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(review)).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(f.router.routeInformationProvider.value.uri.path, '/review');
  });

  for (final w in [768.0, 1366.0]) {
    testWidgets(
      'web review persists an active URL and commits a rating once at $w',
      (tester) async {
        final f = await LocalFixture.open(tester, w, 1, due: true);
        await tapText(tester, 'Ôn tập');
        await tapText(tester, 'Bắt đầu ôn từ đến hạn');
        final location = f.router.routeInformationProvider.value.uri.path;
        expect(location, startsWith('/review/session/'));
        await tapText(tester, 'Lật thẻ xem nghĩa');
        await showPage(tester, f.router, '/review');
        await showPage(tester, f.router, location);
        expect(find.text('Ôn tập · Mặt đáp án'), findsOneWidget);
        final rate = find.text('Nhớ');
        await tester.ensureVisible(rate);
        await tester.pumpAndSettle();
        await tester.tap(rate);
        await tester.tap(rate);
        await tester.pumpAndSettle();
        expect((await f.repo.load()).review.events, hasLength(1));
        expect(find.text('Đã hoàn thành phiên ôn'), findsOneWidget);
        await tapText(tester, 'Về lịch ôn');
        expect(find.text('0 từ đến hạn'), findsOneWidget);
      },
    );
  }
}
