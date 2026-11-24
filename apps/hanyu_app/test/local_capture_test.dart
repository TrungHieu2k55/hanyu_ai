import 'support/practice_fixtures.dart' show picture, sound;

import 'package:doanchuyennganh2/features/practice/domain/local_practice.dart';
import 'package:doanchuyennganh2/features/roleplay/data/sample_scenarios.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';
import 'package:doanchuyennganh2/features/review/domain/sm2.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

void main() {
  testWidgets('capture persisted local screens', (tester) async {
    await tester.runAsync(() async {
      final configFile = File('.dart_tool/package_config.json');
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final flutter = (config['packages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == 'flutter');
      final sdk = Directory.fromUri(
        configFile.absolute.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent.path;
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
    final captureNow = DateTime.utc(2026, 11, 19, 8);
    final repository = DriftLocalRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => captureNow,
    );
    addTearDown(repository.close);
    var data = await repository.load();
    const entry = VocabularyItem(
      id: 'personal:capture',
      level: null,
      personal: true,
      hanzi: '雨伞',
      pinyin: 'yǔsǎn',
      vietnamese: 'ô đi mưa',
      exampleHanzi: '',
      exampleVietnamese: '',
    );
    data = await repository.putWord(
      entry,
      revision: data.revision,
      operationId: 'create',
    );
    data = await repository.saveWord(
      entry.id,
      true,
      revision: data.revision,
      operationId: 'save',
    );
    await repository.saveNote(
      entry.id,
      'Đem theo khi trời mưa.',
      revision: data.revision,
      operationId: 'note',
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            localRepositoryProvider.overrideWithValue(repository),
            localClockProvider.overrideWithValue(() => captureNow),
          ],
          child: const LocalHanyuApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LocalHanyuApp)),
    );
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
      expect(tester.takeException(), isNull);
    }

    container.read(localRouterProvider).go('/words/personal:capture');
    await tester.pumpAndSettle();
    await capture('local-word-390');
    tester.view.physicalSize = const Size(360, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pumpAndSettle();
    await capture('local-word-360-text150');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(1366, 768);
    container.read(localRouterProvider).go('/learn');
    await tester.pumpAndSettle();
    await capture('local-catalog-1366');
    tester.view.physicalSize = const Size(390, 844);
    await container
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.startReview(
            revision: container
                .read(localControllerProvider)
                .requireValue
                .revision,
            operationId: 'capture-start',
          ),
        );
    final session = container
        .read(localControllerProvider)
        .requireValue
        .review
        .active!;
    container.read(localRouterProvider).go('/review/session/${session.id}');
    await tester.pumpAndSettle();
    await capture('local-review-front-390');
    await container
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.revealReview(
            session.id,
            0,
            revision: container
                .read(localControllerProvider)
                .requireValue
                .revision,
            operationId: 'capture-reveal',
          ),
        );
    tester.view.physicalSize = const Size(360, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pumpAndSettle();
    await capture('local-review-rating-360-text150');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(390, 844);
    // Settle viewport metrics before changing the routed widget tree.
    await tester.pumpAndSettle();
    await container
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.startExam(
            'local-level-1',
            LocalExamMode.readingPractice,
            revision: container
                .read(localControllerProvider)
                .requireValue
                .revision,
            operationId: 'capture-exam',
          ),
        );
    final exam = container
        .read(localControllerProvider)
        .requireValue
        .exams
        .attempts
        .first;
    container.read(localRouterProvider).go('/exams/attempts/${exam.id}');
    await tester.pumpAndSettle();
    await capture('local-exam-390');
    await container
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.saveExamAnswer(
            exam.id,
            0,
            exam.questions.first.correct,
            revision: container
                .read(localControllerProvider)
                .requireValue
                .revision,
            operationId: 'capture-answer',
          ),
        );
    await tester.pumpAndSettle();
    await capture('local-exam-saved-390');
    await container
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.submitExam(
            exam.id,
            revision: container
                .read(localControllerProvider)
                .requireValue
                .revision,
            operationId: 'capture-submit',
          ),
        );
    tester.view.physicalSize = const Size(1366, 768);
    await tester.pumpAndSettle();
    await capture('local-exam-result-1366');
    await container
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.rateReview(
            session.id,
            0,
            MemoryRating.remembered,
            revision: container
                .read(localControllerProvider)
                .requireValue
                .revision,
            operationId: 'capture-rate',
          ),
        );
    container.read(localRouterProvider).go('/progress');
    await tester.pumpAndSettle();
    await capture('local-progress-1366');
    Future<void> savePractice(
      LocalPracticeEntry entry, {
      List<LocalMediaInput> media = const [],
    }) => container
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.savePractice(
            entry,
            media: media,
            revision: container
                .read(localControllerProvider)
                .requireValue
                .revision,
            operationId: 'capture-${entry.id}',
          ),
        );
    await savePractice(
      LocalPracticeEntry(
        id: 'capture-writing',
        kind: PracticeKind.writing,
        createdAt: captureNow,
        updatedAt: captureNow,
        data: {
          'character': '人',
          'manualChoice': null,
          'elapsedMs': 2400,
          'strokes': [
            [
              [0.55, 0.2],
              [0.5, 0.4],
              [0.4, 0.6],
              [0.28, 0.78],
            ],
            [
              [0.5, 0.43],
              [0.62, 0.62],
              [0.78, 0.78],
            ],
          ],
        },
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    container.read(localRouterProvider).go('/writing/capture-writing');
    await tester.pumpAndSettle();
    await capture('local-writing-390');
    final image = picture();
    await savePractice(
      LocalPracticeEntry(
        id: 'capture-photo',
        kind: PracticeKind.photo,
        createdAt: captureNow,
        updatedAt: captureNow,
        data: {'original': '你好，朋友。', 'text': '你好，朋友。', 'imageId': image.id},
      ),
      media: [image],
    );
    container.read(localRouterProvider).go('/photos/capture-photo');
    await tester.pumpAndSettle();
    await capture('local-photo-390');
    final scenario = sampleScenarios.first, audio = sound();
    await savePractice(
      LocalPracticeEntry(
        id: 'capture-conversation',
        kind: PracticeKind.conversation,
        createdAt: captureNow,
        updatedAt: captureNow,
        data: {
          'scenarioId': scenario.id,
          'scenarioVersion': 'sample-v1-unreviewed',
          'title': scenario.title,
          'role': scenario.role,
          'partner': scenario.partner,
          'goal': scenario.goal,
          'opening': scenario.opening,
          'reply': scenario.reply,
          'turns': [],
          'draft': '你好！欢迎来到岘港。',
          'draftAudioId': audio.id,
        },
      ),
      media: [audio],
    );
    container
        .read(localRouterProvider)
        .go('/conversations/capture-conversation');
    await tester.pumpAndSettle();
    await capture('local-conversation-390');
    tester.view.physicalSize = const Size(1366, 768);
    await tester.pumpAndSettle();
    container.read(localRouterProvider).go('/photos');
    await tester.pumpAndSettle();
    await capture('local-media-history-1366');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: !const bool.fromEnvironment('CAPTURE_UI'));
}
