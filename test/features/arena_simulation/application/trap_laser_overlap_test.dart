import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  const contestants = [
    CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
    CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
  ];
  for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
    for (final shape in [ArenaShape.circle, ArenaShape.square]) {
      test('overlapping laser gates damage once: ${mode.name}/${shape.name}', () {
        MatchSimulationController setup(int count) {
          final match = MatchSimulationController(contestants,
            mode: mode, arenaShape: shape, arenaRadius: 260,
            seed: 1308, lookAhead: false, tuning: PowerUpConfig.defaults);
          final system = match.powerUps!..automaticSpawning = false;
          final ball = match.state.balls.first;
          ball.position = const Offset(10, 0);
          ball.velocity = Offset.zero;
          for (var i = 0; i < count; i++) {
            system.arenaThemeHazards.add(ArenaThemeHazard(
              kind: ArenaThemeHazardKind.laserGate,
              position: Offset.zero, spawnStep: 0, angle: 0));
          }
          return match;
        }
        final single = setup(1);
        final overlap = setup(2);
        single.tick(1 / 60);
        overlap.tick(1 / 60);
        final a = single.state.balls.first;
        final b = overlap.state.balls.first;
        if (mode == MatchMode.arsenal) {
          expect(b.life, closeTo(a.life, 0.0001));
        } else {
          expect(b.fanLines.length, a.fanLines.length);
        }
        expect(overlap.powerUps!.arenaThemeHazards.every(
          (hazard) => hazard.affected.contains(b)), isTrue);
      });
      test('laser gates clear membership independently: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants,
          mode: mode, arenaShape: shape, arenaRadius: 260,
          seed: 1309, lookAhead: false, tuning: PowerUpConfig.defaults);
        final system = match.powerUps!..automaticSpawning = false;
        final ball = match.state.balls.first;
        ball.position = const Offset(10, 0);
        ball.velocity = Offset.zero;
        final gates = [for (var i = 0; i < 2; i++)
          ArenaThemeHazard(kind: ArenaThemeHazardKind.laserGate,
            position: Offset.zero, spawnStep: 0, angle: 0)];
        system.arenaThemeHazards.addAll(gates);
        match.tick(1 / 60);
        expect(gates.every((gate) => gate.affected.contains(ball)), isTrue);
        ball.position = const Offset(10, 80);
        match.tick(1 / 60);
        expect(gates.every((gate) => !gate.affected.contains(ball)), isTrue);
      });
    }
  }
}
