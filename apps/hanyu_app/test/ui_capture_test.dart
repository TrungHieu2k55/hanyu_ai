import 'package:doanchuyennganh2/features/ocr/presentation/create_personal_word_action.dart';
import 'package:doanchuyennganh2/features/support/presentation/feedback_screen.dart';

// Optional reference captures, not a cross-platform golden baseline.
// flutter test test/ui_capture_test.dart --dart-define=CAPTURE_UI=true
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app.dart';
import 'package:doanchuyennganh2/features/preview/ui_preview.dart'
    show HanyuAdminPreview, HanyuUiStatesPreview;

import 'package:doanchuyennganh2/core/theme/app_theme.dart';
import 'package:doanchuyennganh2/features/auth/presentation/auth_flow_screens.dart';
import 'package:doanchuyennganh2/features/settings/domain/learning_preferences.dart';
import 'package:doanchuyennganh2/features/writing/presentation/stroke_guide_screen.dart';
import 'package:doanchuyennganh2/features/exam/presentation/exam_layout_screen.dart';
import 'package:doanchuyennganh2/features/admin/presentation/preview_admin_import_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';

void main() {
  testWidgets('capture home with readable local fonts', (tester) async {
    await tester.runAsync(() async {
      final configFile = File('.dart_tool/package_config.json');
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final packages = config['packages'] as List;
      final flutter = packages.cast<Map<String, dynamic>>().firstWhere(
        (p) => p['name'] == 'flutter',
      );
      final packageRoot = configFile.absolute.uri.resolve(
        flutter['rootUri'] as String,
      );
      final sdk = Directory.fromUri(packageRoot).parent.parent.path;
      Future<void> load(String family, String path) async {
        final loader = FontLoader(family)
          ..addFont(
            File(path).readAsBytes().then((v) => ByteData.sublistView(v)),
          );
        await loader.load();
      }

      await load(
        'Roboto',
        '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      );
      await load(
        'MaterialIcons',
        '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      );
      if (File('C:/Windows/Fonts/msyh.ttc').existsSync()) {
        await load('Microsoft YaHei', 'C:/Windows/Fonts/msyh.ttc');
      }
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: const HanyuApp()));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('test/previews').create(recursive: true);
        await File('test/previews/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('home-390');
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Khám phá từ mẫu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá từ mẫu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xem chi tiết').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem chi tiết').first);
    await tester.pumpAndSettle();
    await capture('word-detail-390');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luyện tập').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đọc chữ trong ảnh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đọc chữ trong ảnh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Chọn ảnh mẫu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn ảnh mẫu'));
    await tester.pumpAndSettle();
    await capture('ocr-preview-390');
    await tester.ensureVisible(find.text('Xem văn bản mẫu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem văn bản mẫu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tra lại trong từ mẫu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tra lại trong từ mẫu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('ocr-editor')));
    await tester.pumpAndSettle();
    await capture('ocr-result-390');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hội thoại theo tình huống'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hội thoại theo tình huống'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hỏi đường'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hỏi đường'));
    await tester.pumpAndSettle();
    await capture('roleplay-intro-390');
    await tester.ensureVisible(find.text('Bắt đầu phiên mẫu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu phiên mẫu'));
    await tester.pumpAndSettle();
    await capture('roleplay-room-390');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thi thử nghe và đọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thi thử nghe và đọc'));
    await tester.pumpAndSettle();
    await capture('exam-list-390');
    await tester.ensureVisible(find.text('Mini-test HSK 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mini-test HSK 1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bắt đầu bài mẫu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu bài mẫu'));
    await tester.pumpAndSettle();
    await capture('exam-question-390');
    await tester.pageBack();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1366, 768);
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const HanyuAdminPreview()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ vựng').first);
    await tester.pumpAndSettle();
    await capture('admin-vocabulary-1366');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(RepaintBoundary(key: key, child: const HanyuApp()));
    await tester.pumpAndSettle();
    Future<void> tapVisible(String label) async {
      await tester.ensureVisible(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await tapVisible('Luyện tập');
    await tapVisible('Đọc chữ trong ảnh');
    await tapVisible('Chọn ảnh mẫu');
    await tapVisible('Xem văn bản mẫu');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible('Tiến độ');
    await capture('progress-local-390');
    await tapVisible('Mở lịch hoạt động mẫu');
    await capture('activity-history-390');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible('Luyện tập');
    await tapVisible('Thi thử nghe và đọc');
    await tapVisible('Xem giao diện bài nghe');
    await capture('listening-390');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapVisible('Hội thoại theo tình huống');
    await tapVisible('Hỏi đường');
    await tapVisible('Bắt đầu phiên mẫu');
    await tapVisible('Ghi âm / bản chữ mẫu');
    await tapVisible('Bắt đầu mô phỏng ghi âm');
    await tester.pump(const Duration(seconds: 1));
    await capture('recording-simulated-390');
    await tapVisible('Dừng mô phỏng');
    tester.view.physicalSize = const Size(1366, 768);
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const HanyuUiStatesPreview()),
    );
    await tester.pumpAndSettle();
    await capture('ui-states-1366');

    Future<void> renderScreen(String name, Widget screen, Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: AppTheme.light,
            home: DetailScaffold(title: 'Hanyu AI', body: screen),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(name);
      expect(tester.takeException(), isNull);
    }

    await renderScreen(
      'email-verification-360',
      EmailVerificationScreen(
        email: 'demo@example.com',
        preferences: LearningPreferences(),
      ),
      const Size(360, 844),
    );
    await renderScreen(
      'stroke-guide-360',
      const StrokeGuideScreen(hanzi: '人', pinyin: 'rén', meaning: 'người'),
      const Size(360, 844),
    );
    await renderScreen(
      'exam-layout-390',
      const ExamLayoutScreen(level: 1),
      const Size(390, 844),
    );
    await renderScreen(
      'csv-import-1366',
      const PreviewAdminImportScreen(existing: {}),
      const Size(1366, 768),
    );

    await renderScreen(
      'ocr-personal-entry-390',
      CreatePersonalWordAction(
        text: '雨伞',
        words: const [],
        nextId: () => 'capture:personal',
        onCreated: (_) {},
      ),
      const Size(390, 844),
    );
    await tapVisible('Tạo từ riêng từ văn bản');
    await capture('ocr-personal-editor-390');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await renderScreen(
      'feedback-entry-360',
      const FeedbackScreen(contextLabel: '朋友 · péngyou'),
      const Size(360, 844),
    );
    await tester.enterText(
      find.byType(TextField),
      'Nhờ kiểm tra nghĩa và Pinyin',
    );
    await tapVisible('Xem lại bản nháp');
    await tapVisible('Xem trạng thái gửi mẫu');
    await tapVisible('Xem lỗi mẫu');
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await capture('feedback-error-360');

    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('CAPTURE_UI'));
}
