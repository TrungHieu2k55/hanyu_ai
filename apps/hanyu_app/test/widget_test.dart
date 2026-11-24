import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app.dart';

void main() {
  for (final width in [360.0, 390.0, 1366.0]) {
    testWidgets('preview navigation fits $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const HanyuApp());
      await tester.pumpAndSettle();
      expect(find.text('Hanyu AI'), findsOneWidget);
      expect(find.text('Bài học đầu tiên'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in [
        'Ôn tập',
        'Luyện tập',
        'Tiến độ',
        'Cá nhân',
        'Học',
      ]) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('save sample word and finish review without looping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const HanyuApp());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá từ mẫu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lưu 你好'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ôn tập').last);
    await tester.pumpAndSettle();
    expect(find.text('1 từ sẵn sàng xem thử'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu xem thẻ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lật thẻ xem nghĩa'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nhớ'));
    await tester.tap(find.text('Nhớ'));
    await tester.pumpAndSettle();
    expect(find.text('Đã xem hết bộ thẻ mẫu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('practice screens and account form fit at 360 with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const HanyuApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luyện tập').last);
    await tester.pumpAndSettle();
    for (final title in [
      'Luyện viết chữ Hán',
      'Đọc chữ trong ảnh',
      'Hội thoại theo tình huống',
      'Thi thử nghe và đọc',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Cá nhân').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xem đăng nhập / đăng ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem đăng nhập / đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
  });
}
