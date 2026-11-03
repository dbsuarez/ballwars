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
      test('expired quicksand does not release a victim still in another patch: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants, mode: mode,
          arenaShape: shape, arenaRadius: 260, seed: 804, lookAhead: false,
          tuning: PowerUpConfig.defaults);
        final system = match.powerUps!..automaticSpawning = false;
        final ball = match.state.balls.first;
        ball.position = const Offset(10, 0);
        ball.velocity = const Offset(1, 0);
        final expired = ArenaThemeHazard(kind: ArenaThemeHazardKind.quicksand,
          position: Offset.zero, spawnStep: 0)
          ..age = PowerUpConfig.defaults.arenaTrapDurationSteps - 1
          ..affected.add(ball);
        final active = ArenaThemeHazard(kind: ArenaThemeHazardKind.quicksand,
          position: Offset.zero, spawnStep: 0)..affected.add(ball);
        system.arenaThemeHazards.addAll([expired, active]);
        match.tick(1 / 60);
        expect(system.arenaThemeHazards, isNot(contains(expired)));
        expect(system.arenaThemeHazards, contains(active));
        expect(ball.velocity.distance, lessThan(match.arenaRadius * 0.42),
          reason: 'An overlapping active quicksand must not eject the victim');
      });

      test('disabling arena traps releases overlapping quicksand once: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants, mode: mode,
          arenaShape: shape, arenaRadius: 260, seed: 805, lookAhead: false,
          tuning: PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0));
        final system = match.powerUps!..automaticSpawning = false;
        final ball = match.state.balls.first;
        ball.position = const Offset(10, 0);
        ball.velocity = Offset.zero;
        for (var i = 0; i < 2; i++) {
          system.arenaThemeHazards.add(ArenaThemeHazard(
            kind: ArenaThemeHazardKind.quicksand,
            position: Offset.zero, spawnStep: i)..affected.add(ball));
        }
        match.tick(1 / 60);
        expect(system.arenaThemeHazards, isEmpty);
        expect(ball.velocity.dx, greaterThan(0));
      });
    }
  }
}
