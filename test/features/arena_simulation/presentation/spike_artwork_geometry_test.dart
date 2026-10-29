import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

class _Canvas extends Fake implements Canvas {
  double angle = 0;
  final stack = <double>[];
  final spikeAngles = <double>[];
  @override
  void save() => stack.add(angle);
  @override
  void restore() => angle = stack.removeLast();
  @override
  void rotate(double radians) => angle += radians;
  @override
  void drawImageRect(ui.Image image, Rect source, Rect target, Paint paint) =>
      spikeAngles.add(angle);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'changing spike artwork size retains the actual collision sample angles',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 16, 16),
          Paint()..color = Colors.purple,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(16, 16);
        await SpriteRegistry.registerDrawn('qa.spike', image, output: 16);
        image.dispose();
        picture.dispose();
      });
      for (final scale in [1.0, 3.0]) {
        final skill = SkillLibrary.defaults
            .builtIn(PowerUpKind.spikeWall, PowerUpConfig.defaults)
            .copyWith(impactSpriteId: 'qa.spike', effectDisplayScale: scale);
        final match = MatchSimulationController(
          const [
            CustomBall(
              id: 'a',
              name: 'A',
              primaryColor: Colors.red,
              glowColor: Colors.red,
            ),
            CustomBall(
              id: 'b',
              name: 'B',
              primaryColor: Colors.blue,
              glowColor: Colors.blue,
            ),
          ],
          arenaRadius: 260,
          mode: MatchMode.arsenal,
          skillLibrary: SkillLibrary.defaults.withDefinition(
            skill,
            PowerUpConfig.defaults,
          ),
        );
        final powerUps = match.powerUps!;
        final wall = SpikeWall(
          position: const Offset(240, 0),
          angle: 0,
          spawnStep: 0,
        );
        powerUps.spikeWalls.add(wall);
        final canvas = _Canvas();
        PowerUpPainter.paint(canvas, match.state, 260);
        final expected = wall
            .spikePositions(powerUps.fieldRadius * .96)
            .map((point) => math.atan2(point.dy, point.dx) + math.pi / 2)
            .toList();
        expect(canvas.spikeAngles, hasLength(6));
        for (var i = 0; i < expected.length; i++) {
          expect(
            canvas.spikeAngles[i],
            closeTo(expected[i], 1e-9),
            reason: 'scale $scale, spike $i',
          );
        }
      }
    },
  );
}
