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
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(const HanyuApp());
  await tester.pumpAndSettle();
}

Future<void> openExams(WidgetTester tester) async {
  await tap(tester, find.text('Luyện tập').last);
  await tap(tester, find.text('Thi thử nghe và đọc'));
}

void main() {
  testWidgets(
    'exam instructions do not create attempt until Start; answers resume',
    (tester) async {
      await launch(tester);
      await openExams(tester);
      await tap(tester, find.text('Mini-test HSK 1'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa có bài làm. Xem hướng dẫn trước khi bắt đầu.'),
        findsOneWidget,
      );
      await tap(tester, find.text('Mini-test HSK 1'));
      await tap(tester, find.text('Bắt đầu bài mẫu'));
      await tap(tester, find.text('Bạn bè'));
      await tap(tester, find.text('Câu tiếp'));
      await tap(tester, find.text('Rời và giữ bài tạm'));
      await tap(tester, find.text('Tiếp tục bài 1 · HSK 1'));
      expect(find.text('Câu 2 / 4'), findsOneWidget);
      await tap(tester, find.text('Câu trước'));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.radio_button_checked)).icon,
        Icons.radio_button_checked,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('exam submit handles blanks and locks answer edits', (
    tester,
  ) async {
    await launch(tester);
    await openExams(tester);
    await tap(tester, find.text('Mini-test HSK 2'));
    await tap(tester, find.text('Bắt đầu bài mẫu'));
    await tap(tester, find.text('Bạn bè'));
    await tap(tester, find.text('Câu tiếp'));
    await tap(tester, find.text('xièxie'));
    await tap(tester, find.text('Câu 4'));
    await tap(tester, find.text('Tôi học tiếng Trung.'));
    await tap(tester, find.text('Nộp bài mẫu'));
    expect(
      find.text(
        'Còn 1 câu chưa chọn. Sau khi nộp không thể sửa đáp án của bài này.',
      ),
      findsOneWidget,
    );
    await tap(tester, find.text('Tiếp tục làm'));
    expect(find.text('Kết quả bài mẫu'), findsNothing);
    await tap(tester, find.text('Nộp bài mẫu'));
    await tap(tester, find.text('Nộp và xem kết quả'));
    expect(find.text('Đúng 2/4 · sai 1 · bỏ trống 1'), findsOneWidget);
    expect(find.text('Nộp bài mẫu'), findsNothing);
    await tap(tester, find.text('Về danh sách đề'));
    expect(find.text('Đã khóa bài · đúng 2/4 · đã nộp'), findsOneWidget);
    await tap(tester, find.text('Bài 1 · HSK 2'));
    expect(find.text('Kết quả bài mẫu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile, onboarding and device screens are reachable', (
    tester,
  ) async {
    await launch(tester, scale: 1.5);
    await tap(tester, find.text('Cá nhân').last);
    await tap(tester, find.text('Sửa hồ sơ mẫu'));
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Người học mẫu',
    );
    await tap(tester, find.text('Giữ hồ sơ mẫu'));
    expect(find.text('Người học mẫu'), findsOneWidget);
    await tap(tester, find.text('Hướng dẫn bắt đầu'));
    await tap(tester, find.text('Xem hướng dẫn từng bước'));
    await tap(tester, find.text('Tiếp theo'));
    await tap(tester, find.text('Tiếp theo'));
    await tap(tester, find.text('Hoàn tất xem hướng dẫn'));
    await tap(tester, find.text('Quyền camera và microphone'));
    await tap(tester, find.text('Xem hướng dẫn quyền bị từ chối'));
    expect(find.text('Nếu quyền bị từ chối'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('deletion preview never claims a real deletion request', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, find.text('Cá nhân').last);
    await tap(tester, find.text('Quyền riêng tư'));
    await tap(tester, find.text('Xem quy trình xóa tài khoản'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xem xác nhận minh họa'),
          )
          .onPressed,
      isNull,
    );
    await tap(
      tester,
      find.text('Tôi hiểu đây là luồng minh họa, chưa gửi yêu cầu.'),
    );
    await tap(tester, find.text('Xem xác nhận minh họa'));
    expect(find.text('Chưa gửi yêu cầu xóa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'personal meanings do not overwrite shared vocabulary and can be reviewed',
    (tester) async {
      await launch(tester);
      await tap(tester, find.text('Ôn tập').last);
      await tap(tester, find.text('Từ cá nhân của tôi'));
      await tap(tester, find.text('Thêm từ cá nhân'));
      await tester.enterText(find.byType(TextFormField).at(0), '你好');
      await tester.enterText(find.byType(TextFormField).at(1), 'nǐ hǎo');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Lời chào riêng',
      );
      await tap(tester, find.text('Giữ từ cá nhân mẫu'));
      await tap(tester, find.text('Mở và lưu vào bộ ôn'));
      expect(find.text('Từ riêng · chưa kiểm duyệt'), findsOneWidget);
      await tap(tester, find.text('Lưu vào bộ ôn mẫu'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Bắt đầu xem thẻ'));
      await tap(tester, find.text('Lật thẻ xem nghĩa'));
      expect(find.text('Lời chào riêng'), findsOneWidget);
      await tap(tester, find.text('Tạm dừng phiên mẫu'));
      await tap(tester, find.text('Học').last);
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Khám phá từ mẫu'));
      await tester.enterText(find.byType(TextField), '你好');
      await tester.pumpAndSettle();
      expect(find.text('xin chào'), findsOneWidget);
      expect(find.text('Lời chào riêng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
