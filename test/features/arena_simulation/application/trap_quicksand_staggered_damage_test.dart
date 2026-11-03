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
      test('staggered quicksand ages cannot multiply periodic damage: ${mode.name}/${shape.name}', () {
        MatchSimulationController setup(bool overlap) {
          final match = MatchSimulationController(contestants,
            mode: mode, arenaShape: shape, arenaRadius: 260,
            seed: 2014, lookAhead: false, tuning: PowerUpConfig.defaults);
          final system = match.powerUps!..automaticSpawning = false;
          final ball = match.state.balls.first;
          ball.position = const Offset(10, 0);
          ball.velocity = Offset.zero;
          system.arenaThemeHazards.add(ArenaThemeHazard(
            kind: ArenaThemeHazardKind.quicksand,
            position: Offset.zero, spawnStep: 0));
          if (overlap) {
            final later = ArenaThemeHazard(
              kind: ArenaThemeHazardKind.quicksand,
              position: Offset.zero, spawnStep: 30);
            later.age = 30;
            system.arenaThemeHazards.add(later);
          }
          return match;
        }
        final single = setup(false);
        final overlapping = setup(true);
        for (var i = 0; i < 60; i++) {
          single.state.balls.first.position = const Offset(10, 0);
          overlapping.state.balls.first.position = const Offset(10, 0);
          single.state.balls.first.velocity = Offset.zero;
          overlapping.state.balls.first.velocity = Offset.zero;
          single.tick(1 / 60);
          overlapping.tick(1 / 60);
        }
        if (mode == MatchMode.arsenal) {
          expect(overlapping.state.balls.first.life,
            closeTo(single.state.balls.first.life, 0.0001));
        } else {
          expect(overlapping.state.balls.first.fanLines.length,
            single.state.balls.first.fanLines.length);
        }
      });
    }
  }
}
