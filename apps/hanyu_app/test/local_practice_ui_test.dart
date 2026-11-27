import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/media/practice_media.dart';
import 'package:doanchuyennganh2/features/practice/domain/local_practice.dart';
import 'package:doanchuyennganh2/shared/widgets/handwriting_pad.dart';

import 'support/practice_fixtures.dart' show picture, sound;

class FakePicker implements PracticeImagePicker {
  bool canceled = false, cameraDenied = false;
  @override
  Future<LocalMediaInput?> pick({required bool camera}) async {
    if (camera && cameraDenied) {
      throw PlatformException(code: 'camera_access_denied');
    }
    return canceled ? null : picture();
  }
}

class FakeRecorder implements PracticeRecorder {
  bool denied = false, active = false, disposed = false;
  @override
  String? interruption;
  @override
  Future<void> start() async {
    if (denied) {
      throw const MicrophonePermissionDenied();
    }
    active = true;
  }

  @override
  Future<LocalMediaInput?> stop() async {
    active = false;
    return sound();
  }

  @override
  Future<void> cancel() async {
    active = false;
  }

  @override
  Future<void> dispose() async {
    active = false;
    disposed = true;
  }
}

class FakePlayer implements PracticePlayer {
  final changes = StreamController<bool>.broadcast();
  bool disposed = false, failDispose = false;
  Uint8List? loaded;
  @override
  Stream<bool> get playing => changes.stream;
  @override
  Future<void> load(Uint8List bytes) async {
    loaded = bytes;
  }

  @override
  Future<void> play() async {
    changes.add(true);
  }

  @override
  Future<void> pause() async {
    changes.add(false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await changes.close();
    if (failDispose) throw StateError("device disappeared during disposal");
  }
}

Future<void> pressPractice(WidgetTester tester, String label) async {
  final f = find.text(label).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: label);
}

class FakePracticeStopwatch implements Stopwatch {
  int milliseconds = 0;
  bool running = false;
  @override
  Duration get elapsed => Duration(milliseconds: milliseconds);
  @override
  int get elapsedMilliseconds => milliseconds;
  @override
  int get elapsedMicroseconds => milliseconds * 1000;
  @override
  int get elapsedTicks => milliseconds;
  @override
  int get frequency => 1000;
  @override
  bool get isRunning => running;
  @override
  void start() {
    running = true;
  }

  @override
  void stop() {
    running = false;
  }

  @override
  void reset() {
    milliseconds = 0;
  }
}

void main() {
  late DriftLocalRepository repo;
  late FakePicker picker;
  late FakeRecorder recorder;
  late List<FakePlayer> players;
  late FakePracticeStopwatch stopwatch;
  setUp(() {
    repo = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
    picker = FakePicker();
    recorder = FakeRecorder();
    players = [];
    stopwatch = FakePracticeStopwatch();
  });
  tearDown(() => repo.close());
  Future<ProviderContainer> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRepositoryProvider.overrideWithValue(repo),
          practiceImagePickerProvider.overrideWithValue(picker),
          practiceStopwatchFactoryProvider.overrideWithValue(() => stopwatch),
          practiceRecorderFactoryProvider.overrideWithValue(() => recorder),
          practicePlayerFactoryProvider.overrideWithValue(() {
            final player = FakePlayer();
            players.add(player);
            return player;
          }),
        ],
        child: const LocalHanyuApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(LocalHanyuApp)),
    );
  }

  testWidgets(
    'writing saves normalized strokes, guards leaving and survives app recreation',
    (tester) async {
      final c = await launch(tester);
      c.read(localRouterProvider).go('/writing/new');
      await tester.pumpAndSettle();
      final pad = find.byType(HandwritingPad);
      await tester.ensureVisible(pad);
      await tester.pumpAndSettle();
      final point = tester.getTopLeft(pad) + const Offset(50, 50);
      await tester.dragFrom(point, const Offset(80, 80));
      await tester.pumpAndSettle();
      expect((await repo.load()).practice, isEmpty);
      await pressPractice(tester, 'Về lịch sử viết');
      expect(find.text('Rời khi chưa lưu?'), findsOneWidget);
      await pressPractice(tester, 'Ở lại');
      await pressPractice(tester, 'Lưu bản nháp viết');
      var stored = (await repo.load()).practice.single;
      expect(stored.done, isFalse);
      expect((stored.data['strokes'] as List).length, 1);
      expect(
        c.read(localRouterProvider).routeInformationProvider.value.uri.path,
        '/writing/${stored.id}',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final next = await launch(tester);
      next.read(localRouterProvider).go('/writing/${stored.id}');
      await tester.pumpAndSettle();
      expect(find.text('1 nét · 0 giây đặt bút'), findsOneWidget);
      await pressPractice(tester, 'Hoàn thành lượt luyện');
      stored = (await repo.load()).practice.single;
      expect(stored.done, isTrue);
      expect(find.text('Bài viết đã hoàn thành'), findsOneWidget);
      expect(find.text('Lưu bản nháp viết'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'real-image adapter preview cancel, save, text edit and drop-image keep text',
    (tester) async {
      final c = await launch(tester);
      c.read(localRouterProvider).go('/photos/new');
      await tester.pumpAndSettle();
      picker.canceled = true;
      await pressPractice(tester, 'Chọn từ thư viện ảnh');
      expect((await repo.load()).practice, isEmpty);
      picker.canceled = false;
      await pressPractice(tester, 'Chọn từ thư viện ảnh');
      await pressPractice(tester, 'Hủy ảnh xem trước');
      expect((await repo.load()).media, isEmpty);
      await pressPractice(tester, 'Chọn từ thư viện ảnh');
      await pressPractice(tester, 'Dùng ảnh này');
      await tester.enterText(find.byType(TextField), '你好');
      await tester.pumpAndSettle();
      await pressPractice(tester, 'Lưu ảnh và văn bản');
      var e = (await repo.load()).practice.single;
      expect((await repo.load()).media.length, 1);
      expect(
        c.read(localRouterProvider).routeInformationProvider.value.uri.path,
        '/photos/${e.id}',
      );
      await tester.enterText(find.byType(TextField), '谢谢');
      await tester.pumpAndSettle();
      await pressPractice(tester, 'Bỏ ảnh, giữ văn bản');
      await pressPractice(tester, 'Xác nhận');
      await pressPractice(tester, 'Lưu ảnh và văn bản');
      final loaded = await repo.load();
      e = loaded.practice.single;
      expect(e.data['text'], '谢谢');
      expect(e.data['original'], '你好');
      expect(loaded.media, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'audio is saved with draft, playback stops on exit and confirmation adds exactly one turn',
    (tester) async {
      final c = await launch(tester);
      c.read(localRouterProvider).go('/conversations/new?scenario=tourism');
      await tester.pumpAndSettle();
      await pressPractice(tester, 'Ghi âm / ghi lại');
      expect(recorder.active, isTrue);
      await pressPractice(tester, 'Dừng ghi âm');
      expect((await repo.load()).media, isEmpty);
      await pressPractice(tester, 'Nghe bản thu');
      expect(players.single.loaded, sound().bytes);
      await pressPractice(tester, 'Tạm dừng audio');
      await tester.enterText(find.byType(TextField), '你好');
      await tester.pumpAndSettle();
      await pressPractice(tester, 'Lưu phiên và bản nháp');
      var e = (await repo.load()).practice.single;
      expect((e.data['turns'] as List), isEmpty);
      expect((await repo.load()).media.length, 1);
      expect(
        c.read(localRouterProvider).routeInformationProvider.value.uri.path,
        '/conversations/${e.id}',
      );
      await pressPractice(tester, 'Xác nhận thêm lượt');
      e = (await repo.load()).practice.single;
      expect((e.data['turns'] as List).length, 1);
      expect(e.data['draft'], '');
      expect(find.text('Lượt 1 · bạn tự nhập'), findsOneWidget);
      await pressPractice(tester, 'Nghe bản thu');
      expect(players.last.loaded, sound().bytes);
      players.last.failDispose = true;
      await pressPractice(tester, 'Về các tình huống');
      expect(
        c.read(localRouterProvider).routeInformationProvider.value.uri.path,
        '/conversations',
      );
      await tester.pumpAndSettle();
      expect(
        players.every((p) => p.disposed),
        isTrue,
        reason: 'players: ${players.map((p) => p.disposed).toList()}',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('camera denial keeps the text and permits a different source', (
    tester,
  ) async {
    final c = await launch(tester);
    c.read(localRouterProvider).go('/photos/new');
    await tester.pumpAndSettle();
    picker.cameraDenied = true;
    await tester.enterText(find.byType(TextField), '朋友');
    await pressPractice(tester, 'Chụp ảnh bằng camera');
    expect(find.text('Chưa có quyền mở nguồn ảnh'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '朋友',
    );
    await pressPractice(tester, 'Chọn ảnh khác');
    expect(find.text('Dùng ảnh này'), findsOneWidget);
  });

  testWidgets(
    'denied microphone keeps text-only path; background interruption and 60 seconds stop recording',
    (tester) async {
      final c = await launch(tester);
      c.read(localRouterProvider).go('/conversations/new?scenario=directions');
      await tester.pumpAndSettle();
      recorder.denied = true;
      await pressPractice(tester, 'Ghi âm / ghi lại');
      expect(find.textContaining('Microphone bị từ chối'), findsOneWidget);
      expect(find.text('Bạn vẫn có thể nhập chữ'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '请问');
      await tester.pumpAndSettle();
      await pressPractice(tester, 'Lưu phiên và bản nháp');
      expect((await repo.load()).practice.length, 1);
      recorder.denied = false;
      await pressPractice(tester, 'Ghi âm / ghi lại');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(recorder.active, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await pressPractice(tester, 'Ghi âm / ghi lại');
      recorder.interruption = 'Thiết bị bị ngắt';
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(recorder.active, isFalse);
      recorder.interruption = null;
      await pressPractice(tester, 'Ghi âm / ghi lại');
      stopwatch.milliseconds = 60000;
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(recorder.active, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
