import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openOcr(WidgetTester tester, {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const HanyuApp());
  await tester.pumpAndSettle();
  await tap(tester, find.text('Luyện tập').last);
  await tap(tester, find.text('Đọc chữ trong ảnh'));
}

Future<void> createSample(WidgetTester tester) async {
  await tap(tester, find.text('Chọn ảnh mẫu'));
  await tap(tester, find.text('Xem văn bản mẫu'));
}

void main() {
  testWidgets(
    'OCR confirms sample before creating history and saves selected words once',
    (tester) async {
      await openOcr(tester);
      await tap(tester, find.text('Chọn ảnh mẫu'));
      await tap(tester, find.text('Đổi nguồn / hủy'));
      expect(find.text('Lịch sử scan mẫu (0)'), findsOneWidget);
      await createSample(tester);
      expect(find.text('Lịch sử scan mẫu (1)'), findsOneWidget);
      await tap(tester, find.text('Tra lại trong từ mẫu'));
      for (final title in ['你好 · nǐ hǎo', '学习 · xuéxí']) {
        await tap(tester, find.text(title));
      }
      await tap(tester, find.text('Lưu 2 từ đã chọn'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lưu 0 từ đã chọn'),
            )
            .onPressed,
        isNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Ôn tập').last);
      expect(find.text('2 từ sẵn sàng xem thử'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing OCR invalidates lookup and requires explicit draft save',
    (tester) async {
      await openOcr(tester);
      await createSample(tester);
      await tap(tester, find.text('Tra lại trong từ mẫu'));
      await tap(tester, find.text('你好 · nǐ hǎo'));
      await tester.enterText(find.byKey(const ValueKey('ocr-editor')), '未知');
      await tester.pumpAndSettle();
      expect(find.text('你好 · nǐ hǎo'), findsNothing);
      await tap(tester, find.text('Tra lại trong từ mẫu'));
      expect(
        find.text(
          'Chưa có từ phù hợp trong bộ mẫu. Không tự tạo nghĩa hoặc Pinyin cho văn bản này.',
        ),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Rời khi chưa lưu?'), findsOneWidget);
      await tap(tester, find.text('Ở lại'));
      await tap(tester, find.text('Giữ bản sửa vào lịch sử mẫu'));
      await tap(tester, find.text('Lịch sử scan mẫu (1)'));
      expect(find.text('未知'), findsOneWidget);
      await tap(tester, find.text('Mở lại kết quả'));
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('ocr-editor')),
      );
      expect(field.controller!.text, '未知');
      expect(find.text('你好！我学习中文。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('discarding the sample image preserves saved scan text', (
    tester,
  ) async {
    await openOcr(tester);
    await createSample(tester);
    await tap(tester, find.text('Lịch sử scan mẫu (1)'));
    await tap(tester, find.text('Bỏ hình minh họa'));
    await tap(tester, find.text('Bỏ ảnh mẫu'));
    expect(find.text('Đã bỏ ảnh mẫu · văn bản còn'), findsOneWidget);
    await tap(tester, find.text('Mở lại kết quả'));
    expect(
      find.text('Ảnh mẫu đã bỏ. Văn bản vẫn còn để xem và chỉnh sửa.'),
      findsOneWidget,
    );
    expect(find.text('你好！我学习中文。'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('OCR screens remain usable at 360 and 150 percent text', (
    tester,
  ) async {
    await openOcr(tester, scale: 1.5);
    await createSample(tester);
    await tap(tester, find.text('Tra lại trong từ mẫu'));
    await tap(tester, find.text('Xem từ 你好'));
    expect(find.text('Chi tiết từ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Lịch sử scan mẫu (1)'));
    expect(find.text('Scan mẫu 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
