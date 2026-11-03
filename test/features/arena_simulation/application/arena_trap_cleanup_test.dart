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

  for (final scenario in <(String, PowerUpConfig)>[
    ('arena switch disabled', PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0)),
    ('master switch disabled', PowerUpConfig.defaults.withValue('allTrapsDisabled', 1)),
  ]) {
    test('existing quicksand releases its affected ball: ${scenario.$1}', () {
      final match = MatchSimulationController(
        balls,
        arenaRadius: 260,
        seed: 19,
        mode: MatchMode.arsenal,
        lookAhead: false,
        tuning: scenario.$2,
      );
      final system = match.powerUps!;
      final ball = match.state.balls.first;
      ball.position = const Offset(30, 0);
      ball.velocity = Offset.zero;
      final hazard = ArenaThemeHazard(
        kind: ArenaThemeHazardKind.quicksand,
        position: Offset.zero,
        spawnStep: 0,
      )..affected.add(ball);
      system.arenaThemeHazards.add(hazard);

      match.tick(1 / 60);

      expect(system.arenaThemeHazards, isEmpty);
      expect(ball.velocity.distance, greaterThan(0));
      expect(ball.velocity.dx, greaterThan(0), reason: 'release points away from quicksand');
    });
  }

  test('disabling skill traps alone does not clear existing arena hazards', () {
    final match = MatchSimulationController(
      balls,
      arenaRadius: 260,
      seed: 19,
      mode: MatchMode.arsenal,
      lookAhead: false,
      tuning: PowerUpConfig.defaults.withValue('skillTrapsEnabled', 0),
    );
    final hazard = ArenaThemeHazard(
      kind: ArenaThemeHazardKind.quicksand,
      position: Offset.zero,
      spawnStep: 0,
    );
    match.powerUps!.arenaThemeHazards.add(hazard);
    match.tick(1 / 60);
    expect(match.powerUps!.arenaThemeHazards, contains(hazard));
  });
  // Both combat modes construct a power-up system. Trap-source policy must
  // behave identically regardless of the match's combat rules.
  for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
    test('arena hazard cleanup is consistent in ${mode.name}', () {
      final config = PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0);
      final match = MatchSimulationController(
        balls,
        arenaRadius: 260,
        seed: 31,
        mode: mode,
        lookAhead: false,
        tuning: config,
      );
      final system = match.powerUps!;
      final ball = match.state.balls.first;
      ball.position = const Offset(30, 0);
      ball.velocity = Offset.zero;
      system.arenaThemeHazards.add(ArenaThemeHazard(
        kind: ArenaThemeHazardKind.quicksand,
        position: Offset.zero,
        spawnStep: 0,
      )..affected.add(ball));
      match.tick(1 / 60);
      expect(system.arenaThemeHazards, isEmpty);
      expect(ball.velocity.dx, greaterThan(0));
    });

    test('skill trap toggle preserves arena hazards in ${mode.name}', () {
      final match = MatchSimulationController(
        balls,
        arenaRadius: 260,
        seed: 31,
        mode: mode,
        lookAhead: false,
        tuning: PowerUpConfig.defaults.withValue('skillTrapsEnabled', 0),
      );
      final system = match.powerUps!;
      final hazard = ArenaThemeHazard(
        kind: ArenaThemeHazardKind.quicksand,
        position: Offset.zero,
        spawnStep: 0,
      );
      system.arenaThemeHazards.add(hazard);
      match.tick(1 / 60);
      expect(system.arenaThemeHazards, contains(hazard));
    });
  }

  // Arena geometry must not change the precedence of the two independent
  // source switches or the master override. Test both supported shapes and
  // combat modes with live quicksand rather than only configuration getters.
  for (final shape in [ArenaShape.circle, ArenaShape.square]) {
    for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
      for (final scenario in <(String, PowerUpConfig, bool)>[
        ('arena off', PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0), true),
        ('master off', PowerUpConfig.defaults.withValue('allTrapsDisabled', 1), true),
        ('skill off', PowerUpConfig.defaults.withValue('skillTrapsEnabled', 0), false),
      ]) {
        test('quicksand policy ${shape.name}/${mode.name}/${scenario.$1}', () {
          final match = MatchSimulationController(
            balls,
            arenaRadius: 260,
            arenaShape: shape,
            seed: 43,
            mode: mode,
            lookAhead: false,
            tuning: scenario.$2,
          );
          final system = match.powerUps!;
          final ball = match.state.balls.first;
          ball.position = const Offset(30, 0);
          ball.velocity = Offset.zero;
          final hazard = ArenaThemeHazard(
            kind: ArenaThemeHazardKind.quicksand,
            position: Offset.zero,
            spawnStep: 0,
          )..affected.add(ball);
          system.arenaThemeHazards.add(hazard);
          match.tick(1 / 60);
          if (scenario.$3) {
            expect(system.arenaThemeHazards, isEmpty);
            expect(ball.velocity.dx, greaterThan(0));
          } else {
            expect(system.arenaThemeHazards, contains(hazard));
          }
        });
      }
    }
  }

  for (final mode in [MatchMode.threads, MatchMode.threadGrowth]) {
    test('thread-only mode ${mode.name} has no automatic trap system', () {
      final match = MatchSimulationController(
        balls,
        arenaRadius: 260,
        seed: 31,
        mode: mode,
        lookAhead: false,
        tuning: PowerUpConfig.defaults.withValue('allTrapsDisabled', 1),
      );
      expect(match.powerUps, isNull);
      match.tick(1 / 60);
      expect(match.powerUps, isNull);
    });
  }

  for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
    test('vine snare releases on arena switch disable in ${mode.name}', () {
      final match = MatchSimulationController(
        balls,
        arenaRadius: 260,
        seed: 51,
        mode: mode,
        lookAhead: false,
        tuning: PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0),
      );
      final ball = match.state.balls.first;
      ball.position = const Offset(120, 0);
      ball.velocity = Offset.zero;
      ball.stickyGooLeft = 90;
      match.powerUps!.arenaThemeHazards.add(ArenaThemeHazard(
        kind: ArenaThemeHazardKind.vineSnare,
        position: const Offset(120, 0),
        spawnStep: 0,
      )..affected.add(ball));
      match.tick(1 / 60);
      expect(match.powerUps!.arenaThemeHazards, isEmpty);
    });
  }

}

