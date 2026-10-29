import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

class _Canvas extends Fake implements Canvas {
  final draws = <(ui.Image, Rect)>[];
  @override
  Rect getLocalClipBounds() => const Rect.fromLTWH(0, 0, 800, 600);
  @override
  void drawImageRect(
    ui.Image image,
    Rect source,
    Rect destination,
    Paint paint,
  ) {
    draws.add((image, destination));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets(
    'custom shotgun keeps seven-pellet choreography and respects projectile and held scales',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 16, 16),
          Paint()..color = Colors.purple,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(16, 16);
        await SpriteRegistry.registerDrawn('qa.pellet', image, output: 16);
        await SpriteRegistry.registerDrawn('qa.held', image, output: 16);
        image.dispose();
        picture.dispose();
      });
      final pellet = SpriteRegistry.frame('qa.pellet')!;
      final held = SpriteRegistry.frame('qa.held')!;
      Future<_Canvas> render(double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            home: HarpoonCinematic(
              key: ValueKey(scale),
              move: 'Shotgun',
              onFinished: () {},
              winner: const CustomBall(
                id: 'a',
                name: 'A',
                primaryColor: Colors.red,
                glowColor: Colors.red,
              ),
              loser: const CustomBall(
                id: 'b',
                name: 'B',
                primaryColor: Colors.blue,
                glowColor: Colors.blue,
              ),
              skill: SkillDefinition(
                id: 'builtin.shotgun',
                name: 'Shotgun',
                baseKind: PowerUpKind.shotgun,
                projectileSpriteId: 'qa.pellet',
                iconSpriteId: 'qa.held',
                projectileSize: scale,
                weaponDisplayScale: scale,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1800));
        final canvas = _Canvas();
        tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('harpoon-cinematic-effects')),
            )
            .painter!
            .paint(canvas, const Size(800, 600));
        expect(tester.takeException(), isNull);
        return canvas;
      }

      final normal = await render(1);
      final large = await render(2);
      final shots = normal.draws
          .where((draw) => identical(draw.$1, pellet))
          .toList();
      final largerShots = large.draws
          .where((draw) => identical(draw.$1, pellet))
          .toList();
      expect(shots, hasLength(7));
      expect(largerShots, hasLength(7));
      expect(
        largerShots.first.$2.width,
        closeTo(shots.first.$2.width * 2, .001),
      );
      final normalHeld = normal.draws.singleWhere(
        (draw) => identical(draw.$1, held),
      );
      final largeHeld = large.draws.singleWhere(
        (draw) => identical(draw.$1, held),
      );
      expect(largeHeld.$2.width, closeTo(normalHeld.$2.width * 2, .001));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
