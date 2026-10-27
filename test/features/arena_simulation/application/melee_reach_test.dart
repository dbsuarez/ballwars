import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const _balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
  CustomBall(
    id: 'c',
    name: 'C',
    primaryColor: Colors.green,
    glowColor: Colors.lime,
  ),
];

const _life = PowerUpTuning.arenaLife;

/// A seeded Arsenal match with only contact weapons, run to its end; the summary includes the next
/// RNG draw, so any change in the draws shows up.
String _summary(int seed) {
  final c = MatchSimulationController(
    _balls,
    arenaRadius: 260,
    seed: seed,
    mode: MatchMode.arsenal,
    lookAhead: false,
    powerUpKinds: const {
      PowerUpKind.knife,
      PowerUpKind.sword,
      PowerUpKind.shield,
      PowerUpKind.orbitingFlail,
    },
  );
  for (var i = 0; i < 60 * 300 && c.state.winnerId == null; i++) {
    c.tick(1 / 60);
  }
  final p = c.powerUps!;
  final lives = c.state.balls.map((b) => b.life.toStringAsFixed(6)).join(',');
  return '${c.state.winnerId}|${c.stepCount}|${p.slashes}|${p.hits}|'
      '${p.blocks}|$lives|${p.rng.nextDouble().toStringAsFixed(12)}';
}

/// Recorded on the commit before melee reach existed (f577379).
const _recorded = {
  1: 'c|2868|2|4|0|0.000000,0.000000,55.000000|0.276405864515',
  2: 'c|1805|5|5|1|0.000000,0.000000,10.000000|0.543463282683',
  3: 'c|1474|3|4|1|0.000000,0.000000,100.000000|0.658692754589',
  4: 'a|1392|4|4|0|66.250000,0.000000,0.000000|0.239792143297',
  5: 'c|1128|3|3|0|0.000000,0.000000,32.500000|0.309392773177',
};

/// Two still balls in Arsenal, [a] holding a knife skill with [reach], centers [gapRadii] attacker
/// radii beyond touching.
(MatchSimulationController, SkillDefinition) _reachMatch({
  required double reach,
  required double gapRadii,
  PowerUpKind carrier = PowerUpKind.knife,
}) {
  final skill = SkillLibrary.defaults
      .create('Long Knife', carrier)
      .copyWith(enabled: true, meleeReach: reach);
  final library = SkillLibrary.defaults.withDefinition(
    skill,
    PowerUpConfig.defaults,
  );
  final c = MatchSimulationController(
    _balls.take(2).toList(),
    arenaRadius: 260,
    seed: 1,
    layoutRotation: 0,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: library,
  );
  c.powerUps!.automaticSpawning = false;
  final [a, b] = c.state.balls;
  for (final ball in c.state.balls) {
    ball.velocity = Offset.zero;
  }
  a.position = const Offset(-50, 0);
  b.position = Offset(-50 + a.radius + b.radius + gapRadii * a.radius, 0);
  a.equipWeapon(carrier, skillId: skill.id, dualWield: false);
  return (c, skill);
}

void main() {
  test(
    'with every reach at 0, a contact-weapon match plays exactly as before',
    () {
      for (final entry in _recorded.entries) {
        expect(_summary(entry.key), entry.value, reason: 'seed ${entry.key}');
      }
    },
  );

  test('a knife with reach 1 hits a ball 0.9 radii away without touching', () {
    final (c, _) = _reachMatch(reach: 1, gapRadii: 0.9);
    final [a, b] = c.state.balls;
    c.tick(1 / 60);
    expect(c.ballHits, 0);
    expect(b.life, _life - PowerUpTuning.arenaDamage[PowerUpKind.knife]!);
    expect(a.held, isNull);
    expect(c.powerUps!.slashes, 1);
    // Used up: it never strikes twice.
    for (var i = 0; i < 10; i++) {
      c.tick(1 / 60);
    }
    expect(b.life, _life - PowerUpTuning.arenaDamage[PowerUpKind.knife]!);
    expect(c.powerUps!.slashes, 1);
  });

  test('a knife with reach 1 misses a ball 1.1 radii away', () {
    final (c, _) = _reachMatch(reach: 1, gapRadii: 1.1);
    final [a, b] = c.state.balls;
    c.tick(1 / 60);
    expect(b.life, _life);
    expect(a.held, PowerUpKind.knife);
  });

  test('reach never hits a ghost', () {
    final (c, _) = _reachMatch(reach: 1, gapRadii: 0.5);
    final [a, b] = c.state.balls;
    b.ghostLeft = 100;
    c.tick(1 / 60);
    expect(b.life, _life);
    expect(a.held, PowerUpKind.knife);
  });

  test('a ghost holding a reach knife strikes nobody', () {
    final (c, _) = _reachMatch(reach: 1, gapRadii: 0.5);
    final [a, b] = c.state.balls;
    a.ghostLeft = 100;
    c.tick(1 / 60);
    expect(b.life, _life);
    expect(a.held, PowerUpKind.knife);
  });

  test('a reach shield bashes only a ball that holds nothing', () {
    final (c, _) = _reachMatch(
      reach: 1,
      gapRadii: 0.5,
      carrier: PowerUpKind.shield,
    );
    final [a, b] = c.state.balls;
    b.equipWeapon(PowerUpKind.knife, dualWield: false);
    c.tick(1 / 60);
    expect(a.held, PowerUpKind.shield);
    expect(b.life, _life);
  });

  test('a reach shield bashes an unarmed ball', () {
    final (c, _) = _reachMatch(
      reach: 1,
      gapRadii: 0.5,
      carrier: PowerUpKind.shield,
    );
    final [a, b] = c.state.balls;
    c.tick(1 / 60);
    expect(a.held, isNull);
    expect(b.life, lessThan(_life));
  });

  /// Two still balls in Arsenal at a gap of [gapRadii] radii beyond touching, built from [order] of the
  /// first two test balls; [library] holds the skills they are given.
  MatchSimulationController still(
    SkillLibrary library, {
    required double gapRadii,
    List<CustomBall>? order,
    bool dualWield = false,
  }) {
    final c = MatchSimulationController(
      order ?? _balls.take(2).toList(),
      arenaRadius: 260,
      seed: 1,
      layoutRotation: 0,
      mode: MatchMode.arsenal,
      lookAhead: false,
      dualWield: dualWield,
      skillLibrary: library,
    );
    c.powerUps!.automaticSpawning = false;
    final [a, b] = c.state.balls;
    for (final ball in c.state.balls) {
      ball.velocity = Offset.zero;
    }
    a.position = const Offset(-50, 0);
    b.position = Offset(-50 + a.radius + b.radius + gapRadii * a.radius, 0);
    return c;
  }

  SkillDefinition reachSkill(String name, PowerUpKind carrier) => SkillLibrary
      .defaults
      .create(name, carrier)
      .copyWith(enabled: true, meleeReach: 1);

  test(
    'two balls in reach of each other both strike, whatever their order',
    () {
      final knife = reachSkill('Long Knife', PowerUpKind.knife);
      final library = SkillLibrary.defaults.withDefinition(
        knife,
        PowerUpConfig.defaults,
      );
      for (final order in [
        [_balls[0], _balls[1]],
        [_balls[1], _balls[0]],
      ]) {
        final c = still(library, gapRadii: 0.5, order: order);
        for (final ball in c.state.balls) {
          ball.life = 5;
          ball.equipWeapon(
            PowerUpKind.knife,
            skillId: knife.id,
            dualWield: false,
          );
        }
        c.tick(1 / 60);
        // Both lethal hits land: the first one doesn't stop the second.
        expect(c.powerUps!.slashes, 2, reason: order.first.id);
        expect(c.powerUps!.hits, 2, reason: order.first.id);
        for (final ball in c.state.balls) {
          expect(ball.held, isNull);
        }
      }
    },
  );

  test('a collision skill strikes by reach and is used up', () {
    final bonk = reachSkill('Bonk', PowerUpKind.pistol).copyWith(
      trigger: SkillTrigger.collision,
      delivery: SkillDelivery.instant,
    );
    expect(bonk.isComposed, isTrue);
    final c = still(
      SkillLibrary.defaults.withDefinition(bonk, PowerUpConfig.defaults),
      gapRadii: 0.5,
    );
    final [a, b] = c.state.balls;
    a.equipWeapon(PowerUpKind.pistol, skillId: bonk.id, dualWield: false);
    c.tick(1 / 60);
    expect(c.ballHits, 0);
    expect(b.life, lessThan(_life));
    expect(a.held, isNull);
  });

  test('dual wield: both reach weapons strike', () {
    final knife = reachSkill('Long Knife', PowerUpKind.knife);
    final sword = reachSkill('Long Sword', PowerUpKind.sword);
    final library = SkillLibrary.defaults
        .withDefinition(knife, PowerUpConfig.defaults)
        .withDefinition(sword, PowerUpConfig.defaults);
    final c = still(library, gapRadii: 0.5, dualWield: true);
    final [a, b] = c.state.balls;
    a
      ..equipWeapon(PowerUpKind.knife, skillId: knife.id, dualWield: true)
      ..equipWeapon(PowerUpKind.sword, skillId: sword.id, dualWield: true);
    expect(a.equippedWeapons, hasLength(2));
    c.tick(1 / 60);
    expect(c.powerUps!.slashes, 2);
    expect(
      b.life,
      _life -
          PowerUpTuning.arenaDamage[PowerUpKind.knife]! -
          PowerUpTuning.arenaDamage[PowerUpKind.sword]!,
    );
    expect(a.equippedWeapons, isEmpty);
  });

  test('a bump and a reach in the same step strike only once', () {
    final knife = reachSkill('Long Knife', PowerUpKind.knife);
    final c = still(
      SkillLibrary.defaults.withDefinition(knife, PowerUpConfig.defaults),
      gapRadii: 0,
    );
    final [a, b] = c.state.balls;
    // Already overlapping and closing, so this step bumps.
    b.position -= const Offset(2, 0);
    a.velocity = const Offset(60, 0);
    b.velocity = const Offset(-60, 0);
    a.equipWeapon(PowerUpKind.knife, skillId: knife.id, dualWield: false);
    c.tick(1 / 60);
    expect(c.ballHits, 1);
    expect(c.powerUps!.slashes, 1);
    expect(
      b.life,
      _life -
          PowerUpTuning.arenaCollisionDamage -
          PowerUpTuning.arenaDamage[PowerUpKind.knife]!,
    );
    expect(a.held, isNull);
  });
}
