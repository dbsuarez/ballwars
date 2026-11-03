
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  simultaneousContactRegressionTests();
  persistentThreeTargetRegressionTests();
  reflectedThirdTargetRegressionTests();
  previousHitHistoryRegressionTests();
  for (final reverse in [false, true]) {
    test('returning boomerang crosses two targets in one step, reverse=$reverse', () {
      const owner = CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink);
      const a = CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime);
      const b = CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan);
      final match = MatchSimulationController(
        reverse ? [owner, b, a] : [owner, a, b],
        arenaRadius: 260, seed: 2323, mode: MatchMode.arsenal, lookAhead: false,
      );
      match.powerUps!.automaticSpawning = false;
      for (final ball in match.state.balls) {
        ball.position = switch (ball.config.id) {
          'owner' => const Offset(-220, 0),
          'a' => const Offset(-90, 0),
          _ => const Offset(10, 0),
        };
        ball.velocity = Offset.zero;
      }
      final attacker = match.state.balls.firstWhere((ball) => ball.config.id == 'owner');
      final first = match.state.balls.firstWhere((ball) => ball.config.id == 'a');
      final second = match.state.balls.firstWhere((ball) => ball.config.id == 'b');
      final firstLife = first.life;
      final secondLife = second.life;
      final shot = Projectile(
        owner: attacker, kind: PowerUpKind.boomerang,
        position: const Offset(-180, 0), velocity: const Offset(18000, 0),
      );
      match.powerUps!.projectiles.add(shot);
      match.powerUps!.step();
      expect(first.life, lessThan(firstLife));
      expect(second.life, lessThan(secondLife));
      expect(shot.hitTargets, containsAll([first, second]));
    });
  }

  test('second same-step contact reflects and transfers ownership', () {
    const owner = CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink);
    const a = CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime);
    const b = CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan);
    final match = MatchSimulationController([owner, a, b],
      arenaRadius: 260, seed: 2425, mode: MatchMode.arsenal,
      lookAhead: false);
    match.powerUps!.automaticSpawning = false;
    for (final ball in match.state.balls) {
      ball.position = switch (ball.config.id) {
        'owner' => const Offset(-220, 0),
        'a' => const Offset(-90, 0),
        _ => const Offset(10, 0),
      };
      ball.velocity = Offset.zero;
    }
    final attacker = match.state.balls[0];
    final first = match.state.balls[1];
    final defender = match.state.balls[2];
    defender.mirrorCharges = 1;
    final initialLife = first.life;
    final defenderLife = defender.life;
    final shot = Projectile(owner: attacker, kind: PowerUpKind.boomerang,
      position: const Offset(-180, 0), velocity: const Offset(18000, 0));
    match.powerUps!.projectiles.add(shot);
    match.powerUps!.step();
    expect(first.life, lessThan(initialLife));
    expect(defender.life, defenderLife);
    expect(defender.mirrorCharges, 0);
    expect(shot.owner, same(defender));
    expect(shot.velocity.dx, lessThan(0));
    expect(shot.hitTargets, contains(defender));
  });

  test('second target magnetic field intercepts at expanded radius', () {
    const owner = CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink);
    const a = CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime);
    const b = CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan);
    final match = MatchSimulationController([owner, a, b],
      arenaRadius: 260, seed: 2426, mode: MatchMode.arsenal,
      lookAhead: false);
    match.powerUps!.automaticSpawning = false;
    final attacker = match.state.balls[0];
    final first = match.state.balls[1];
    final defender = match.state.balls[2];
    attacker.position = const Offset(-220, 0);
    first.position = const Offset(-90, 0);
    defender.position = const Offset(10, 20);
    for (final ball in match.state.balls) {
      ball.velocity = Offset.zero;
      ball.radius = 12;
    }
    defender.magneticFieldLeft = 100;
    final initialLife = first.life;
    final defenderLife = defender.life;
    final shot = Projectile(owner: attacker, kind: PowerUpKind.boomerang,
      position: const Offset(-180, 0), velocity: const Offset(18000, 0));
    match.powerUps!.projectiles.add(shot);
    match.powerUps!.step();
    expect(first.life, lessThan(initialLife));
    expect(defender.life, defenderLife);
    expect(shot.owner, same(defender));
    expect(shot.hitTargets, contains(defender));
  });

  for (final obstacle in [CenterObstacle.circle, CenterObstacle.square]) {
    test('returning projectile cannot damage a second target behind $obstacle', () {
      const owner = CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink);
      const a = CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime);
      const b = CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan);
      final match = MatchSimulationController([owner, a, b],
        arenaRadius: 260, seed: 2324, mode: MatchMode.arsenal,
        lookAhead: false, centerObstacle: obstacle);
      match.powerUps!.automaticSpawning = false;
      for (final ball in match.state.balls) {
        ball.position = switch (ball.config.id) {
          'owner' => const Offset(-220, 0),
          'a' => const Offset(-135, 0),
          _ => const Offset(135, 0),
        };
        ball.velocity = Offset.zero;
      }
      final attacker = match.state.balls.first;
      final first = match.state.balls[1];
      final second = match.state.balls[2];
      final firstLife = first.life;
      final secondLife = second.life;
      final shot = Projectile(owner: attacker, kind: PowerUpKind.boomerang,
        position: const Offset(-180, 0), velocity: const Offset(18000, 0));
      match.powerUps!.projectiles.add(shot);
      match.powerUps!.step();
      expect(first.life, lessThan(firstLife));
      expect(second.life, secondLife);
      expect(shot.wallBounces, 1);
      expect(shot.velocity.dx, lessThan(0));
    });
  }
}

// The test below is intentionally separate from the normal first-contact
// reflection cases: the defender is the SECOND contact in a single tick.


// Extra regression coverage for ordered multi-contact sweeps. These cases
// deliberately use one fixed-timestep movement that crosses all defenders.
void persistentThreeTargetRegressionTests() {
  for (final reversed in [false, true]) {
    test('three same-step contacts are order independent, reverse=$reversed', () {
      const owner = CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink);
      const a = CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime);
      const b = CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan);
      const c = CustomBall(id: 'c', name: 'C', primaryColor: Colors.orange, glowColor: Colors.yellow);
      final match = MatchSimulationController(
        reversed ? [owner, c, b, a] : [owner, a, b, c],
        arenaRadius: 300, seed: 2727, mode: MatchMode.arsenal,
        lookAhead: false,
      );
      match.powerUps!.automaticSpawning = false;
      final balls = {for (final ball in match.state.balls) ball.config.id: ball};
      for (final entry in balls.entries) {
        entry.value.position = Offset(switch (entry.key) {
          'owner' => -250,
          'a' => -130,
          'b' => -30,
          _ => 70,
        }, 0);
        entry.value.velocity = Offset.zero;
      }
      final targets = [balls['a']!, balls['b']!, balls['c']!];
      final before = targets.map((ball) => ball.life).toList();
      final shot = Projectile(owner: balls['owner']!,
          kind: PowerUpKind.boomerang,
          position: const Offset(-200, 0),
          velocity: const Offset(24000, 0));
      match.powerUps!.projectiles.add(shot);
      match.powerUps!.step();
      for (var i = 0; i < targets.length; i++) {
        expect(targets[i].life, lessThan(before[i]),
            reason: 'Target ${targets[i].config.id} should be hit once');
        expect(shot.hitTargets, contains(targets[i]));
      }
    });
  }
}

// A reflected second contact must terminate the original outgoing sweep.
// A third target behind the reflector cannot be damaged in the same tick.
void reflectedThirdTargetRegressionTests() {
  for (final reversed in [false, true]) {
    test('second-contact mirror blocks third target, reverse=$reversed', () {
      const owner = CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink);
      const a = CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime);
      const b = CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan);
      const c = CustomBall(id: 'c', name: 'C', primaryColor: Colors.orange, glowColor: Colors.yellow);
      final match = MatchSimulationController(
        reversed ? [owner, c, b, a] : [owner, a, b, c],
        arenaRadius: 300, seed: 2828, mode: MatchMode.arsenal,
        lookAhead: false,
      );
      match.powerUps!.automaticSpawning = false;
      final balls = {for (final ball in match.state.balls) ball.config.id: ball};
      for (final entry in balls.entries) {
        entry.value.position = Offset(switch (entry.key) {
          'owner' => -250,
          'a' => -130,
          'b' => -30,
          _ => 70,
        }, 0);
        entry.value.velocity = Offset.zero;
      }
      final first = balls['a']!;
      final reflector = balls['b']!;
      final behind = balls['c']!;
      reflector.mirrorCharges = 1;
      final firstLife = first.life;
      final reflectorLife = reflector.life;
      final behindLife = behind.life;
      final shot = Projectile(owner: balls['owner']!,
          kind: PowerUpKind.boomerang,
          position: const Offset(-200, 0),
          velocity: const Offset(24000, 0));
      match.powerUps!.projectiles.add(shot);
      match.powerUps!.step();
      expect(first.life, lessThan(firstLife));
      expect(reflector.life, reflectorLife);
      expect(behind.life, behindLife);
      expect(shot.owner, same(reflector));
      expect(shot.hitTargets, isNot(contains(behind)));
    });
  }
}

void previousHitHistoryRegressionTests() {
  test('previously contacted target is skipped while later targets are hit', () {
    const owner = CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink);
    const a = CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime);
    const b = CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan);
    const c = CustomBall(id: 'c', name: 'C', primaryColor: Colors.orange, glowColor: Colors.yellow);
    final match = MatchSimulationController([owner, a, b, c],
      arenaRadius: 300, seed: 2829, mode: MatchMode.arsenal,
      lookAhead: false);
    match.powerUps!.automaticSpawning = false;
    final balls = {for (final ball in match.state.balls) ball.config.id: ball};
    for (final entry in balls.entries) {
      entry.value.position = Offset(switch (entry.key) {
        'owner' => -250,
        'a' => -130,
        'b' => -30,
        _ => 70,
      }, 0);
      entry.value.velocity = Offset.zero;
    }
    final skipped = balls['a']!;
    final second = balls['b']!;
    final third = balls['c']!;
    final beforeSkipped = skipped.life;
    final beforeSecond = second.life;
    final beforeThird = third.life;
    final shot = Projectile(owner: balls['owner']!,
      kind: PowerUpKind.boomerang,
      position: const Offset(-200, 0),
      velocity: const Offset(24000, 0));
    shot.hitTargets.add(skipped);
    match.powerUps!.projectiles.add(shot);
    match.powerUps!.step();
    expect(skipped.life, beforeSkipped);
    expect(second.life, lessThan(beforeSecond));
    expect(third.life, lessThan(beforeThird));
  });
}

// A swept projectile can enter two overlapping defenders at precisely the
// same fraction of a frame. Both must be considered, in either list order.
void simultaneousContactRegressionTests() {
  for (final reversed in [false, true]) {
    test('equal-time overlapping contacts, reverse=$reversed', () {
      const owner = CustomBall(id: 'owner', name: 'Owner',
          primaryColor: Colors.red, glowColor: Colors.pink);
      const a = CustomBall(id: 'a', name: 'A',
          primaryColor: Colors.green, glowColor: Colors.lime);
      const b = CustomBall(id: 'b', name: 'B',
          primaryColor: Colors.blue, glowColor: Colors.cyan);
      final match = MatchSimulationController(
        reversed ? [owner, b, a] : [owner, a, b],
        arenaRadius: 260, seed: 2929, mode: MatchMode.arsenal,
        lookAhead: false,
      );
      match.powerUps!.automaticSpawning = false;
      final balls = {for (final ball in match.state.balls) ball.config.id: ball};
      balls['owner']!.position = const Offset(-220, 0);
      balls['a']!.position = const Offset(-60, 0);
      balls['b']!.position = const Offset(-60, 0);
      for (final ball in match.state.balls) {
        ball.velocity = Offset.zero;
      }
      final beforeA = balls['a']!.life;
      final beforeB = balls['b']!.life;
      final shot = Projectile(owner: balls['owner']!,
        kind: PowerUpKind.boomerang,
        position: const Offset(-180, 0),
        velocity: const Offset(18000, 0));
      match.powerUps!.projectiles.add(shot);
      match.powerUps!.step();
      expect(balls['a']!.life, lessThan(beforeA));
      expect(balls['b']!.life, lessThan(beforeB));
      expect(shot.hitTargets, containsAll([balls['a'], balls['b']]));
    });
  }
}
