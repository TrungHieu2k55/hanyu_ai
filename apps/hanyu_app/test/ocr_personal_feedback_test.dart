import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app.dart';
import 'package:doanchuyennganh2/core/theme/app_theme.dart';
import 'package:doanchuyennganh2/features/support/presentation/feedback_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> viewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => tester.pumpWidget(const SizedBox()));
}

Future<void> openUnknownWord(WidgetTester tester) async {
  await viewport(tester);
  await tester.pumpWidget(const HanyuApp());
  await tester.pumpAndSettle();
  await tap(tester, find.text('Luyện tập').last);
  await tap(tester, find.text('Đọc chữ trong ảnh'));
  await tap(tester, find.text('Chọn ảnh mẫu'));
  await tap(tester, find.text('Xem văn bản mẫu'));
  await tester.enterText(find.byKey(const ValueKey('ocr-editor')), '雨伞');
  await tap(tester, find.text('Giữ bản sửa vào lịch sử mẫu'));
  await tap(tester, find.text('Tra lại trong từ mẫu'));
  await tap(tester, find.text('Tạo từ riêng từ văn bản'));
}

Future<void> fillWord(WidgetTester tester) async {
  expect(
    tester
        .widget<TextFormField>(find.byType(TextFormField).first)
        .controller!
        .text,
    '雨伞',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'yǔsǎn');
  await tester.enterText(find.byType(TextFormField).at(2), 'ô đi mưa của tôi');
  await tap(tester, find.text('Giữ từ cá nhân mẫu'));
}

void main() {
  testWidgets(
    'OCR unknown word becomes a private draft and only explicit selection adds review',
    (tester) async {
      await openUnknownWord(tester);
      await fillWord(tester);
      expect(find.text('Từ riêng từ văn bản'), findsNothing);
      expect(find.text('雨伞 · yǔsǎn'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lưu 0 từ đã chọn'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.text('雨伞 · yǔsǎn'));
      await tap(tester, find.text('Lưu 1 từ đã chọn'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Ôn tập').last);
      expect(find.text('1 từ sẵn sàng xem thử'), findsOneWidget);
      await tap(tester, find.text('Bắt đầu xem thẻ'));
      await tap(tester, find.text('Lật thẻ xem nghĩa'));
      expect(find.text('ô đi mưa của tôi'), findsOneWidget);
    },
  );

  testWidgets('OCR cancel keeps scan and repeated personal word is rejected', (
    tester,
  ) async {
    await openUnknownWord(tester);
    await tester.enterText(find.byType(TextFormField).at(1), 'nháp');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(tester, find.text('Ở lại'));
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'nháp',
    );
    await tap(tester, find.text('Hủy chỉnh sửa'));
    await tap(tester, find.text('Bỏ thay đổi và rời'));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('ocr-editor')))
          .controller!
          .text,
      '雨伞',
    );
    expect(find.text('雨伞 · yǔsǎn'), findsNothing);
    await tap(tester, find.text('Tạo từ riêng từ văn bản'));
    await fillWord(tester);
    await tap(tester, find.text('Tạo từ riêng từ văn bản'));
    await fillWord(tester);
    expect(
      find.text('Từ riêng với Hán tự và Pinyin này đã có. Hãy sửa từ hiện có.'),
      findsOneWidget,
    );
    expect(find.text('Từ riêng từ văn bản'), findsOneWidget);
  });

  testWidgets(
    'feedback outcomes preserve context and draft across cancel retry and edits',
    (tester) async {
      await viewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const DetailScaffold(
            title: 'Báo lỗi học liệu',
            body: FeedbackScreen(contextLabel: '朋友 · péngyou'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Nhờ kiểm tra nghĩa và Pinyin',
      );
      await tap(tester, find.text('Xem lại bản nháp'));
      await tap(tester, find.text('Xem trạng thái gửi mẫu'));
      await tap(tester, find.text('Hủy'));
      expect(find.text('Nội dung: 朋友 · péngyou'), findsOneWidget);
      await tap(tester, find.text('Xem trạng thái gửi mẫu'));
      await tap(tester, find.text('Xem lỗi mẫu'));
      expect(find.textContaining('Lỗi gửi minh họa.'), findsOneWidget);
      await tap(tester, find.text('Xem thử lại, giữ bản nháp'));
      await tap(tester, find.text('Xem đã nhận mẫu'));
      expect(
        find.textContaining('Không có phản hồi thật được gửi'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nhờ kiểm tra nghĩa và Pinyin',
      );
      await tester.enterText(find.byType(TextField), 'Bổ sung nội dung');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không có phản hồi thật được gửi'),
        findsNothing,
      );
      expect(find.text('Nội dung: 朋友 · péngyou'), findsOneWidget);
    },
  );
}
