import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';

Future<void> tapLocal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  late DriftLocalRepository repository;
  setUp(
    () => repository = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
    ),
  );
  tearDown(() => repository.close());

  Future<void> launch(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localRepositoryProvider.overrideWithValue(repository)],
        child: const LocalHanyuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'local word pronunciation requests Mandarin and handles a missing voice',
    (tester) async {
      final calls = <MethodCall>[];
      var languages = ['en-US', 'yue-HK', 'zh-CN'];
      const channel = MethodChannel('flutter_tts');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'getLanguages' ? languages : 1;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await launch(tester, scale: 1.5);
      await tapLocal(tester, find.text('Xem mục từ'));
      final listen = find.byTooltip('Nghe phát âm');
      await tapLocal(tester, listen);

      expect(
        calls.singleWhere((c) => c.method == 'setLanguage').arguments,
        'zh-CN',
      );
      final spoken = calls.singleWhere((c) => c.method == 'speak').arguments;
      expect(find.text(spoken as String), findsOneWidget);
      expect(tester.getSize(listen).shortestSide, greaterThanOrEqualTo(48));

      languages = ['en-US', 'yue-HK'];
      await tapLocal(tester, listen);
      expect(calls.where((c) => c.method == 'speak'), hasLength(1));
      expect(
        find.text(
          'Hãy thêm giọng tiếng Quan thoại trên thiết bị hoặc trình duyệt.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'local vertical slice commits word saved flag and note before app rebuild',
    (tester) async {
      await launch(tester);
      await tapLocal(tester, find.text('Thêm từ riêng'));
      await tester.enterText(find.byType(TextFormField).at(0), '雨伞');
      await tester.enterText(find.byType(TextFormField).at(1), 'yǔsǎn');
      await tester.enterText(find.byType(TextFormField).at(2), 'ô đi mưa');
      await tapLocal(tester, find.text('Lưu từ trên thiết bị'));
      expect(find.text('雨伞'), findsOneWidget);
      await tapLocal(tester, find.text('Lưu vào bộ ôn'));
      final noteElement = tester.element(
        find.byKey(const ValueKey('local-note-input')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('local-note-input')),
        'Ghi chú giữ focus',
      );
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.element(find.byKey(const ValueKey('local-note-input'))),
          noteElement,
        ),
        isTrue,
      );
      await tapLocal(tester, find.text('Lưu ghi chú'));
      expect(find.text('Đã lưu ghi chú trên thiết bị.'), findsOneWidget);
      final record = (await repository.load()).words.singleWhere(
        (w) => w.entry.personal,
      );
      expect(record.saved, isTrue);
      expect(record.note, 'Ghi chú giữ focus');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localRepositoryProvider.overrideWithValue(repository)],
          child: const LocalHanyuApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tapLocal(tester, find.text('Ôn tập').last);
      await tapLocal(tester, find.text('雨伞'));
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Ghi chú của bạn'),
            )
            .controller!
            .text,
        'Ghi chú giữ focus',
      );
      expect(find.text('Bỏ khỏi bộ ôn'), findsOneWidget);
    },
  );

  testWidgets(
    'tab navigation preserves unsaved form and failed commit does not show saved',
    (tester) async {
      await launch(tester, scale: 1.5);
      await tapLocal(tester, find.text('Thêm từ riêng'));
      await tester.enterText(find.byType(TextFormField).first, '朋友');
      await tester.pumpAndSettle();
      await tapLocal(tester, find.text('Cá nhân').last);
      expect(find.text('Rời khi chưa lưu?'), findsOneWidget);
      await tapLocal(tester, find.text('Ở lại'));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '朋友',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'péngyou');
      await tester.enterText(find.byType(TextFormField).at(2), 'bạn');
      // Another successful write makes this editor stale. It must keep the draft.
      final snapshot = await repository.load();
      await repository.saveNote(
        snapshot.words.first.entry.id,
        'Another writer',
        revision: snapshot.revision,
        operationId: 'external',
      );
      await tapLocal(tester, find.text('Lưu từ trên thiết bị'));
      expect(find.textContaining('Dữ liệu đã thay đổi'), findsOneWidget);
      expect(find.text('Đã lưu thay đổi trên thiết bị.'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(2))
            .controller!
            .text,
        'bạn',
      );
      expect(
        (await repository.load()).words.where((w) => w.entry.personal),
        isEmpty,
      );
    },
  );

  testWidgets(
    'local settings commit and remain after navigation at large text',
    (tester) async {
      await launch(tester, scale: 1.5);
      await tapLocal(tester, find.text('Cá nhân').last);
      await tapLocal(tester, find.text('Mục tiêu và âm thanh'));
      await tester.enterText(find.byType(TextField), 'Hiếu');
      await tapLocal(tester, find.text('Âm thanh bài học'));
      await tapLocal(tester, find.text('Lưu cài đặt'));
      expect(find.text('Đã lưu cài đặt trên thiết bị.'), findsOneWidget);
      await tapLocal(tester, find.text('Học').last);
      await tapLocal(tester, find.text('Cá nhân').last);
      expect(find.text('Chào Hiếu'), findsOneWidget);
      expect((await repository.load()).preferences.sound, isFalse);
    },
  );

  testWidgets(
    'startup failure offers retry and never silently substitutes RAM',
    (tester) async {
      await repository.load();
      await repository.db.customStatement('DROP TABLE local_words');
      await launch(tester);
      expect(find.textContaining('Chưa mở được dữ liệu'), findsOneWidget);
      expect(find.text('Thử mở lại'), findsOneWidget);
      expect(find.text('Thêm từ riêng'), findsNothing);
    },
  );
}
