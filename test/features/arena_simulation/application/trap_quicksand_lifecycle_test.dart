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
      for (final disabled in [false, true]) {
        test('quicksand does not eject a departed victim: ${mode.name}/${shape.name}/disabled=$disabled', () {
          final tuning = PowerUpConfig.defaults.withValue('arenaTrapsEnabled', disabled ? 0 : 1);
          final match = MatchSimulationController(contestants, mode: mode,
            arenaShape: shape, arenaRadius: 260, seed: 902, lookAhead: false,
            tuning: tuning);
          final system = match.powerUps!..automaticSpawning = false;
          final ball = match.state.balls.first;
          ball.position = const Offset(110, 0);
          ball.velocity = const Offset(2, 0);
          final hazard = ArenaThemeHazard(kind: ArenaThemeHazardKind.quicksand,
            position: Offset.zero, spawnStep: 0)
            ..age = PowerUpConfig.defaults.arenaTrapDurationSteps - 1
            ..affected.add(ball);
          system.arenaThemeHazards.add(hazard);
          match.tick(1 / 60);
          expect(system.arenaThemeHazards, isNot(contains(hazard)));
          expect(ball.velocity.distance, lessThan(match.arenaRadius * 0.42));
        });
      }
    }
  }
}
