import 'dart:ui' as ui;
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/features/sprites/presentation/sprites_screen.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'sprite_backup_test.dart' show BackupRepo, atlas, a, b;

void main() {
  testWidgets(
    'library searches upload/sprite names; assignment filter and clear compose',
    (tester) async {
      final repo = BackupRepo()
        ..items = [
          atlas(a, name: 'Kage Bunshin'),
          atlas(b, name: 'Fire burst'),
        ];
      final skill = SkillLibrary.defaults
          .builtIn(PowerUpKind.shadowClone, PowerUpConfig.defaults)
          .copyWith(iconSpriteId: 'custom.$a.sprite');
      await tester.pumpWidget(
        MaterialApp(
          home: SpritesScreen(
            repository: repo,
            library: SkillLibrary.defaults.withDefinition(
              skill,
              PowerUpConfig.defaults,
            ),
            tuning: PowerUpConfig.defaults,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Unassigned'));
      await tester.pumpAndSettle();
      expect(find.text('Kage Bunshin'), findsNothing);
      expect(find.text('Fire burst'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('search-sprite-library')),
        'Kage',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No sprites match your search and filter.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Assigned'));
      await tester.pumpAndSettle();
      expect(find.text('Kage Bunshin'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('clear-sprite-library-search')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('search-sprite-library')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Kage Bunshin'), findsOneWidget);
      expect(find.text('Fire burst'), findsNothing);
    },
  );
  testWidgets(
    'picker shows upload names, searches artwork and returns stable ID',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawPaint(ui.Paint()..color = Colors.green);
        final pic = recorder.endRecording();
        final image = await pic.toImage(16, 16);
        await SpriteRegistry.register(
          SpriteImport.grid(
            sheet: 'a.png',
            width: 16,
            height: 16,
            spriteName: 'clone-pop',
          ),
          image,
          idPrefix: 'custom.$a',
          label: 'Kage Bunshin',
        );
        image.dispose();
        pic.dispose();
      });
      addTearDown(() => SpriteRegistry.unregister('custom.$a'));
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    picked = await selectSkillSprite(context, title: 'Artwork'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Kage Bunshin'), findsOneWidget);
      expect(find.text(a), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('search-skill-sprites')),
        'other',
      );
      await tester.pumpAndSettle();
      expect(find.text('Kage Bunshin'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('clear-skill-sprite-search')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('select-sprite-custom.$a.clone-pop')),
      );
      await tester.pumpAndSettle();
      expect(picked, 'custom.$a.clone-pop');
    },
  );
}
