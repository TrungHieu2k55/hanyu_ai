import 'package:doanchuyennganh2/shared/widgets/learner_web_navigation.dart';
import 'package:doanchuyennganh2/app/local/local_app.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/drift_local_repository.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/shared/widgets/brand_mark.dart';
import 'package:doanchuyennganh2/shared/widgets/figma_icon.dart';
import 'package:doanchuyennganh2/shared/widgets/learner_navigation_bar.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reference_images.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_UI');
  for (final (width, height, scale) in [
    (320.0, 720.0, 1.5),
    (320.0, 720.0, 2.0),
    (360.0, 844.0, 1.5),
    (390.0, 844.0, 1.0),
    (768.0, 900.0, 1.3),
    (1366.0, 768.0, 1.0),
  ]) {
    testWidgets('learner navigation at ${width.toInt()} px and text ×$scale', (
      tester,
    ) async {
      final repository = DriftLocalRepository(
        LocalDatabase(NativeDatabase.memory()),
      );
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      final bottomInset = width == 390 ? 34.0 : 0.0;
      tester.view.padding = FakeViewPadding(bottom: bottomInset);
      addTearDown(tester.view.resetPadding);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await repository.close();
      });
      if (capture) await loadReferenceFonts(tester);
      final preview = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: ProviderScope(
            overrides: [localRepositoryProvider.overrideWithValue(repository)],
            child: const LocalHanyuApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Học đều, nhớ lâu.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final rail = find.byType(LearnerWebNavigation);
      final bar = find.byType(LearnerNavigationBar);
      expect(rail, width >= 760 ? findsOneWidget : findsNothing);
      expect(bar, width >= 760 ? findsNothing : findsOneWidget);
      final shortcutBounds = [
        for (final label in ['Viết chữ', 'Chụp chữ', 'Hội thoại', 'Thi thử'])
          tester.getRect(find.widgetWithText(OutlinedButton, label)),
      ];
      if (scale > 1.5) {
        for (var i = 1; i < shortcutBounds.length; i++) {
          expect(
            shortcutBounds[i].top - shortcutBounds[i - 1].bottom,
            greaterThanOrEqualTo(8),
          );
        }
      } else {
        for (var i = 0; i < shortcutBounds.length; i += 2) {
          expect(shortcutBounds[i].top, closeTo(shortcutBounds[i + 1].top, .1));
          expect(
            shortcutBounds[i].bottom,
            closeTo(shortcutBounds[i + 1].bottom, .1),
          );
        }
      }
      if (width < 760) {
        final header = find.byType(AppBar);
        expect(
          find.descendant(of: header, matching: find.byType(BrandMark)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text('Học hôm nay')),
          findsOneWidget,
        );
        expect(
          tester.getBottomLeft(find.byType(TextField)).dy,
          lessThan(shortcutBounds.first.top),
        );
        if (capture && width == 320) {
          expect(tester.getSize(bar).height, lessThanOrEqualTo(100));
        }
        final icons = find.descendant(
          of: bar,
          matching: find.byType(FigmaIcon),
        );
        expect(icons, findsNWidgets(5));
        final tabLabels = find.descendant(of: bar, matching: find.byType(Text));
        expect(tabLabels, findsNWidgets(5));
        final labelTop = tester.getTopLeft(tabLabels.first).dy;
        for (var index = 0; index < 5; index++) {
          final label = tabLabels.at(index);
          final text = tester.widget<Text>(label);
          final scaler = MediaQuery.textScalerOf(tester.element(label));
          expect(text.textScaler, isNull);
          expect(scaler.scale(12), closeTo(12 * scale, .1));
          expect(tester.getTopLeft(label).dy, closeTo(labelTop, .1));
        }
        if (bottomInset > 0) {
          for (final label in tabLabels.evaluate()) {
            expect(
              tester
                  .getBottomLeft(
                    find.byElementPredicate((element) => element == label),
                  )
                  .dy,
              lessThanOrEqualTo(height - bottomInset),
            );
          }
        }
        final top = tester.getTopLeft(icons.first).dy;
        for (final iconIndex in Iterable<int>.generate(5)) {
          expect(tester.getTopLeft(icons.at(iconIndex)).dy, closeTo(top, .1));
        }
      }
      if (capture) {
        await captureReference(
          tester,
          preview,
          'build/learner_alignment_home_${width.toInt()}_$scale.png',
        );
      }

      for (final tab in ['Tiến độ', 'Cá nhân']) {
        await tester.tap(
          find.descendant(
            of: width >= 760 ? rail : bar,
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (capture) {
          final page = tab == 'Tiến độ' ? 'progress' : 'profile';
          await captureReference(
            tester,
            preview,
            'build/learner_alignment_${page}_${width.toInt()}_$scale.png',
          );
        }
      }
    });
  }
}
