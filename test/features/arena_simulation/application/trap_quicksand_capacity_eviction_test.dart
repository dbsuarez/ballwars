import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

void main() {
  const contestants = [
    CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
    CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
  ];
  for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
    for (final shape in [ArenaShape.circle, ArenaShape.square]) {
      test('quicksand capacity eviction releases only its own occupant: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants,
          mode: mode, arenaShape: shape, arenaDecoration: ArenaDecoration.desert,
          arenaRadius: 260, seed: 1004, lookAhead: false,
          tuning: PowerUpConfig.defaults);
        final system = match.powerUps!..automaticSpawning = false;
        final ball = match.state.balls.first;
        ball.position = const Offset(-250, 0);
        ball.velocity = Offset.zero;
        final oldest = ArenaThemeHazard(kind: ArenaThemeHazardKind.quicksand,
          position: const Offset(-250, 0), spawnStep: 0)..affected.add(ball);
        system.arenaThemeHazards.addAll([
          oldest,
          ArenaThemeHazard(kind: ArenaThemeHazardKind.quicksand,
            position: const Offset(250, 0), spawnStep: 1),
        ]);
        system.spawnTestArenaHazard();
        expect(system.arenaThemeHazards, hasLength(2));
        expect(system.arenaThemeHazards, isNot(contains(oldest)));
        expect(ball.velocity.distance, greaterThanOrEqualTo(match.arenaRadius * 0.42));
      });

      test('quicksand capacity eviction respects overlapping ownership: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants,
          mode: mode, arenaShape: shape, arenaDecoration: ArenaDecoration.desert,
          arenaRadius: 260, seed: 1005, lookAhead: false,
          tuning: PowerUpConfig.defaults);
        final system = match.powerUps!..automaticSpawning = false;
        final ball = match.state.balls.first;
        ball.position = const Offset(-250, 0);
        ball.velocity = Offset.zero;
        final oldest = ArenaThemeHazard(kind: ArenaThemeHazardKind.quicksand,
          position: const Offset(-250, 0), spawnStep: 0)..affected.add(ball);
        final surviving = ArenaThemeHazard(kind: ArenaThemeHazardKind.quicksand,
          position: const Offset(-250, 0), spawnStep: 1)..affected.add(ball);
        system.arenaThemeHazards.addAll([oldest, surviving]);
        system.spawnTestArenaHazard();
        expect(system.arenaThemeHazards, isNot(contains(oldest)));
        expect(system.arenaThemeHazards, contains(surviving));
        expect(ball.velocity, Offset.zero);
      });
    }
  }
}
