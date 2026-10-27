import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
];

/// Every pickup that spawns in [seconds] of a still match: (kind, skill id).
List<(PowerUpKind, String?)> _spawns(
  SkillLibrary library, {
  Set<PowerUpKind>? kinds,
  Set<String>? custom,
  int seconds = 90,
  int seed = 3,
}) {
  final c = MatchSimulationController(
    _balls,
    arenaRadius: 260,
    seed: seed,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: library,
    powerUpKinds: kinds,
    customSkillIds: custom,
  );
  final seen = <(PowerUpKind, String?)>[];
  final known = <Object>{};
  for (var i = 0; i < seconds * 60; i++) {
    for (final ball in c.state.balls) {
      ball.velocity = Offset.zero;
    }
    c.tick(1 / 60);
    for (final p in c.powerUps!.field) {
      if (known.add(p)) seen.add((p.kind, p.skillId));
    }
  }
  return seen;
}

void main() {
  const tuning = PowerUpConfig.defaults;
  final volley = SkillLibrary.defaults.create('Knife Volley', PowerUpKind.knife);
  final library = SkillLibrary.defaults.withDefinition(volley, tuning);

  test('a chosen custom skill spawns even when its base weapon is switched off', () {
    final spawns = _spawns(library, kinds: {PowerUpKind.apple}, custom: {volley.id});
    expect(spawns.where((s) => s.$2 == volley.id), isNotEmpty);
    // Its base weapon itself stays off: knives only ever come as the custom skill.
    expect(spawns.where((s) => s.$1 == PowerUpKind.knife && s.$2 != volley.id), isEmpty);
  });

  test('a custom skill switched off never spawns', () {
    final spawns = _spawns(library, custom: const {});
    expect(spawns.where((s) => s.$2 == volley.id), isEmpty);
    expect(spawns, isNotEmpty);
  });

  test('a custom skill used on contact (collision trigger) spawns', () {
    final blade = SkillLibrary.defaults
        .create('Big Blade', PowerUpKind.sword)
        .copyWith(trigger: SkillTrigger.collision);
    expect(blade.spawnsInArena, isTrue);
    final spawns = _spawns(
      SkillLibrary.defaults.withDefinition(blade, tuning),
      kinds: {PowerUpKind.apple},
      custom: {blade.id},
    );
    expect(spawns.where((s) => s.$2 == blade.id), isNotEmpty);
  });

  test('with everything on, the draws are the same as choosing nothing', () {
    expect(_spawns(library, custom: {volley.id}), _spawns(library));
  });
}
