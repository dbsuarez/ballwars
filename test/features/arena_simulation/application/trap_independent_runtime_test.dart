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
      for (final disabledSource in ['arena', 'skill']) {
        test('independent $disabledSource cleanup: ${mode.name}/${shape.name}', () {
          final config = PowerUpConfig.defaults
              .withValue('arenaTrapsEnabled', disabledSource == 'arena' ? 0 : 1)
              .withValue('skillTrapsEnabled', disabledSource == 'skill' ? 0 : 1)
              .withValue('allTrapsDisabled', 0);
          final match = MatchSimulationController(
            balls, mode: mode, arenaShape: shape, arenaRadius: 260,
            seed: 902, lookAhead: false, tuning: config,
          );
          final system = match.powerUps!;
          system.arenaThemeHazards.add(ArenaThemeHazard(
            kind: ArenaThemeHazardKind.gravityWell,
            position: const Offset(80, 0), spawnStep: 0,
          ));
          system.portals.add(ArenaPortal(position: const Offset(200, 200), spawnStep: 0));
          system.stickyGoo.add(StickyGoo(position: const Offset(200, 200), spawnStep: 0));
          match.tick(1 / 60);
          if (disabledSource == 'arena') {
            expect(system.arenaThemeHazards, isEmpty);
            expect(system.portals, isNotEmpty);
            expect(system.stickyGoo, isNotEmpty);
          } else {
            expect(system.arenaThemeHazards, isNotEmpty);
            expect(system.portals, isEmpty);
            expect(system.stickyGoo, isEmpty);
          }
        });
      }
    }
  }
}
