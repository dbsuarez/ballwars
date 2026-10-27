import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/finisher_profile.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _balls = [
  CustomBall(
    id: 'a',
    name: 'Alpha',
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  CustomBall(
    id: 'b',
    name: 'Beta',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
  CustomBall(
    id: 'c',
    name: 'Gamma',
    primaryColor: Colors.green,
    glowColor: Colors.lime,
  ),
];

MatchSimulationController _match({
  int count = 3,
  int seed = 88,
  MatchMode mode = MatchMode.arsenal,
  PowerUpConfig tuning = PowerUpConfig.defaults,
}) {
  final match = MatchSimulationController(
    _balls.take(count).toList(),
    arenaRadius: 260,
    seed: seed,
    layoutRotation: 0,
    mode: mode,
    lookAhead: false,
    dualWield: true,
    tuning: tuning,
  );
  for (final ball in match.state.balls) {
    ball.velocity = Offset.zero;
  }
  return match;
}

void _run(MatchSimulationController match, int steps) {
  for (var i = 0; i < steps; i++) {
    match.tick(1 / 60);
  }
}

void _give(
  MatchSimulationController match,
  SimulationBall ball,
  PowerUpKind kind,
) {
  match.powerUps!.field.add(
    FieldPowerUp(kind: kind, position: ball.position, spawnStep: 0),
  );
  _run(match, 1);
}

Iterable<String> _texts(MatchSimulationController match) =>
    match.state.floatingTexts.items.map((t) => t.text);

/// Owner in the middle, one opponent near it and one far away.
(SimulationBall, SimulationBall, SimulationBall) _place(
  MatchSimulationController match,
) {
  final [owner, near, far] = match.state.balls;
  owner.position = Offset.zero;
  near.position = const Offset(110, 0);
  far.position = const Offset(-190, 0);
  return (owner, near, far);
}

const _appear = ShadowCloneAttack.appearSteps;
const _strike = ShadowCloneAttack.strikeSteps;
const _vanish = ShadowCloneAttack.vanishSteps;

void main() {
  test(
    'Shadow Clone is a Special-tier instant power-up with its own tuning',
    () {
      const kind = PowerUpKind.shadowClone;
      expect(kind.label, 'Shadow Clone');
      expect(PowerUpKind.values.last, kind);
      expect(kind.isPowerUp, isTrue);
      expect(kind.isGun, isFalse);
      expect(kind.rarity, PowerUpRarity.special);
      expect(PowerUpConfig.defaults.rarityOf(kind), PowerUpRarity.special);
      expect(kind.impactWeight, 1.0);
      expect(PowerUpConfig.damageKinds, contains(kind));
      expect(PowerUpConfig.defaults.arenaDamage(kind), 5);
      expect(PowerUpConfig.defaults.allOutThreads(kind), 2);
      expect(PowerUpConfig.defaults.shadowCloneCount, 3);
      final count = PowerUpConfig.field('shadowCloneCount')!;
      expect(count.label, 'Shadow clones');
      expect([count.min, count.max, count.integer], [1, 6, true]);
      expect(kind.dealsDamage(PowerUpConfig.defaults), isTrue);
      expect(FinisherProfile.profiles, contains('Shadow Clone'));
      final skill = SkillLibrary.defaults.builtIn(kind, PowerUpConfig.defaults);
      expect(skill.yell, 'KAGE BUNSHIN NO JUTSU!');
      expect(
        powerUpDescription(kind, arsenal: true),
        contains('3 shadow clones'),
      );
    },
  );

  test(
    'pickup yells, freezes time and three clones strike the nearest one by one',
    () {
      final match = _match();
      final (owner, near, far) = _place(match);

      _give(match, owner, PowerUpKind.shadowClone);
      final attack = match.powerUps!.shadowCloneAttacks.single;
      expect(attack.owner, same(owner));
      expect(attack.target, same(near));
      expect(attack.clones, 3);
      expect(_texts(match), contains('KAGE BUNSHIN NO JUTSU!'));
      expect(match.state.balls.every((ball) => ball.stunnedLeft > 0), isTrue);
      expect(
        owner.stunnedLeft,
        greaterThanOrEqualTo(ShadowCloneAttack.durationFor(3) - 1),
      );

      _run(match, _appear + _strike - 1);
      expect(near.life, 100);
      expect(attack.clonesDone, 0);
      _run(match, 1);
      expect(near.life, 95);
      expect(attack.clonesDone, 1);
      _run(match, _strike);
      expect(near.life, 90);
      _run(match, _strike);
      expect(near.life, 85);
      expect(attack.clonesDone, 3);
      expect(far.life, 100);
      expect(owner.position, Offset.zero);
      expect(match.powerUps!.shadowCloneAttacks, isNotEmpty);
      _run(match, _vanish);
      expect(match.powerUps!.shadowCloneAttacks, isEmpty);
    },
  );

  test('damage and clone count follow the admin tuning', () {
    final tuning = PowerUpConfig.defaults
        .withValue('shadowCloneCount', 5)
        .withValue('dmg.shadowClone', 9);
    final match = _match(tuning: tuning);
    final (owner, near, _) = _place(match);

    _give(match, owner, PowerUpKind.shadowClone);
    expect(match.powerUps!.shadowCloneAttacks.single.clones, 5);
    _run(match, _appear + 5 * _strike);
    expect(near.life, 100 - 5 * 9);
  });

  test('when the target dies the next clones go for the next nearest', () {
    final match = _match();
    final (owner, near, far) = _place(match);
    near.life = 4;

    _give(match, owner, PowerUpKind.shadowClone);
    _run(match, _appear + _strike);
    expect(near.life, lessThan(1));
    final attack = match.powerUps!.shadowCloneAttacks.single;
    expect(attack.target, same(far));
    _run(match, 2 * _strike);
    expect(far.life, 90);
  });

  test('with no opponent left the remaining clones vanish early', () {
    final match = _match(count: 2);
    final [owner, target] = match.state.balls;
    owner.position = Offset.zero;
    target
      ..position = const Offset(110, 0)
      ..life = 4;

    _give(match, owner, PowerUpKind.shadowClone);
    _run(match, _appear + _strike);
    final attack = match.powerUps!.shadowCloneAttacks.single;
    expect(attack.clonesDone, 1);
    expect(attack.isVanishing, isTrue);
    expect(attack.target, isNull);
  });

  test('All-Out: each clone cuts the configured threads', () {
    final tuning = PowerUpConfig.defaults.withValue('lines.shadowClone', 4);
    final match = _match(mode: MatchMode.allOut, tuning: tuning);
    final (owner, near, _) = _place(match);

    _give(match, owner, PowerUpKind.shadowClone);
    final before = near.fanLines.length;
    _run(match, _appear + 3 * _strike);
    expect(near.fanLines.length, before - 12);
  });

  test(
    'clone positions are pure functions of age and the seed replays exactly',
    () {
      List<Object> trace(int seed) {
        final match = _match(seed: seed);
        final (owner, near, far) = _place(match);
        _give(match, owner, PowerUpKind.shadowClone);
        final out = <Object>[];
        final attack = match.powerUps!.shadowCloneAttacks.single;
        for (var i = 0; i < ShadowCloneAttack.durationFor(3) - 2; i++) {
          _run(match, 1);
          for (var c = 0; c < attack.clones; c++) {
            out.add(attack.clonePosition(c));
          }
        }
        out.addAll([near.life, far.life]);
        return out;
      }

      final a = trace(88);
      expect(trace(88), a);
      // Another seed changes the RNG but not where the clones go.
      expect(trace(5), a);
    },
  );
}
