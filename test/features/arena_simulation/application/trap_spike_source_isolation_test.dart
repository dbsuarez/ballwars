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
      for (final switches in <(bool, bool, bool)>[
        (true, true, false),
        (false, true, false),
        (true, false, false),
        (true, true, true),
      ]) {
        final (arenaEnabled, skillEnabled, masterDisabled) = switches;
        test('spike source isolation ${mode.name}/${shape.name} '
            'arena=$arenaEnabled skill=$skillEnabled master=$masterDisabled', () {
          final config = PowerUpConfig.defaults
              .withValue('arenaTrapsEnabled', arenaEnabled ? 1 : 0)
              .withValue('skillTrapsEnabled', skillEnabled ? 1 : 0)
              .withValue('allTrapsDisabled', masterDisabled ? 1 : 0);
          final match = MatchSimulationController(contestants,
              mode: mode, arenaShape: shape, arenaRadius: 260,
              seed: 811, lookAhead: false, tuning: config);
          final system = match.powerUps!;
          system.spikeWalls.addAll([
            SpikeWall(position: const Offset(220, 0), angle: 0,
                spawnStep: 0, arenaGenerated: true),
            SpikeWall(position: const Offset(-220, 0), angle: 3.14159,
                spawnStep: 0),
          ]);
          match.tick(1 / 60);
          expect(system.spikeWalls.where((w) => w.arenaGenerated).length,
              arenaEnabled && !masterDisabled ? 1 : 0);
          expect(system.spikeWalls.where((w) => !w.arenaGenerated).length,
              skillEnabled && !masterDisabled ? 1 : 0);
        });
      }
    }
  }
}
