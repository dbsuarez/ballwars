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
      test('vine snare tracks exit and re-entry: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants,
          mode: mode, arenaShape: shape, arenaRadius: 260,
          seed: 1921, lookAhead: false, tuning: PowerUpConfig.defaults);
        final system = match.powerUps!..automaticSpawning = false;
        final ball = match.state.balls.first;
        final hazard = ArenaThemeHazard(kind: ArenaThemeHazardKind.vineSnare,
          position: Offset.zero, spawnStep: 0);
        system.arenaThemeHazards.add(hazard);
        ball.position = Offset.zero;
        match.tick(1 / 60);
        expect(hazard.affected.contains(ball), isTrue);
        ball.position = const Offset(150, 0);
        match.tick(1 / 60);
        expect(hazard.affected.contains(ball), isFalse);
        ball.position = Offset.zero;
        match.tick(1 / 60);
        expect(hazard.affected.contains(ball), isTrue);
      });
      test('ghosts do not retain vine membership: ${mode.name}/${shape.name}', () {
        final match = MatchSimulationController(contestants,
          mode: mode, arenaShape: shape, arenaRadius: 260,
          seed: 1922, lookAhead: false, tuning: PowerUpConfig.defaults);
        final system = match.powerUps!..automaticSpawning = false;
        final ball = match.state.balls.first;
        final hazard = ArenaThemeHazard(kind: ArenaThemeHazardKind.vineSnare,
          position: Offset.zero, spawnStep: 0);
        system.arenaThemeHazards.add(hazard);
        ball.position = Offset.zero;
        match.tick(1 / 60);
        expect(hazard.affected.contains(ball), isTrue);
        ball.ghostLeft = 30;
        match.tick(1 / 60);
        expect(hazard.affected.contains(ball), isFalse);
      });
    }
  }
}
