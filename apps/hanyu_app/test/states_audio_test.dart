import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app.dart';
import 'package:doanchuyennganh2/features/preview/ui_preview.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: finder.toString());
}

Future<void> launch(
  WidgetTester tester, {
  double scale = 1,
  bool gallery = false,
}) async {
  tester.view.physicalSize = const Size(360, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(
    gallery ? const HanyuUiStatesPreview() : const HanyuApp(),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'recording UI returns edited sample text but does not count a turn',
    (tester) async {
      await launch(tester);
      await tap(tester, find.text('Luyện tập').last);
      await tap(tester, find.text('Hội thoại theo tình huống'));
      await tap(tester, find.text('Hỏi đường'));
      await tap(tester, find.text('Bắt đầu phiên mẫu'));
      await tap(tester, find.text('Ghi âm / bản chữ mẫu'));
      await tap(tester, find.text('Bắt đầu mô phỏng ghi âm'));
      await tester.pump(const Duration(seconds: 1));
      await tap(tester, find.text('Dừng mô phỏng'));
      expect(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Phát audio — chưa có tệp',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('recording-transcript')),
        '请问，车站在哪里？',
      );
      await tap(tester, find.text('Dùng bản chữ này'));
      expect(
        find.text('0/8 lượt đã xác nhận · Phiên mẫu đang mở'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('conversation-input')))
            .controller!
            .text,
        '请问，车站在哪里？',
      );
      await tap(tester, find.text('Tiếp tục hội thoại'));
      await tap(tester, find.text('Xác nhận lượt mẫu'));
      expect(
        find.text('1/8 lượt đã xác nhận · Phiên mẫu đang mở'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'listening layout shows unavailable audio without creating an exam attempt',
    (tester) async {
      await launch(tester, scale: 1.5);
      await tap(tester, find.text('Luyện tập').last);
      await tap(tester, find.text('Thi thử nghe và đọc'));
      await tap(tester, find.text('Xem giao diện bài nghe'));
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is IconButton && w.tooltip == 'Phát audio — chưa có tệp',
              ),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.text('Xem bản chép lời mẫu'));
      expect(find.text('你想去哪里？'), findsOneWidget);
      await tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Bạn muốn đi đâu?'),
      );
      await tap(tester, find.text('Xem đáp án minh họa'));
      expect(
        find.text(
          'Đáp án: “Bạn muốn đi đâu?”. Bạn vừa xem bài tập với văn bản mẫu; chưa có phép đo khả năng nghe.',
        ),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa có bài làm. Xem hướng dẫn trước khi bắt đầu.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('CNN screen keeps strokes and labels manual choice honestly', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, find.text('Luyện tập').last);
    await tap(tester, find.text('Luyện viết chữ Hán'));
    await tap(tester, find.text('人 · rén'));
    await tap(tester, find.text('Viết tự do trên canvas'));
    final canvas = find.byKey(const ValueKey('writing-canvas'));
    await tester.ensureVisible(canvas);
    await tester.pumpAndSettle();
    await tester.drag(canvas, const Offset(0, 50));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Nhận diện chữ').last);
    expect(find.text('Nhận diện chưa sẵn sàng'), findsOneWidget);
    expect(find.text('Chọn 人 (mẫu)'), findsNothing);
    await tap(tester, find.text('Chọn chữ thủ công'));
    await tap(tester, find.text('人 · rén · người'));
    expect(
      find.text('Bạn chọn thủ công: 人 · Không phải dự đoán CNN.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Hoàn tác'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'QA gallery renders all states and separates example CNN results',
    (tester) async {
      await launch(tester, gallery: true, scale: 1.5);
      for (final label in [
        'Mất mạng',
        'Thử lại',
        'Hết phiên',
        'Sai quyền',
        'Rỗng',
        'Thiếu audio',
        'Chưa kết nối',
      ]) {
        await tap(tester, find.widgetWithText(ChoiceChip, label));
        expect(find.byType(PreviewStatusPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tap(tester, find.text('Xem kết quả chưa chắc'));
      expect(find.text('Mẫu kết quả chưa chắc chắn'), findsOneWidget);
      expect(find.text('Chọn 人 (mẫu)'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Đang xử lý'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đang xử lý'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'progress uses actual local attempts and activity filter survives opening detail',
    (tester) async {
      await launch(tester, scale: 1.5);
      await tap(tester, find.text('Luyện tập').last);
      await tap(tester, find.text('Thi thử nghe và đọc'));
      await tap(tester, find.text('Mini-test HSK 1'));
      await tap(tester, find.text('Bắt đầu bài mẫu'));
      await tap(tester, find.text('Nộp bài mẫu'));
      await tap(tester, find.text('Nộp và xem kết quả'));
      await tap(tester, find.text('Về danh sách đề'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Tiến độ').last);
      final metric = find
          .ancestor(
            of: find.text('Bài mẫu đã khóa'),
            matching: find.byType(Column),
          )
          .first;
      expect(
        find.descendant(of: metric, matching: find.text('1')),
        findsOneWidget,
      );
      await tap(tester, find.text('Mở lịch hoạt động mẫu'));
      await tap(tester, find.widgetWithText(ChoiceChip, 'Thi'));
      expect(find.text('1 hoạt động mẫu'), findsOneWidget);
      await tap(tester, find.text('Bài mẫu 1 · HSK 1'));
      expect(find.text('Kết quả bài mẫu'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Thi'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
