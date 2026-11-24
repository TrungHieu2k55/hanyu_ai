import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> launch(WidgetTester tester, {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const HanyuApp());
  await tester.pumpAndSettle();
  await tap(tester, find.text('Luyện tập').last);
  await tap(tester, find.text('Hội thoại theo tình huống'));
}

Future<void> start(WidgetTester tester, {String scenario = 'Hỏi đường'}) async {
  await tap(tester, find.text(scenario));
  await tap(tester, find.text('Bắt đầu phiên mẫu'));
}

void main() {
  testWidgets('four scenarios show roles before any session is created', (
    tester,
  ) async {
    await launch(tester, scale: 1.5);
    for (final entry in [
      ('Đón khách tại Đà Nẵng', 'Nhân viên đón khách'),
      ('Hỏi đường', 'Người đang tìm đường'),
      ('Mua hàng Taobao', 'Người mua hàng'),
      ('Giao tiếp thương mại', 'Đại diện doanh nghiệp Việt Nam'),
    ]) {
      await tap(tester, find.text(entry.$1));
      expect(find.text(entry.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Chưa có phiên mẫu. Chọn một tình huống để bắt đầu.'),
      findsOneWidget,
    );
  });

  testWidgets('cancel keeps edited draft without counting a turn', (
    tester,
  ) async {
    await launch(tester);
    await start(tester);
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      '你好',
    );
    await tap(tester, find.text('Tiếp tục hội thoại'));
    await tester.enterText(
      find.byKey(const ValueKey('confirm-turn-input')),
      '请问，车站在哪里？',
    );
    await tap(tester, find.text('Hủy — về bản nháp'));
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
    expect(find.text('请问，车站在哪里？'), findsOneWidget);
    await tap(tester, find.text('Giọng đọc / văn bản thay thế'));
    expect(
      find.text(
        'Chưa có dịch vụ giọng đọc. Hán tự, Pinyin và nghĩa Việt của nội dung mẫu vẫn xem được; phiên hội thoại không bị mất.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft resumes and ending requires confirmation', (tester) async {
    await launch(tester);
    await start(tester);
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      'Bản nháp cần giữ',
    );
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Hỏi đường · phiên 1'));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('conversation-input')))
          .controller!
          .text,
      'Bản nháp cần giữ',
    );
    await tap(tester, find.text('Kết thúc phiên'));
    await tap(tester, find.text('Tiếp tục hội thoại').last);
    expect(find.byKey(const ValueKey('conversation-input')), findsOneWidget);
    await tap(tester, find.text('Kết thúc phiên'));
    await tap(tester, find.text('Kết thúc phiên').last);
    expect(find.text('Đã kết thúc phiên mẫu'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-input')), findsNothing);
    await tap(tester, find.text('Về danh sách tình huống'));
    await tap(tester, find.text('Hỏi đường · phiên 1'));
    expect(find.text('Đã kết thúc phiên mẫu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eight confirmed turns end the session and cannot add a ninth', (
    tester,
  ) async {
    await launch(tester);
    await start(tester);
    for (var i = 1; i <= 8; i++) {
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '你好 $i',
      );
      await tap(tester, find.text('Tiếp tục hội thoại'));
      await tap(tester, find.text('Xác nhận lượt mẫu'));
    }
    expect(find.text('8/8 lượt đã xác nhận · Đã kết thúc'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-input')), findsNothing);
    expect(find.text('Tiếp tục hội thoại'), findsNothing);
    await tap(tester, find.text('Xem lại hội thoại'));
    expect(find.text('Bạn · lượt 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('word details return to the same conversation at large text', (
    tester,
  ) async {
    await launch(tester, scale: 1.5);
    await start(tester);
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      '你好',
    );
    await tap(tester, find.text('Tiếp tục hội thoại'));
    await tap(tester, find.text('Xác nhận lượt mẫu'));
    await tap(tester, find.text('你好 · nǐ hǎo'));
    await tap(tester, find.text('Lưu vào bộ ôn mẫu'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('你好 · nǐ hǎo · Đã lưu mẫu'), findsOneWidget);
    expect(
      find.text('1/8 lượt đã xác nhận · Phiên mẫu đang mở'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
