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
}
