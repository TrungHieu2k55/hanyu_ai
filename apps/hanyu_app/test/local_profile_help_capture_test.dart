// Optional readable reference images; not browser/device acceptance.
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

void main() {
  testWidgets('capture E profile and help at mobile and desktop widths', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final file = File('.dart_tool/package_config.json');
      final config =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final flutter = (config['packages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == 'flutter');
      final sdk = Directory.fromUri(
        file.absolute.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent.path;
      for (final entry in {
        'Roboto': '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        'MaterialIcons':
            '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        if (File('C:/Windows/Fonts/msyh.ttc').existsSync())
          'Microsoft YaHei': 'C:/Windows/Fonts/msyh.ttc',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(
            File(entry.value)
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          );
        await loader.load();
      }
    });
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [360.0, 390.0, 1366.0]) {
      tester.view.physicalSize = Size(width, width > 900 ? 768 : 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = width == 360
          ? 1.5
          : 1;
      final repo = DriftLocalRepository(LocalDatabase(NativeDatabase.memory()));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            overrides: [localRepositoryProvider.overrideWithValue(repo)],
            child: const LocalHanyuApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String text) async {
        final target = find.text(text).last;
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            '../../specs/005-local-admin-content/evidence/$name-${width.toInt()}.png',
          );
          await output.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tap('Cá nhân');
      await tap('Mục tiêu và âm thanh');
      expect(
        tester.getTopLeft(find.text('Hồ sơ và nhịp học')).dy,
        greaterThanOrEqualTo(56),
      );
      await capture('profile');
      await tap('Cá nhân');
      await tap('Hướng dẫn sử dụng');
      expect(
        tester.getTopLeft(find.text('Hướng dẫn sử dụng')).dy,
        greaterThanOrEqualTo(56),
      );
      await capture('help');
      await tap('Đã đọc hướng dẫn');
      expect(find.text('Đã ghi nhận trên thiết bị.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await repo.close();
    }
  }, skip: !const bool.fromEnvironment('CAPTURE_UI'));
}
