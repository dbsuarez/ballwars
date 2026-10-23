import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
];

void main() {
  test('paints field power-ups, projectiles, bombs, blasts and ball effects without throwing', () {
    final c = MatchSimulationController(_balls, arenaRadius: 260, seed: 1, mode: MatchMode.arsenal, lookAhead: false);
    final p = c.powerUps!;
    final a = c.state.balls[0];
    final b = c.state.balls[1];
    for (final kind in PowerUpKind.values) {
      p.field.add(FieldPowerUp(kind: kind, position: Offset(kind.index * 15.0 - 80, 60), spawnStep: 0));
    }
    p.projectiles.add(Projectile(owner: a, kind: PowerUpKind.pistol, position: Offset.zero, velocity: const Offset(100, 0)));
    p.bombs.add(ArmedBomb(owner: a, position: const Offset(0, -50), armedStep: 0));
    p.slashMarks.add(SlashMark(position: const Offset(20, 20), angle: 1));
    p.explosions.add(Explosion(position: const Offset(30, 30), radius: 70));
    a
      ..held = PowerUpKind.shield
      ..aimTarget = b
      ..aimLeft = 10
      ..frozenLeft = 5;
    b
      ..held = PowerUpKind.pistol
      ..ghostLeft = 5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    PowerUpPainter.paint(canvas, c.state, 260);
    ArenaPainter(state: c.state, arenaRadius: 260, rimAngle: 0).paint(canvas, const Size(600, 600));
    expect(recorder.endRecording(), isNotNull);
  });

  test('every power-up has its own glyph color', () {
    final colors = {for (final kind in PowerUpKind.values) PowerUpPainter.colorOf(kind)};
    expect(colors.length, PowerUpKind.values.length);
  });
}
