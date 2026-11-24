import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app.dart';
import 'package:doanchuyennganh2/features/admin/data/csv_file_source.dart';
import 'package:doanchuyennganh2/features/admin/presentation/preview_admin_import_screen.dart';
import 'package:doanchuyennganh2/features/admin/domain/admin_record.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/core/theme/app_theme.dart';
import 'package:doanchuyennganh2/features/auth/presentation/auth_screen.dart';

class DemoCsvSource implements CsvFileSource {
  const DemoCsvSource();
  @override
  Future<PickedCsv?> pick() async =>
      const PickedCsv('words.csv', 'h,p,v\n早上,zǎoshang,"sáng, chào"\n晚上,,tối');
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: finder.toString());
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

void main() {
  testWidgets('guest samples return to the intended word without saving', (
    tester,
  ) async {
    await launch(tester, scale: 1.5);
    await tap(tester, find.text('Cá nhân').last);
    await tap(tester, find.text('Hướng dẫn bắt đầu'));
    await tap(tester, find.text('Xem thử không cần tài khoản'));
    await tap(tester, find.text('Xem từ 朋友'));
    expect(find.text('Bạn đang xem thử'), findsOneWidget);
    await tap(tester, find.text('Xem thử nét chữ 人'));
    expect(find.text('Quan sát hướng từng nét'), findsOneWidget);
    await tap(tester, find.text('Quay lại nội dung xem thử'));
    await tap(tester, find.text('Thêm vào ôn tập'));
    expect(find.text(AccountIntent.saveWord.description), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa tạo thẻ ôn hoặc ghi lịch sử cá nhân.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'registration verifies confirmation and shows email states without authenticating',
    (tester) async {
      await launch(tester);
      await tap(tester, find.text('Cá nhân').last);
      await tap(tester, find.text('Xem đăng nhập / đăng ký'));
      await tap(tester, find.text('Chưa có tài khoản? Đăng ký'));
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        'demo@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'sample-pass',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-confirmation')),
        'different',
      );
      await tap(tester, find.text('Kiểm tra form đăng ký'));
      expect(find.text('Hai mật khẩu chưa khớp.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('account-confirmation')),
        'sample-pass',
      );
      await tap(tester, find.text('Tôi đồng ý Điều khoản sử dụng'));
      await tap(tester, find.text('Kiểm tra form đăng ký'));
      expect(find.text('Chờ kiểm tra email'), findsOneWidget);
      await tap(tester, find.text('Xem liên kết hết hạn (mẫu)'));
      expect(find.text('Liên kết mẫu hết hạn'), findsOneWidget);
      await tap(tester, find.text('Xem gửi lại email (mẫu)'));
      expect(
        find.text(
          'Đã xem thao tác gửi lại mẫu. Không có email thật nào được gửi.',
        ),
        findsOneWidget,
      );
      await tap(tester, find.text('Xem xác minh thành công (mẫu)'));
      await tap(tester, find.text('Chọn mục tiêu học mẫu'));
      expect(find.text('Mục tiêu HSK'), findsOneWidget);
    },
  );
  testWidgets('Google unavailable returns to the unchanged form', (
    tester,
  ) async {
    await launch(tester, scale: 1.5);
    await tap(tester, find.text('Cá nhân').last);
    await tap(tester, find.text('Xem đăng nhập / đăng ký'));
    await tester.enterText(
      find.byType(TextFormField).first,
      'demo@example.com',
    );
    await tap(tester, find.text('Tiếp tục với Google'));
    expect(find.text('Đăng nhập chưa sẵn sàng'), findsOneWidget);
    await tap(tester, find.text('Về form, giữ thông tin đang nhập'));
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'demo@example.com',
    );
  });
  testWidgets('account action stays above the keyboard at 360 and 150%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.learner,
        home: const AuthScreen(returnTo: AccountIntent.photo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AccountIntent.photo.description), findsOneWidget);
    final email = find.byKey(const ValueKey('account-email'));
    await tester.ensureVisible(email);
    await tester.enterText(email, 'demo@example.com');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.text('Kiểm tra form đăng nhập')).dy,
      lessThan(524),
    );
    expect(
      tester.widget<TextFormField>(email).controller!.text,
      'demo@example.com',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'deletion processing, error and complete remain explicitly sample states',
    (tester) async {
      await launch(tester, scale: 1.5);
      await tap(tester, find.text('Cá nhân').last);
      await tap(tester, find.text('Quyền riêng tư'));
      await tap(tester, find.text('Xem quy trình xóa tài khoản'));
      await tap(
        tester,
        find.text('Tôi hiểu đây là luồng minh họa, chưa gửi yêu cầu.'),
      );
      await tap(tester, find.text('Xem xác nhận minh họa'));
      await tap(tester, find.text('Xem trạng thái đang xử lý (mẫu)'));
      await tap(tester, find.text('Xem lỗi xử lý (mẫu)'));
      expect(find.text('Chưa xử lý được · trạng thái mẫu'), findsOneWidget);
      await tap(tester, find.text('Xem lại bước xử lý (mẫu)'));
      await tap(tester, find.text('Xem hoàn tất (mẫu)'));
      expect(find.text('Hoàn tất · trạng thái mẫu'), findsOneWidget);
    },
  );
  testWidgets(
    'guide animates and manual stroke practice has no fabricated grade',
    (tester) async {
      await launch(tester);
      await tap(tester, find.text('Luyện tập').last);
      await tap(tester, find.text('Luyện viết chữ Hán'));
      await tap(tester, find.text('人 · rén'));
      await tap(tester, find.text('Hướng dẫn và quiz theo nét'));
      await tap(tester, find.text('Phát nét mẫu'));
      await tap(tester, find.text('Nét tiếp'));
      expect(find.text('Nét 2 / 2 · mác sang phải'), findsOneWidget);
      await tap(tester, find.text('Thử luyện theo hai nét mẫu'));
      for (var i = 1; i <= 2; i++) {
        final pad = find.byKey(const ValueKey('guided-writing-canvas'));
        await tester.ensureVisible(pad);
        await tester.pumpAndSettle();
        await tester.drag(pad, const Offset(20, 50));
        await tester.pumpAndSettle();
        await tap(tester, find.text('Tự xác nhận nét $i'));
      }
      expect(find.text('Đã thử hai nét mẫu'), findsOneWidget);
      expect(find.textContaining('Chưa chấm đúng/sai'), findsOneWidget);
    },
  );
  testWidgets(
    '20-question layout has both sections and does not create a real attempt',
    (tester) async {
      await launch(tester, scale: 1.5);
      await tap(tester, find.text('Luyện tập').last);
      await tap(tester, find.text('Thi thử nghe và đọc'));
      await tap(tester, find.text('Mini-test HSK 1'));
      await tap(tester, find.text('Xem bố cục 20 câu nghe/đọc'));
      expect(find.text('Phần nghe · câu 1–10'), findsOneWidget);
      expect(find.text('Phần đọc · câu 11–20'), findsOneWidget);
      await tap(tester, find.widgetWithText(ChoiceChip, '20'));
      await tap(tester, find.text('Về hướng dẫn đề'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa có bài làm. Xem hướng dẫn trước khi bắt đầu.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'file picking and partial CSV import require explicit confirmation',
    (tester) async {
      await launch(tester);
      List<AdminRecord>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.push<List<AdminRecord>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DetailScaffold(
                        title: 'Import',
                        body: PreviewAdminImportScreen(
                          existing: {},
                          fileSource: DemoCsvSource(),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open import'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('Open import'));
      await tap(tester, find.text('Chọn tệp CSV'));
      expect(find.text('Tệp: words.csv'), findsOneWidget);
      await tap(tester, find.text('Đọc CSV mẫu'));
      await tap(tester, find.text('Kiểm tra dữ liệu mẫu'));
      expect(find.text('1 bản ghi hợp lệ · 1 bản ghi có lỗi'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xem xác nhận import'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.text('Chỉ giữ dòng hợp lệ, bỏ qua dòng lỗi'));
      await tap(tester, find.text('Xem xác nhận import'));
      await tap(tester, find.text('Xác nhận import mẫu'));
      await tap(tester, find.text('Về danh sách và giữ nháp'));
      expect(result!.single.fields['Nghĩa Việt'], 'sáng, chào');
    },
  );
}
