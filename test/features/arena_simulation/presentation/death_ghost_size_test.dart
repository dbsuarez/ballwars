import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

class _GhostCanvas extends Fake implements Canvas {
  _GhostCanvas(this.ghost);
  final ui.Image ghost;
  Rect? destination;
  @override
  void drawImageRect(ui.Image image, Rect source, Rect target, Paint paint) {
    if (identical(image, ghost)) destination = target;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'supplied ghost artwork follows the defeated ball size with larger framing',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(PowerUpSprites.load);
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
        seed: 42,
        mode: MatchMode.arsenal,
        lookAhead: false,
        simulationRevision: 11,
        endlessBattle: true,
        powerUpKinds: const {},
      );
      final ball = match.state.balls.first;
      ball.life = 0;
      match.tick(1 / 60);
      final ghost = match.state.deathGhosts.single;
      expect(ghost.radius, ball.radius);
      final canvas = _GhostCanvas(
        SpriteRegistry.frameAt('anim.death-ghost', 0)!,
      );
      ArenaPainter(
        state: match.state,
        arenaRadius: 260,
        rimAngle: 0,
      ).paint(canvas, const Size(520, 520));
      expect(canvas.destination, isNotNull);
      expect(canvas.destination!.width, closeTo(ball.radius * 3.6, 1e-8));
      expect(canvas.destination!.height, canvas.destination!.width);
    },
  );
}
