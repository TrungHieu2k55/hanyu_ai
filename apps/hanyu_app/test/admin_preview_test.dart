import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/features/preview/ui_preview.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> launch(WidgetTester tester, {double scale = 1}) async {
  tester.view.physicalSize = const Size(1366, 768);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const HanyuAdminPreview());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin lists and editors fit desktop and large text', (
    tester,
  ) async {
    await launch(tester, scale: 1.5);
    for (final label in ['Từ vựng', 'Đề thi', 'Tình huống', 'Báo lỗi']) {
      await tap(tester, find.text(label).first);
      expect(find.byType(DataTable), findsOneWidget);
      await tap(tester, find.text('Mở').first);
      expect(find.text('Giữ nháp mẫu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
  testWidgets(
    'admin edits drafts then shows reviewed, published and withdrawn sample states',
    (tester) async {
      await launch(tester);
      await tap(tester, find.text('Từ vựng').first);
      await tap(tester, find.text('Mở').first);
      await tester.enterText(find.byType(TextFormField).first, '测试');
      await tap(tester, find.text('Giữ nháp mẫu'));
      expect(find.text('测试'), findsOneWidget);
      for (final action in [
        ('Duyệt (mẫu)', 'Đã duyệt mẫu'),
        ('Công bố (mẫu)', 'Công bố mẫu'),
        ('Thu hồi (mẫu)', 'Thu hồi mẫu'),
      ]) {
        await tap(tester, find.byTooltip('Thao tác bản ghi mẫu').first);
        await tap(tester, find.text(action.$1));
        await tap(tester, find.text('Xác nhận thao tác mẫu'));
        final table = tester.widget<DataTable>(find.byType(DataTable));
        expect((table.rows.first.cells[2].child as Text).data, action.$2);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'CSV preview validates, maps, confirms and returns draft records',
    (tester) async {
      await launch(tester);
      await tap(tester, find.text('Từ vựng').first);
      await tap(tester, find.text('Import từ mẫu'));
      await tap(tester, find.text('Đọc CSV mẫu'));
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(3));
      await tap(tester, find.text('Kiểm tra dữ liệu mẫu'));
      await tap(tester, find.text('Xem xác nhận import'));
      await tap(tester, find.text('Xác nhận import mẫu'));
      await tap(tester, find.text('Về danh sách và giữ nháp'));
      await tester.enterText(find.byType(TextFormField), '早上');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(DataTable), matching: find.text('早上')),
        findsOneWidget,
      );
      expect(find.text('1 bản ghi · Trang 1/1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('CSV import refuses to overwrite existing sample word', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, find.text('Từ vựng').first);
    await tap(tester, find.text('Import từ mẫu'));
    await tester.enterText(
      find.byType(TextField),
      'hanzi,pinyin,vietnamese\n你好,nǐ hǎo,xin chào',
    );
    await tap(tester, find.text('Đọc CSV mẫu'));
    await tap(tester, find.text('Kiểm tra dữ liệu mẫu'));
    expect(
      find.text(
        'Có Hán tự/Pinyin đã tồn tại trong bảng mẫu. Không tự ghi đè; quay lại sửa CSV.',
      ),
      findsOneWidget,
    );
    expect(find.text('Xác nhận import mẫu'), findsNothing);
  });
}
