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

  // A trap already present in the field must not bypass a changed policy.
  // Neither the independent arena switch nor the master switch should be
  // mistaken for the independent skill-trap switch.
  // Forced admin spawns must use the skill-trap switch, not the arena switch.
  // The master override must also prevent a forced trap from entering the field.
  for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
    for (final scenario in <(String, PowerUpConfig)>[
      ('skill off', PowerUpConfig.defaults.withValue('skillTrapsEnabled', 0)),
      ('master off', PowerUpConfig.defaults.withValue('allTrapsDisabled', 1)),
    ]) {
      test('forced mine spawn blocked in ${mode.name}: ${scenario.$1}', () {
        final match = MatchSimulationController(
          balls,
          arenaRadius: 260,
          seed: 83,
          mode: mode,
          lookAhead: false,
          tuning: scenario.$2,
        );
        final system = match.powerUps!;
        system.spawnTestItem(PowerUpKind.mine);
        expect(system.field.where((item) => item.kind == PowerUpKind.mine), isEmpty);
      });
    }
  }

  for (final scenario in <(String, PowerUpConfig, bool)>[
    ('skill off', PowerUpConfig.defaults.withValue('skillTrapsEnabled', 0), false),
    ('master off', PowerUpConfig.defaults.withValue('allTrapsDisabled', 1), false),
    ('arena off', PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0), true),
  ]) {
    test('direct mine pickup respects ${scenario.$1}', () {
      final match = MatchSimulationController(
        balls,
        arenaRadius: 260,
        seed: 73,
        mode: MatchMode.arsenal,
        lookAhead: false,
        tuning: scenario.$2,
      );
      final system = match.powerUps!;
      final owner = match.state.balls.first;
      final pickup = FieldPowerUp(
        kind: PowerUpKind.mine,
        position: owner.position,
        spawnStep: match.stepCount,
      );
      system.field.add(pickup);
      system.pickUp(owner, pickup);
      expect(system.mines.isNotEmpty, scenario.$3);
      expect(system.field.contains(pickup), !scenario.$3);
    });
  }

  for (final scenario in <(String, PowerUpConfig, bool)>[
    ('skill off', PowerUpConfig.defaults.withValue('skillTrapsEnabled', 0), false),
    ('master off', PowerUpConfig.defaults.withValue('allTrapsDisabled', 1), false),
    ('arena off', PowerUpConfig.defaults.withValue('arenaTrapsEnabled', 0), true),
  ]) {
    test('editor direct mine activation respects ${scenario.$1}', () {
      final match = MatchSimulationController(
        balls,
        arenaRadius: 260,
        seed: 79,
        mode: MatchMode.arsenal,
        lookAhead: false,
        tuning: scenario.$2,
      );
      final system = match.powerUps!;
      final skill = match.skillLibrary.builtIn(PowerUpKind.mine, scenario.$2);
      system.activateTestSkill(
        match.state.balls.first,
        skill,
        match.state.balls.last,
      );
      expect(system.mines.isNotEmpty, scenario.$3);
    });
  }
}
