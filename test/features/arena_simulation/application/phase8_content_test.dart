import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
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
  int count = 2,
  PowerUpConfig tuning = PowerUpConfig.defaults,
}) {
  final match = MatchSimulationController(
    _balls.take(count).toList(),
    arenaRadius: 260,
    seed: 88,
    layoutRotation: 0,
    mode: MatchMode.arsenal,
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

void main() {
  test('Fried Chicken restores to 100 but does nothing at or above 100', () {
    final match = _match();
    final owner = match.state.balls.first;

    owner.life = 31;
    _give(match, owner, PowerUpKind.friedChicken);
    expect(owner.life, 100);

    owner.life = 125;
    final particles = match.state.particles.particles.length;
    _give(match, owner, PowerUpKind.friedChicken);
    expect(owner.life, 125);
    expect(match.state.particles.particles.length, particles);
  });

  test('Special Sniper is an unavoidable one-shot through golden armor', () {
    final match = _match();
    final [owner, target] = match.state.balls;
    owner.position = const Offset(-100, 0);
    target
      ..position = const Offset(100, 0)
      ..goldenArmorHits = 2;

    _give(match, owner, PowerUpKind.sniperRifle);
    _run(match, PowerUpTuning.aimSteps);

    expect(target.life, 0);
    expect(target.goldenArmorHits, 0);
    expect(match.powerUps!.projectiles, isEmpty);
    expect(match.powerUps!.sniperFlashes, isNotEmpty);
  });

  test('Buster Sword freezes time and chooses the farthest opponent', () {
    final match = _match(count: 3);
    final [owner, near, far] = match.state.balls;
    owner.position = Offset.zero;
    near.position = const Offset(35, 0);
    far.position = const Offset(190, 0);

    _give(match, owner, PowerUpKind.busterSword);
    _run(match, PowerUpTuning.aimSteps);

    expect(match.powerUps!.omnislashAttacks.single.target, same(far));
    expect(match.state.balls.every((ball) => ball.stunnedLeft > 0), isTrue);
    _run(match, 40);
    expect(far.life, 76);
    expect(near.life, 100);
  });

  test(
    'Raging Demon hits the nearest target the configured number of times',
    () {
      final tuning = PowerUpConfig.defaults.withValue('ragingDemonHits', 7);
      final match = _match(count: 3, tuning: tuning);
      final [owner, near, far] = match.state.balls;
      owner.position = Offset.zero;
      near.position = const Offset(45, 0);
      far.position = const Offset(180, 0);

      _give(match, owner, PowerUpKind.ragingDemon);
      expect(match.powerUps!.ragingDemonAttacks.single.target, same(near));
      _run(match, 14);

      expect(near.life, 93);
      expect(far.life, 100);
      expect(match.powerUps!.ragingDemonAttacks.single.hitsShown, 7);
    },
  );
}
