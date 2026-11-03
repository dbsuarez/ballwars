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
      test('theme transition clears only automatic hazards: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants,
          mode: mode, arenaShape: shape, arenaRadius: 260,
          seed: 530, lookAhead: false, tuning: PowerUpConfig.defaults);
        final system = match.powerUps!;
        final automatic = SpikeWall(position: const Offset(200, 0),
          angle: 0, spawnStep: 0, arenaGenerated: true);
        final skill = SpikeWall(position: const Offset(190, 0),
          angle: 0, spawnStep: 0);
        final portal = ArenaPortal(position: const Offset(120, 0), spawnStep: 0);
        final goo = StickyGoo(position: const Offset(130, 0), spawnStep: 0);
        final poison = PoisonSwamp(position: const Offset(140, 0), spawnStep: 0);
        system.spikeWalls.addAll([automatic, skill]);
        system.portals.add(portal);
        system.stickyGoo.add(goo);
        system.poisonSwamps.add(poison);
        for (final kind in ArenaThemeHazardKind.values) {
          system.arenaThemeHazards.add(ArenaThemeHazard(
            kind: kind, position: Offset.zero, spawnStep: 0));
        }
        system.clearAutomaticArenaHazards();
        expect(system.arenaThemeHazards, isEmpty);
        expect(system.spikeWalls, [skill]);
        expect(system.portals, [portal]);
        expect(system.stickyGoo, [goo]);
        expect(system.poisonSwamps, [poison]);
        system.clearAutomaticArenaHazards();
        expect(system.spikeWalls, [skill]);
      });
      test('theme transition does not eject immobilized quicksand victim: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants,
          mode: mode, arenaShape: shape, arenaRadius: 260,
          seed: 531, lookAhead: false, tuning: PowerUpConfig.defaults);
        final system = match.powerUps!;
        final ball = match.state.balls.first;
        ball.position = Offset.zero;
        ball.velocity = Offset.zero;
        ball.stickyGooLeft = 30;
        final sand = ArenaThemeHazard(kind: ArenaThemeHazardKind.quicksand,
          position: Offset.zero, spawnStep: 0);
        sand.affected.add(ball);
        system.arenaThemeHazards.add(sand);
        system.clearAutomaticArenaHazards();
        expect(ball.velocity, Offset.zero);
        expect(ball.stickyGooLeft, 30);
      });
    }
  }
}
