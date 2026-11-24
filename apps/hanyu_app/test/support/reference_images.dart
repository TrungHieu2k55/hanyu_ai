import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadReferenceFonts(WidgetTester tester) =>
    tester.runAsync(() async {
      final configFile = File('.dart_tool/package_config.json');
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final flutter = (config['packages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == 'flutter');
      final sdk = Directory.fromUri(
        configFile.absolute.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent.path;
      for (final entry in {
        'Roboto': '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        'MaterialIcons':
            '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        'Noto Sans SC': 'assets/fonts/NotoSansSC.ttf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(
            File(entry.value)
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          );
        await loader.load();
      }
      final inter = FontLoader('Inter');
      for (final weight in [400, 500, 600, 700, 800]) {
        inter.addFont(
          File('assets/fonts/Inter-$weight.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        );
      }
      await inter.load();
    });
Future<void> captureReference(
  WidgetTester tester,
  GlobalKey key,
  String path,
) async {
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
