import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app.dart';

Future<void> launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const HanyuApp());
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openWords(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -300));
  await tester.pumpAndSettle();
  await tap(tester, find.text('Khám phá từ mẫu'));
}

void main() {
  testWidgets('search accepts unaccented pinyin and clears empty results', (
    tester,
  ) async {
    await launch(tester);
    await openWords(tester);
    await tester.enterText(find.byType(TextField), 'xuexi');
    await tester.pumpAndSettle();
    expect(find.text('学习'), findsOneWidget);
    expect(find.text('1 từ mẫu'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not-a-word');
    await tester.pumpAndSettle();
    expect(find.text('Chưa tìm thấy từ phù hợp'), findsOneWidget);
    await tap(tester, find.text('Xem lại tất cả'));
    expect(find.text('你好'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notes are separate, editable and protected on Back', (
    tester,
  ) async {
    await launch(tester);
    await openWords(tester);
    await tap(tester, find.text('Xem chi tiết').first);
    await tap(tester, find.text('Sửa ghi chú'));
    await tester.enterText(find.byType(TextField), 'Ghi chú ban đầu');
    await tap(tester, find.text('Giữ ghi chú mẫu'));
    expect(find.text('Ghi chú ban đầu'), findsOneWidget);
    await tap(tester, find.text('Sửa ghi chú'));
    await tester.enterText(find.byType(TextField), 'Chỉnh chưa lưu');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Rời khi chưa lưu?'), findsOneWidget);
    await tap(tester, find.text('Ở lại'));
    expect(find.text('Chỉnh chưa lưu'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Bỏ thay đổi và rời'));
    expect(find.text('Ghi chú ban đầu'), findsOneWidget);
    expect(find.text('xin chào'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing a saved word requires confirmation', (tester) async {
    await launch(tester);
    await openWords(tester);
    await tap(tester, find.byTooltip('Lưu 你好'));
    await tap(tester, find.byTooltip('Bỏ lưu 你好'));
    await tap(tester, find.text('Giữ lại'));
    expect(find.byTooltip('Bỏ lưu 你好'), findsOneWidget);
    await tap(tester, find.byTooltip('Bỏ lưu 你好'));
    await tap(tester, find.text('Bỏ khỏi bộ ôn'));
    expect(find.byTooltip('Lưu 你好'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review resumes and rapid rating taps do not skip a card', (
    tester,
  ) async {
    await launch(tester);
    await openWords(tester);
    await tap(tester, find.byTooltip('Lưu 你好'));
    await tap(tester, find.byTooltip('Lưu 学习'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Ôn tập').last);
    await tap(tester, find.text('Bắt đầu xem thẻ'));
    await tap(tester, find.text('Lật thẻ xem nghĩa'));
    await tester.ensureVisible(find.text('Nhớ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhớ'));
    await tester.tap(find.text('Nhớ'));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 2 / 2'), findsOneWidget);
    await tap(tester, find.text('Tạm dừng phiên mẫu'));
    await tap(tester, find.text('Tiếp tục phiên mẫu'));
    expect(find.text('Thẻ 2 / 2'), findsOneWidget);
    await tap(tester, find.text('Lật thẻ xem nghĩa'));
    await tap(tester, find.text('Dễ'));
    expect(find.text('Nhớ: 1 thẻ'), findsOneWidget);
    expect(find.text('Dễ: 1 thẻ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recovery shows expired link and validates password confirmation',
    (tester) async {
      await launch(tester);
      await tap(tester, find.text('Cá nhân').last);
      await tap(tester, find.text('Xem đăng nhập / đăng ký'));
      await tap(tester, find.text('Quên mật khẩu?'));
      await tester.enterText(find.byType(TextFormField), 'sample@example.com');
      await tap(tester, find.text('Xem bước kiểm tra email'));
      await tap(tester, find.text('Xem liên kết hết hạn'));
      await tap(tester, find.text('Nhập lại email'));
      await tester.enterText(find.byType(TextFormField), 'sample@example.com');
      await tap(tester, find.text('Xem bước kiểm tra email'));
      await tap(tester, find.text('Mở liên kết mẫu hợp lệ'));
      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'sample-pass',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password')),
        'different-pass',
      );
      await tap(tester, find.text('Kiểm tra mật khẩu mới'));
      expect(find.text('Hai mật khẩu chưa khớp.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password')),
        'sample-pass',
      );
      await tap(tester, find.text('Kiểm tra mật khẩu mới'));
      expect(
        find.text('Đã hoàn thành luồng mẫu. Mật khẩu thật chưa được thay đổi.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings survive reopening while consent stays independent', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, find.text('Cá nhân').last);
    await tap(tester, find.text('Mục tiêu và âm thanh'));
    await tap(tester, find.text('HSK 3'));
    await tap(tester, find.text('30 phút'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('HSK 3 · 30 phút mỗi ngày · mẫu'), findsOneWidget);
    await tap(tester, find.text('Xem đăng nhập / đăng ký'));
    await tap(tester, find.text('Chưa có tài khoản? Đăng ký'));
    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(boxes.map((w) => w.value), [false, false]);
    await tap(tester, find.text('Tôi đồng ý Điều khoản sử dụng'));
    final changed = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(changed.map((w) => w.value), [true, false]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'writing warns before discarding strokes and preserves them on Stay',
    (tester) async {
      await launch(tester);
      await tap(tester, find.text('Luyện tập').last);
      await tap(tester, find.text('Luyện viết chữ Hán'));
      await tap(tester, find.text('人 · rén'));
      await tap(tester, find.text('Viết tự do trên canvas'));
      final canvas = find.byKey(const ValueKey('writing-canvas'));
      await tester.ensureVisible(canvas);
      await tester.pumpAndSettle();
      await tester.drag(canvas, const Offset(0, 60));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Rời khi chưa lưu?'), findsOneWidget);
      await tap(tester, find.text('Ở lại'));
      expect(canvas, findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Bỏ thay đổi và rời'));
      expect(find.text('Chế độ luyện viết'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reading policies preserves signup input at 360 and text 150 percent',
    (tester) async {
      await launch(tester);
      tester.view.physicalSize = const Size(360, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Cá nhân').last);
      await tap(tester, find.text('Xem đăng nhập / đăng ký'));
      await tester.enterText(
        find.byType(TextFormField).first,
        'sample@example.com',
      );
      await tap(tester, find.text('Chưa có tài khoản? Đăng ký'));
      await tap(tester, find.text('Đọc điều khoản và quyền riêng tư'));
      expect(find.text('Tài khoản và dữ liệu học'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('account-email')))
            .controller!
            .text,
        'sample@example.com',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
