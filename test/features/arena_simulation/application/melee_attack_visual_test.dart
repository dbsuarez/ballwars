import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.red),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.blue),
];

MatchSimulationController _match({
  HeldAttackAnimation? animation,
  bool dualWield = false,
  int durationSteps = 30,
}) {
  final sword = SkillLibrary.defaults
      .builtIn(PowerUpKind.sword, PowerUpConfig.defaults)
      .copyWith(heldAttackAnimation: animation,
          heldAttackDurationSteps: durationSteps);
  final library = SkillLibrary.defaults.withDefinition(
    sword, PowerUpConfig.defaults);
  final c = MatchSimulationController(
    _balls,
    arenaRadius: 260,
    seed: 7,
    mode: MatchMode.arsenal,
    lookAhead: false,
    dualWield: dualWield,
    skillLibrary: library,
  );
  c.powerUps!.automaticSpawning = false;
  final [attacker, target] = c.state.balls;
  attacker.position = const Offset(-15, 0);
  target.position = const Offset(15, 0);
  attacker.velocity = Offset.zero;
  target.velocity = Offset.zero;
  attacker.equipWeapon(PowerUpKind.sword, dualWield: dualWield);
  return c;
}

void main() {
  test('Slash captures consumed sword for 30 visual steps without keeping it equipped', () {
    final c = _match(animation: HeldAttackAnimation.slash);
    final [attacker, target] = c.state.balls;
    c.powerUps!.onContact(attacker, target);
    expect(attacker.held, isNull);
    expect(attacker.equippedWeapons, isEmpty);
    expect(attacker.meleeAttackVisual?.kind, PowerUpKind.sword);
    expect(attacker.meleeAttackVisual?.slot, 0);
    expect(attacker.meleeAttackVisual?.stepsLeft, 30);
    final damage = target.life;
    c.powerUps!.onContact(attacker, target);
    expect(target.life, damage, reason: 'cosmetic swing must not hit twice');
    for (var i = 0; i < 29; i++) {
      c.powerUps!.step();
    }
    expect(attacker.meleeAttackVisual?.stepsLeft, 1);
    c.powerUps!.step();
    expect(attacker.meleeAttackVisual, isNull);
  });

  test('configured cosmetic duration expires without additional hits', () {
    final c = _match(animation: HeldAttackAnimation.slash, durationSteps: 60);
    final [attacker, target] = c.state.balls;
    c.powerUps!.onContact(attacker, target);
    expect(attacker.held, isNull);
    expect(attacker.meleeAttackVisual?.totalSteps, 60);
    expect(attacker.meleeAttackVisual?.stepsLeft, 60);
    final health = target.life;
    for (var i = 0; i < 59; i++) {
      c.powerUps!.step();
    }
    expect(target.life, health);
    expect(attacker.meleeAttackVisual?.stepsLeft, 1);
    c.powerUps!.step();
    expect(attacker.meleeAttackVisual, isNull);
  });

  test('legacy sword does not create a temporary attack sprite', () {
    final c = _match();
    final [attacker, target] = c.state.balls;
    c.powerUps!.onContact(attacker, target);
    expect(attacker.held, isNull);
    expect(attacker.meleeAttackVisual, isNull);
  });

  test('Thrust uses the same cosmetic lifecycle', () {
    final c = _match(animation: HeldAttackAnimation.thrust);
    final [attacker, target] = c.state.balls;
    c.powerUps!.onContact(attacker, target);
    expect(attacker.held, isNull);
    expect(attacker.meleeAttackVisual?.kind, PowerUpKind.sword);
  });

  test('secondary sword attack preserves original visual slot', () {
    final c = _match(animation: HeldAttackAnimation.slash, dualWield: true);
    final [attacker, target] = c.state.balls;
    attacker.held = null;
    attacker.heldSecondary = PowerUpKind.sword;
    c.powerUps!.onContact(attacker, target);
    expect(attacker.heldSecondary, isNull);
    expect(attacker.meleeAttackVisual?.slot, 1);
  });
}
