import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';

Future<void> tapExam(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: text);
}

void main() {
  late DriftLocalRepository repository;
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2026, 11, 19, 8);
    repository = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => now,
    );
  });
  tearDown(() => repository.close());
  Future<void> launch(WidgetTester tester, {double scale = 1.5}) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRepositoryProvider.overrideWithValue(repository),
          localClockProvider.overrideWithValue(() => now),
        ],
        child: const LocalHanyuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openInstructions(WidgetTester tester) async {
    await tapExam(tester, 'Luyện tập');
    await tapExam(tester, 'Thi thử và luyện đọc');
    await tapExam(tester, 'Luyện 10 câu đọc · cấp 1');
  }

  testWidgets(
    'draft preview creates no attempt; saved answer and cursor survive app recreation; submit freezes result',
    (tester) async {
      await launch(tester);
      await openInstructions(tester);
      expect((await repository.load()).exams.attempts, isEmpty);
      await tapExam(tester, 'Bắt đầu luyện đọc');
      var attempt = (await repository.load()).exams.attempts.single;
      final deadline = attempt.deadline;
      final correct =
          attempt.questions[0].choices[attempt.questions[0].correct];
      await tapExam(tester, correct);
      expect(find.text('Đáp án đang chọn chưa lưu.'), findsOneWidget);
      expect((await repository.load()).exams.attempts.single.answers, isEmpty);
      await tapExam(tester, 'Rời bài, giữ đáp án đã lưu');
      expect(find.text('Rời khi chưa lưu?'), findsOneWidget);
      await tapExam(tester, 'Ở lại');
      await tapExam(tester, 'Lưu đáp án');
      expect(find.text('Đáp án câu này đã lưu.'), findsOneWidget);
      await tapExam(tester, '2');
      expect(find.text('Luyện đọc · câu 2/10'), findsOneWidget);
      await tapExam(tester, 'Rời bài, giữ đáp án đã lưu');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await launch(tester);
      await tapExam(tester, 'Luyện tập');
      await tapExam(tester, 'Thi thử và luyện đọc');
      await tapExam(tester, 'Tiếp tục bài đọc · cấp 1');
      expect(find.text('Luyện đọc · câu 2/10'), findsOneWidget);
      expect(
        (await repository.load()).exams.attempts.single.deadline,
        deadline,
      );
      await tapExam(tester, 'Nộp bài luyện đọc');
      await tapExam(tester, 'Quay lại làm tiếp');
      expect((await repository.load()).exams.attempts.single.done, isFalse);
      await tapExam(tester, 'Nộp bài luyện đọc');
      await tapExam(tester, 'Xác nhận nộp');
      expect(find.text('Kết quả luyện đọc'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Kết quả luyện đọc')).dy,
        greaterThanOrEqualTo(0),
      );
      expect(find.text('1 / 10'), findsOneWidget);
      attempt = (await repository.load()).exams.attempts.single;
      expect(attempt.done, isTrue);
      expect(attempt.blanks, 9);
      await tapExam(tester, 'Về danh sách bài luyện');
      await tapExam(tester, 'Tiến độ');
      expect(find.text('0 ngày liên tiếp'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu tự đánh giá'), findsOneWidget);
      await tapExam(tester, 'Bài đọc');
      expect(find.text('Bài đọc · 1/10 câu'), findsOneWidget);
    },
  );

  testWidgets(
    'timeout ignores an unsaved choice and replaces runner with frozen result',
    (tester) async {
      await launch(tester);
      await openInstructions(tester);
      await tapExam(tester, 'Bắt đầu luyện đọc');
      final attempt = (await repository.load()).exams.attempts.single;
      await tapExam(
        tester,
        attempt.questions[0].choices[attempt.questions[0].correct],
      );
      now = attempt.deadline;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Kết quả luyện đọc'), findsOneWidget);
      final result = (await repository.load()).exams.attempts.single;
      expect(result.timedOut, isTrue);
      expect(result.correctCount, 0);
      expect(result.answers, isEmpty);
    },
  );

  testWidgets(
    'view 20-question draft and missing audio does not start or score a full exam',
    (tester) async {
      await launch(tester);
      await tapExam(tester, 'Luyện tập');
      await tapExam(tester, 'Thi thử và luyện đọc');
      await tapExam(tester, 'Bộ nháp định hướng cấp 1');
      await tapExam(tester, 'Câu 1 · Nghe · thiếu audio');
      expect(find.textContaining('Bản chữ dự thảo:'), findsOneWidget);
      expect((await repository.load()).exams.attempts, isEmpty);
      expect(find.text('Kết quả luyện đọc'), findsNothing);
    },
  );
}
