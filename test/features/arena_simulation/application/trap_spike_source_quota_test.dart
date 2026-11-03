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
      for (final incomingArena in [true, false]) {
        test('spike source quota isolates ${incomingArena ? 'arena' : 'skill'} '
            'spawn in ${mode.name}/${shape.name}', () {
          final match = MatchSimulationController(
            contestants, mode: mode, arenaShape: shape, arenaRadius: 260,
            seed: 871, lookAhead: false, tuning: PowerUpConfig.defaults,
          );
          final system = match.powerUps!..automaticSpawning = false;
          // Three walls is the per-source cap for two contestants. Keep the
          // opposite source at capacity while adding one of the incoming type.
          final opposite = !incomingArena;
          final original = [
            for (var i = 0; i < 3; i++)
              SpikeWall(position: Offset(i * 2.0, 0), angle: 0,
                  spawnStep: i, arenaGenerated: opposite),
          ];
          system.spikeWalls.addAll(original);
          if (incomingArena) {
            system.spawnTestArenaHazard();
          } else {
            system.spawnTestItem(PowerUpKind.spikeWall);
          }
          expect(system.spikeWalls.where((wall) =>
              wall.arenaGenerated == opposite), containsAll(original));
          expect(system.spikeWalls.where((wall) =>
              wall.arenaGenerated == opposite).length, 3);
          expect(system.spikeWalls.any((wall) =>
              wall.arenaGenerated == incomingArena), isTrue,
              reason: 'The requested source must still be able to spawn');
        });
      }
    }
  }
}
