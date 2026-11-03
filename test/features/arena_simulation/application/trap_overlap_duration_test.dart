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
  for (final shape in [ArenaShape.circle, ArenaShape.square]) {
    for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
      test('vine source alone expires independently: ${shape.name}/${mode.name}', () {
        final tuning = PowerUpConfig.defaults
            .withValue('arenaTrapsEnabled', 1)
            .withValue('skillTrapsEnabled', 1)
            .withValue('allTrapsDisabled', 0);
        final match = MatchSimulationController(balls, mode: mode,
            arenaShape: shape, arenaRadius: 260, seed: 610,
            lookAhead: false, tuning: tuning);
        final ball = match.state.balls.first;
        ball.position = Offset.zero;
        match.powerUps!.arenaThemeHazards.add(ArenaThemeHazard(
            kind: ArenaThemeHazardKind.vineSnare,
            position: Offset.zero, spawnStep: 0));
        match.tick(1 / 60);
        expect(ball.stickyGooLeft, greaterThan(0));
        expect(ball.velocity, Offset.zero);
      });
    }
  }
}
