import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_selection_dialog.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

void main() {
  for (final width in [390.0, 1000.0]) {
    testWidgets(
      'arena dialog fits $width width, marks current and selects a map',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        if (const bool.fromEnvironment('ARENA_DIALOG_PREVIEW')) {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          await (FontLoader('Manrope')
                ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf')))
              .load();
        }
        ArenaDecoration? picked;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('dialog-capture'),
            child: MaterialApp(
              theme: AppTheme.build(AppPalettes.midnight),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      picked = await showArenaSelectionDialog(
                        context,
                        selected: ArenaDecoration.space,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        final rect = tester.getRect(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(rect.left, greaterThan(0));
        expect(rect.right, lessThan(width));
        expect(rect.top, greaterThan(0));
        expect(rect.width, lessThanOrEqualTo(440));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('arena-option-space')),
            matching: find.byIcon(Icons.check_circle),
          ),
          findsOneWidget,
        );
        if (width == 390 &&
            const bool.fromEnvironment('ARENA_DIALOG_PREVIEW')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('dialog-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            await File('build/arena-selector-phone.png').writeAsBytes(
              (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List(),
            );
            image.dispose();
          });
        }
        final choice = find.byKey(const ValueKey('arena-option-chaotic'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(picked, ArenaDecoration.chaotic);
        expect(find.byType(ArenaSelectionDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Cancel leaves the arena unchanged', (tester) async {
    var value = ArenaDecoration.desert;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                value =
                    await showArenaSelectionDialog(context, selected: value) ??
                    value;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(value, ArenaDecoration.desert);
    expect(find.byType(ArenaSelectionDialog), findsNothing);
  });
}
