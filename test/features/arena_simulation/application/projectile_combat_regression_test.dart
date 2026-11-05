import 'dart:math' as math;

import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _balls = [
  CustomBall(
    id: 'a',
    name: 'Shooter',
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  CustomBall(
    id: 'b',
    name: 'Target',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
];

MatchSimulationController _arena(
  SkillDefinition skill, {
  int simulationRevision = 8,
}) {
  final match = MatchSimulationController(
    _balls,
    arenaRadius: 260,
    simulationRevision: simulationRevision,
    seed: 12,
    layoutRotation: 0,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: SkillLibrary.defaults.withDefinition(
      skill,
      PowerUpConfig.defaults,
    ),
  );
  final shooter = match.state.balls.first;
  final target = match.state.balls.last;
  shooter.position = const Offset(-100, 0);
  target.position = const Offset(100, 0);
  shooter.velocity = Offset.zero;
  target.velocity = Offset.zero;
  match.powerUps!.automaticSpawning = false;
  match.powerUps!.field.add(
    FieldPowerUp(
      kind: skill.baseKind,
      skillId: skill.id,
      position: shooter.position,
      spawnStep: 0,
    ),
  );
  match.tick(1 / 60);
  return match;
}

void _step(MatchSimulationController match, int count) {
  for (var i = 0; i < count; i++) {
    match.tick(1 / 60);
  }
}

SkillDefinition _volley({
  int count = 5,
  double spread = 60,
  double cooldown = 2,
}) => SkillLibrary.defaults
    .create('Regression Volley', PowerUpKind.pistol)
    .copyWith(
      enabled: true,
      trigger: SkillTrigger.aimedFire,
      delivery: SkillDelivery.projectile,
      targeting: SkillTargeting.nearestOpponent,
      effectType: SkillEffectType.damage,
      arsenalDamage: 7,
      projectileCount: count,
      spreadDegrees: spread,
      cooldownSeconds: cooldown,
    );

void main() {
  test('custom beams use the shared emission point for their hit ray', () {
    final skill = _volley(count: 1).copyWith(
      delivery: SkillDelivery.beam,
      range: .01,
      projectileOriginForward: 0,
      projectileOriginSide: 5,
    );
    final displaced = _arena(skill);
    _step(displaced, PowerUpTuning.aimSteps + 2);
    expect(displaced.state.balls.last.life, PowerUpTuning.arenaLife);
    final centered = _arena(skill.copyWith(projectileOriginSide: 0));
    _step(centered, PowerUpTuning.aimSteps + 2);
    expect(centered.state.balls.last.life, lessThan(PowerUpTuning.arenaLife));
    final legacy = _arena(skill, simulationRevision: 7);
    _step(legacy, PowerUpTuning.aimSteps + 2);
    expect(legacy.state.balls.last.life, lessThan(PowerUpTuning.arenaLife));
  });

  for (final revision in [7, 8]) {
    test(
      'Energy Wave emitter revision $revision preserves hits and releases every ball',
      () {
        final skill = SkillLibrary.defaults
            .builtIn(PowerUpKind.energyWave, PowerUpConfig.defaults)
            .copyWith(projectileOriginForward: 2, projectileOriginSide: -0.5);
        final match = _arena(skill, simulationRevision: revision);
        _step(match, PowerUpTuning.aimSteps + 1);
        final attack = match.powerUps!.energyWaveAttacks.single;
        expect(attack.emitter.isCustom, revision >= 8);
        if (revision >= 8) {
          expect(
            attack.origin(const Offset(1, 0)),
            attack.owner.position +
                Offset(attack.owner.radius * 2, attack.owner.radius * -0.5),
          );
        }
        _step(match, EnergyWaveAttack.chargeSteps);
        final wave = match.powerUps!.energyWaves.single;
        expect(wave.emitter, same(attack.emitter));
        expect(
          wave.origin(const Offset(1, 0)),
          attack.origin(const Offset(1, 0)),
        );
        _step(match, EnergyWaveAttack.beamSteps + 15);
        expect(match.powerUps!.energyWaveAttacks, isEmpty);
        expect(match.state.balls.last.life, lessThan(PowerUpTuning.arenaLife));
        expect(
          match.state.balls.every(
            (b) => b.position.dx.isFinite && b.position.dy.isFinite,
          ),
          isTrue,
        );
      },
    );
  }

  test('flame origin follows caster and controls the actual damage cone', () {
    final skill = SkillLibrary.defaults
        .builtIn(PowerUpKind.flamethrower, PowerUpConfig.defaults)
        .copyWith(
          enabled: true,
          projectileOriginForward: 0,
          projectileOriginSide: 5,
        );
    final match = _arena(skill);
    _step(match, PowerUpTuning.aimSteps + 2);
    final cone = match.powerUps!.flameCones.single;
    final owner = match.state.balls.first;
    final target = match.state.balls.last;
    expect(cone.customOrigin, isTrue);
    expect(
      cone.origin,
      match.powerUps!.projectileOrigin(owner, skill, const Offset(1, 0)),
    );
    // The opponent is on the old centerline but outside the displaced cone.
    expect(target.life, PowerUpTuning.arenaLife);
    final before = cone.origin;
    owner.position += const Offset(0, 10);
    expect(cone.origin, before + const Offset(0, 10));
    target.position = cone.origin + const Offset(100, 0);
    _step(match, PowerUpTuning.flamethrowerTickSteps + 1);
    expect(target.life, lessThan(PowerUpTuning.arenaLife));
  });

  test('revision 7 flame keeps the old origin despite a saved override', () {
    final skill = SkillLibrary.defaults
        .builtIn(PowerUpKind.flamethrower, PowerUpConfig.defaults)
        .copyWith(
          enabled: true,
          projectileOriginForward: 3,
          projectileOriginSide: 5,
        );
    final match = _arena(skill, simulationRevision: 7);
    _step(match, PowerUpTuning.aimSteps + 2);
    final cone = match.powerUps!.flameCones.single;
    expect(cone.customOrigin, isFalse);
    expect(cone.origin, cone.owner.position);
    expect(match.state.balls.last.life, lessThan(PowerUpTuning.arenaLife));
  });

  test('extreme Energy Wave offset cannot skip damage or leave a freeze', () {
    final skill = SkillLibrary.defaults
        .builtIn(PowerUpKind.energyWave, PowerUpConfig.defaults)
        .copyWith(projectileOriginForward: 5, projectileOriginSide: 5);
    final match = _arena(skill);
    _step(
      match,
      PowerUpTuning.aimSteps +
          EnergyWaveAttack.chargeSteps +
          EnergyWaveAttack.beamSteps +
          20,
    );
    expect(match.state.balls.last.life, lessThan(PowerUpTuning.arenaLife));
    expect(match.powerUps!.energyWaveAttacks, isEmpty);
    final target = match.state.balls.last;
    final position = target.position;
    target.velocity = const Offset(20, 0);
    _step(match, 2);
    expect(target.position, isNot(position));
  });

  test('full composed volley launches the configured number of shots', () {
    final match = _arena(_volley());
    final shooter = match.state.balls.first;
    shooter.aimLeft = 1;
    _step(match, 1);
    final shots = match.powerUps!.projectiles;
    expect(shots, hasLength(5));
    expect(shots.every((shot) => identical(shot.owner, shooter)), isTrue);
    final angles = shots
        .map((shot) => math.atan2(shot.velocity.dy, shot.velocity.dx))
        .toList();
    for (var i = 0; i < angles.length; i++) {
      expect(angles[i], closeTo((-30 + 15 * i) * math.pi / 180, 1e-8));
    }
  });

  test('single projectile ignores configured spread', () {
    final match = _arena(_volley(count: 1, spread: 85));
    match.state.balls.first.aimLeft = 1;
    _step(match, 1);
    final shot = match.powerUps!.projectiles.single;
    expect(shot.velocity.dy, closeTo(0, 1e-8));
    expect(shot.velocity.dx, greaterThan(0));
  });

  test('firing cooldown is not reset by the subsequent projectile hit', () {
    final match = _arena(_volley(count: 1, spread: 0, cooldown: 5));
    final shooter = match.state.balls.first;
    final target = match.state.balls.last;
    shooter.aimLeft = 1;
    _step(match, 1);
    expect(match.powerUps!.shots, 1);
    final firstShot = match.powerUps!.projectiles.single;
    // Bring the target into the flight path while the firing cooldown is active.
    target.position = firstShot.position + const Offset(15, 0);
    _step(match, 10);
    expect(target.life, lessThan(PowerUpTuning.arenaLife));
    expect(match.powerUps!.shots, 1);
    _step(match, 20);
    expect(match.powerUps!.shots, 1);
  });
}
