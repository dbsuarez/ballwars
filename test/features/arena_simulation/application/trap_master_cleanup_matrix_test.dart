import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  const balls = [
    CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
    CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
  ];

  for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
    for (final shape in [ArenaShape.circle, ArenaShape.square]) {
      test('master override clears both existing hazard sources: ${mode.name}/${shape.name}', () {
        final tuning = PowerUpConfig.defaults
            .withValue('arenaTrapsEnabled', 1)
            .withValue('skillTrapsEnabled', 1)
            .withValue('allTrapsDisabled', 1);
        final match = MatchSimulationController(
          balls,
          mode: mode,
          arenaShape: shape,
          arenaRadius: 260,
          seed: 301,
          lookAhead: false,
          tuning: tuning,
        );
        final system = match.powerUps!;
        final ball = match.state.balls.first;
        ball.position = const Offset(10, 0);
        ball.velocity = Offset.zero;
        system.arenaThemeHazards.add(ArenaThemeHazard(
          kind: ArenaThemeHazardKind.quicksand,
          position: Offset.zero,
          spawnStep: 0,
        )..affected.add(ball));
        system.portals.add(ArenaPortal(position: const Offset(240, 240), spawnStep: 0));
        system.stickyGoo.add(StickyGoo(position: const Offset(240, 240), spawnStep: 0));
        system.poisonSwamps.add(PoisonSwamp(position: const Offset(240, 240), spawnStep: 0));
        system.spikeWalls.add(SpikeWall(position: const Offset(240, 240), angle: 0, spawnStep: 0));

        match.tick(1 / 60);
        expect(system.arenaThemeHazards, isEmpty);
        expect(system.portals, isEmpty);
        expect(system.stickyGoo, isEmpty);
        expect(system.poisonSwamps, isEmpty);
        expect(system.spikeWalls, isEmpty);
        expect(ball.velocity.distance, greaterThan(0));
      });
    }
  }
}
