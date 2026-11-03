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
  CustomBall(id: 'a', name: 'Shooter', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'Target', primaryColor: Colors.blue, glowColor: Colors.cyan),
];

MatchSimulationController _arena(SkillDefinition skill) {
  final match = MatchSimulationController(
    _balls,
    arenaRadius: 260,
    seed: 12,
    layoutRotation: 0,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: SkillLibrary.defaults.withDefinition(skill, PowerUpConfig.defaults),
  );
  final shooter = match.state.balls.first;
  final target = match.state.balls.last;
  shooter.position = const Offset(-100, 0);
  target.position = const Offset(100, 0);
  shooter.velocity = Offset.zero;
  target.velocity = Offset.zero;
  match.powerUps!.automaticSpawning = false;
  match.powerUps!.field.add(FieldPowerUp(
    kind: skill.baseKind,
    skillId: skill.id,
    position: shooter.position,
    spawnStep: 0,
  ));
  match.tick(1 / 60);
  return match;
}

void _step(MatchSimulationController match, int count) {
  for (var i = 0; i < count; i++) {
    match.tick(1 / 60);
  }
}

SkillDefinition _volley({int count = 5, double spread = 60, double cooldown = 2}) =>
    SkillLibrary.defaults.create('Regression Volley', PowerUpKind.pistol).copyWith(
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
  test('full composed volley launches the configured number of shots', () {
    final match = _arena(_volley());
    final shooter = match.state.balls.first;
    shooter.aimLeft = 1;
    _step(match, 1);
    final shots = match.powerUps!.projectiles;
    expect(shots, hasLength(5));
    expect(shots.every((shot) => identical(shot.owner, shooter)), isTrue);
    final angles = shots.map((shot) => math.atan2(shot.velocity.dy, shot.velocity.dx)).toList();
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
