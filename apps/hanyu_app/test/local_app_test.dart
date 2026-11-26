import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

import 'content_package_contract_test.dart' as fixture;

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

  Future<void> launch(
    WidgetTester tester, {
    double scale = 1,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 844);
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

  for (final width in [360.0, 390.0, 768.0, 1366.0]) {
    testWidgets('dictionary filters the active HSK catalog at $width px', (
      tester,
    ) async {
      final pack = fixture.pack(
        records: [
          fixture.record(
            100,
            payload: VocabularyContent(
              hanzi: '朋友',
              pinyin: 'péngyou',
              vietnamese: 'Bạn bè',
              targetLevel: 1,
              exampleHanzi: '他是我的朋友。',
              exampleVietnamese: 'Anh ấy là bạn của tôi.',
            ),
          ),
          fixture.record(
            101,
            payload: VocabularyContent(
              hanzi: '同伴',
              pinyin: 'tóngbàn',
              vietnamese: 'Bạn đồng hành',
              targetLevel: 2,
            ),
          ),
          fixture.record(
            102,
            payload: VocabularyContent(
              hanzi: '机场',
              pinyin: 'jīchǎng',
              vietnamese: 'Sân bay',
              targetLevel: 2,
            ),
          ),
        ],
      );
      final plan = await repository.preparePackageInstall(pack.toFile());
      final data = await repository.installPackage(
        plan,
        operationId: 'install-hsk',
        acceptTrial: true,
        activate: true,
      );
      await repository.putWord(
        const VocabularyItem(
          id: 'personal:hsk-test',
          level: null,
          hanzi: '同学',
          pinyin: 'tóngxué',
          vietnamese: 'Bạn cùng lớp',
          exampleHanzi: '',
          exampleVietnamese: 'Bạn cùng lớp của tôi.',
          personal: true,
        ),
        revision: data.revision,
        operationId: 'put-personal',
      );

      await launch(tester, width: width, scale: width == 360 ? 1.5 : 1);
      expect(find.widgetWithText(ChoiceChip, 'HSK 2'), findsNothing);
      await tapLocal(tester, find.text('Mở từ điển'));
      final search = find.byType(TextField);
      final hsk2 = find.widgetWithText(ChoiceChip, 'HSK 2');
      Finder result(String name) => find.widgetWithText(ListTile, name);
      await tapLocal(tester, hsk2);
      await tester.enterText(search, 'ban');
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(hsk2).selected, isTrue);
      expect(result('同伴'), findsOneWidget);
      expect(result('朋友'), findsNothing);
      expect(result('机场'), findsNothing);
      expect(result('同学'), findsNothing);
      expect(result('你好'), findsNothing);
      await tester.enterText(search, 'ban be');
      await tester.pumpAndSettle();
      await tapLocal(tester, find.text('Bỏ lọc cấp'));
      expect(
        tester.widget<TextField>(search).controller?.text ??
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
        'ban be',
      );
      expect(result('朋友'), findsOneWidget);
      await tapLocal(tester, result('朋友'));
      expect(find.byTooltip('Nghe câu ví dụ'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.enterText(search, 'ban');
      await tester.pumpAndSettle();
      await tapLocal(tester, hsk2);
      await tapLocal(tester, find.text('Từ riêng của tôi'));
      expect(tester.widget<ChoiceChip>(hsk2).selected, isFalse);
      expect(result('同学'), findsOneWidget);
      expect(result('同伴'), findsNothing);
      await tapLocal(tester, result('同学'));
      expect(find.byTooltip('Nghe câu ví dụ'), findsNothing);
      expect(find.text('Bạn cùng lớp của tôi.'), findsOneWidget);
    });
  }

  testWidgets('example playback sends the full Mandarin sentence once', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    final playback = Completer<int>();
    var languages = ['zh-CN'];
    const channel = MethodChannel('flutter_tts');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getLanguages') return languages;
      if (call.method == 'speak') return playback.future;
      return 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await launch(tester);
    await tapLocal(tester, find.text('Mở từ điển'));
    await tapLocal(tester, find.widgetWithText(ListTile, '你好'));
    final listen = find.byTooltip('Nghe câu ví dụ');
    await tester.ensureVisible(listen);
    await tester.tap(listen);
    await tester.pump();
    expect(find.byTooltip('Đang phát âm'), findsOneWidget);
    await tester.tap(find.byTooltip('Đang phát âm'));
    await tester.pump();
    expect(
      calls
          .where((call) => call.method == 'speak')
          .map((call) => call.arguments),
      ['你好，我叫小明。'],
    );
    playback.complete(1);
    await tester.pumpAndSettle();
    languages = [];
    await tapLocal(tester, listen);
    expect(calls.where((call) => call.method == 'speak'), hasLength(1));
    expect(
      find.text(
        'Hãy thêm giọng tiếng Quan thoại trên thiết bị hoặc trình duyệt.',
      ),
      findsOneWidget,
    );
    expect(find.text('Xin chào, tôi tên là Tiểu Minh.'), findsOneWidget);
  });

  testWidgets('example playback respects disabled lesson sound', (
    tester,
  ) async {
    final data = await repository.load();
    await repository.savePreferences(
      const LocalPreferences(sound: false),
      revision: data.revision,
      operationId: 'mute-test',
    );
    await launch(tester);
    await tapLocal(tester, find.text('Xem mục từ'));
    await tapLocal(tester, find.byTooltip('Nghe câu ví dụ'));
    expect(
      find.text('Bật Âm thanh bài học trong Cá nhân → Mục tiêu và âm thanh.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'bundled sample words retain their HSK levels in the dictionary',
    (tester) async {
      await launch(tester);
      await tapLocal(tester, find.text('Mở từ điển'));
      await tapLocal(tester, find.widgetWithText(ChoiceChip, 'HSK 2'));
      expect(find.widgetWithText(ListTile, '旅游'), findsOneWidget);
      expect(find.widgetWithText(ListTile, '你好'), findsNothing);
      await tester.enterText(find.byType(TextField), 'du lich');
      await tester.pumpAndSettle();
      await tapLocal(tester, find.widgetWithText(ListTile, '旅游'));
      expect(find.byTooltip('Nghe câu ví dụ'), findsOneWidget);
    },
  );

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

  testWidgets('Home opens Cá nhân and its direct account entry', (
    tester,
  ) async {
    await launch(tester, scale: 1.5);
    await tapLocal(tester, find.byTooltip('Mở trang cá nhân'));
    final account = find.text('Đăng nhập / Đăng ký');
    expect(account.hitTestable(), findsOneWidget);
    await tapLocal(tester, account);
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(account.hitTestable(), findsOneWidget);
  });

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
