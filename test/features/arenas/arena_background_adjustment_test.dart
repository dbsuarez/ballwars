import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arenas/domain/arena_background_style.dart';
import 'package:ballwars/features/arenas/domain/arena_definition.dart';
import 'package:ballwars/features/arenas/presentation/arena_image_crop.dart';
import 'package:ballwars/features/arenas/presentation/arena_library_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_preview.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';

Future<ui.Image> image() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(200, 200);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'adjustments validate, version-gate and persist in replay snapshots',
    () {
      const style = ArenaBackgroundStyle(zoom: 2, x: .2, y: .7, dim: .6);
      const map = ArenaDefinition(
        id: 'map',
        name: 'Map',
        backgroundSpriteId: 'custom.map.background',
        backgroundStyle: style,
      );
      expect(map.toJson()['version'], 3);
      final restored = ArenaDefinition.decode(map.encode());
      expect(restored.backgroundStyle.toJson(), style.toJson());
      expect(
        () => ArenaDefinition.fromJson({...map.toJson(), 'version': 2}),
        throwsFormatException,
      );
      for (final invalid in [double.nan, double.infinity, -.1, 1.1]) {
        expect(
          () => ArenaBackgroundStyle.fromJson({
            ...style.toJson(),
            'dim': invalid,
          }),
          throwsFormatException,
        );
      }
      final presets = LocalBallRepository.presets;
      final link = ReplayLink(
        contestants: presets.take(2).toList(),
        seed: 3,
        speedMultiplier: 1,
        simulationRevision: 10,
        arenaPreset: map,
      );
      final replay = ReplayLink.fromUri(
        link.toUri(presetIds: {for (final b in presets) b.id}),
        presets: presets,
      )!;
      expect(replay.arenaPreset!.backgroundStyle.toJson(), style.toJson());
    },
  );

  testWidgets('one-finger pan and two-finger zoom update the same crop', (
    tester,
  ) async {
    late ui.Image source;
    await tester.runAsync(() async {
      source = await image();
    });
    addTearDown(source.dispose);
    var style = const ArenaBackgroundStyle(zoom: 2);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => ListView(
              controller: scroll,
              children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: ArenaImageCrop(
                    image: source,
                    style: style,
                    onChanged: (next) => update(() => style = next),
                  ),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );
    final crop = find.byKey(const ValueKey('arena-image-crop'));
    final pan = await tester.startGesture(tester.getCenter(crop));
    await pan.moveBy(const Offset(0, 25));
    await tester.pump();
    await pan.moveBy(const Offset(0, 25));
    await tester.pump();
    await pan.up();
    expect(style.y, lessThan(.5));
    expect(scroll.offset, 0);
    final center = tester.getCenter(crop);
    final left = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    final right = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump();
    await left.moveTo(center - const Offset(70, 0));
    await tester.pump();
    await right.moveTo(center + const Offset(70, 0));
    await tester.pump();
    expect(style.zoom, greaterThan(2));
    expect(style.zoom, lessThanOrEqualTo(4));
    final zoomed=style.zoom;
    await left.up();
    await tester.pump();
    await right.up();
    await tester.pump();
    expect(style.zoom,closeTo(zoomed,.00001));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'existing image edits survive tabs, save failure and reopen without uploading',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late ui.Image source;
      await tester.runAsync(() async {
        source = await image();
      });
      await tester.runAsync(() async {
        await SpriteRegistry.register(
          const SpriteAtlas(
            sheet: 'background.png',
            sprites: {
              'background': SpriteDef(
                id: 'background',
                frames: [Rect.fromLTWH(0, 0, 200, 200)],
                output: 200,
                padding: 0,
                bleedOk: true,
                bleedNote: 'Single image',
              ),
            },
          ),
          source,
          idPrefix: 'custom.adjust-map',
        );
      });
      source.dispose();
      addTearDown(() => SpriteRegistry.unregister('custom.adjust-map'));
      const map = ArenaDefinition(
        id: 'adjust-map',
        name: 'Adjust map',
        backgroundSpriteId: 'custom.adjust-map.background',
      );
      ArenaDefinition? saved;
      var fail = true;
      Widget editor(ArenaDefinition initial) => MaterialApp(
        home: ArenaEditorScreen(
          initial: initial,
          onSave: (value) async {
            if (fail) throw StateError('Offline');
            saved = value;
          },
        ),
      );
      // No backend or uploader is provided: changing a saved image needs neither.
      await tester.pumpWidget(editor(map));
      await tester.tap(find.byKey(const ValueKey('arena-media-tab')));
      await tester.pumpAndSettle();
      Future<void> set(String label, double value) async {
        final control = find.byKey(ValueKey('arena-background-$label'));
        final viewport = tester.getRect(
          find.byKey(const PageStorageKey('arena-media-tab')),
        );
        for (
          var i = 0;
          i < 14 && control.hitTestable().evaluate().isEmpty;
          i++
        ) {
          await tester.dragFrom(
            Offset(viewport.left + 4, viewport.center.dy),
            const Offset(0, -150),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(control);
        tester.widget<Slider>(control).onChanged!(value);
        await tester.pump();
      }

      await set('zoom', 2);
      await set('dim image', .6);
      final preview = tester.widget<ArenaPreview>(find.byType(ArenaPreview));
      expect(preview.arena!.backgroundStyle.dim, .6);
      await tester.tap(find.text('Identity'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('arena-name')),
        'Adjusted',
      );
      await tester.tap(find.byKey(const ValueKey('save-arena')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('save-arena')));
      await tester.pumpAndSettle();
      expect(saved!.backgroundSpriteId, map.backgroundSpriteId);
      expect(saved!.backgroundStyle.zoom, 2);
      expect(saved!.backgroundStyle.dim, .6);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        editor(ArenaDefinition.fromJson(saved!.toJson())),
      );
      await tester.tap(find.byKey(const ValueKey('arena-media-tab')));
      await tester.pumpAndSettle();
      await set('dim image', .6);
      expect(
        tester
            .widget<ArenaPreview>(find.byType(ArenaPreview))
            .arena!
            .backgroundStyle
            .zoom,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
