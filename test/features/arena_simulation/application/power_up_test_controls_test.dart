import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.red),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.blue),
];

MatchSimulationController _match() {
  final match = MatchSimulationController(
    _balls, arenaRadius: 200, seed: 42,
    mode: MatchMode.arsenal, lookAhead: false, slowMotionLines: 0,
  );
  match.powerUps!.automaticSpawning = false;
  match.state.balls[0].position = const Offset(-75, 0);
  match.state.balls[1].position = const Offset(75, 0);
  return match;
}

void main() {
  test('pinning one ball preserves its position while the other moves', () {
    final match = _match();
    final a = match.state.balls[0];
    final b = match.state.balls[1];
    final original = a.velocity;
    final startB = b.position;
    match.setTestBallPinned(a, true);
    for (var i = 0; i < 10; i++) {
      match.tick(MatchSimulationController.fixedTimestep);
    }
    expect(a.position, const Offset(-75, 0));
    expect(b.position, isNot(startB));
    match.setTestBallPinned(a, false);
    expect(a.velocity, original);
    match.tick(MatchSimulationController.fixedTimestep);
    expect(a.position, isNot(const Offset(-75, 0)));
  });

  test('both pinned balls still aim, fire, take damage and expire effects', () {
    final match = _match();
    final a = match.state.balls[0];
    final b = match.state.balls[1];
    a.speedLeft = 10;
    for (final ball in match.state.balls) {
      match.setTestBallPinned(ball, true);
    }
    final life = b.life;
    match.powerUps!.pickUp(a, FieldPowerUp(
      kind: PowerUpKind.pistol, position: a.position, spawnStep: 0,
    ));
    for (var i = 0; i < 180; i++) {
      match.tick(MatchSimulationController.fixedTimestep);
    }
    expect(a.position, const Offset(-75, 0));
    expect(b.position, const Offset(75, 0));
    expect(b.life, lessThan(life));
    expect(a.speedLeft, 0);
    expect(match.powerUps!.field, isEmpty);
  });

  test('selected traps can be spawned before the random spawn delay', () {
    final match = _match();
    match.powerUps!.spawnTestItem(PowerUpKind.portal);
    expect(match.powerUps!.portals, hasLength(1));
    expect(match.stepCount, 0);
  });
  test('tornado DoT hurts without marking the target as burning', () {
    final match = _match();
    final target = match.state.balls[1];
    match.powerUps!.damageOverTime.add(DamageOverTime(
      target: target, kind: PowerUpKind.tornado,
      owner: match.state.balls[0], stepsLeft: PowerUpTuning.damageOverTimeSteps,
    ));
    final life = target.life;
    match.tick(MatchSimulationController.fixedTimestep);
    expect(target.life, lessThan(life));
    expect(target.burningLeft, 0);
    expect(target.poisonLeft, 0);
  });

  test('fire DoT retains the burning visual', () {
    final match = _match();
    final target = match.state.balls[1];
    match.powerUps!.damageOverTime.add(DamageOverTime(
      target: target, kind: PowerUpKind.fireWall,
      owner: match.state.balls[0], stepsLeft: PowerUpTuning.damageOverTimeSteps,
    ));
    match.tick(MatchSimulationController.fixedTimestep);
    expect(target.burningLeft, greaterThan(0));
  });

  test('swap cannon exchanges positions and emits teleport endpoints', () {
    final match = _match();
    final a = match.state.balls[0];
    final b = match.state.balls[1];
    a.velocity = Offset.zero;
    b.velocity = Offset.zero;
    final from = a.position;
    final to = b.position;
    match.powerUps!.projectiles.add(Projectile(
      owner: a, kind: PowerUpKind.swapCannon,
      position: b.position - Offset(b.radius, 0),
      velocity: const Offset(100, 0),
    ));
    match.tick(MatchSimulationController.fixedTimestep);
    expect(a.position, to);
    expect(b.position, from);
    expect(match.powerUps!.portalFlashes, isNotEmpty);
    expect(match.powerUps!.portalFlashes.last.from, from);
    expect(match.powerUps!.portalFlashes.last.to, to);
  });

}
