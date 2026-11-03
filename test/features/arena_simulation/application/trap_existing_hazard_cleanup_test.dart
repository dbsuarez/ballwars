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
      for (final switchId in ['skillTrapsEnabled', 'allTrapsDisabled']) {
        test('placed skill hazards clear when $switchId is active: ${mode.name}/${shape.name}', () {
          final tuning = PowerUpConfig.defaults.withValue(
            switchId, switchId == 'allTrapsDisabled' ? 1 : 0,
          );
          final match = MatchSimulationController(
            balls,
            mode: mode,
            arenaShape: shape,
            arenaRadius: 260,
            seed: 71,
            lookAhead: false,
            tuning: tuning,
          );
          final system = match.powerUps!;
          system.portals.add(ArenaPortal(position: Offset.zero, spawnStep: 0));
          system.spikeWalls.add(SpikeWall(position: Offset.zero, angle: 0, spawnStep: 0));
          system.stickyGoo.add(StickyGoo(position: Offset.zero, spawnStep: 0));
          system.poisonSwamps.add(PoisonSwamp(position: Offset.zero, spawnStep: 0));
          match.tick(1 / 60);
          expect(system.portals, isEmpty);
          expect(system.spikeWalls, isEmpty);
          expect(system.stickyGoo, isEmpty);
          expect(system.poisonSwamps, isEmpty);
        });
      }

      test('arena switch alone preserves placed skill hazards: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(
          balls,
          mode: mode,
          arenaShape: shape,
          arenaRadius: 260,
          seed: 72,
          lookAhead: false,
          tuning: PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0),
        );
        final system = match.powerUps!;
        // Position well away from both balls to avoid normal collision.
        final portal = ArenaPortal(position: const Offset(245, 245), spawnStep: 0);
        system.portals.add(portal);
        match.tick(1 / 60);
        expect(system.portals, contains(portal));
      });
    }
  }
}
