import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _arenaRadius = 260.0;
const _life = PowerUpTuning.arenaLife;

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
  CustomBall(id: 'c', name: 'C', primaryColor: Colors.green, glowColor: Colors.lime),
];

/// A match with [count] balls held still. Arsenal: the first two at (-100, 0) and (100, 0). All-Out: on
/// their own side of the rim, ball 0 (owning the right half) at (100, 0) and ball 1 at (-100, 0). A third
/// ball sits at (0, 180).
MatchSimulationController _match({MatchMode mode = MatchMode.arsenal, int count = 2, int seed = 1}) {
  final c = MatchSimulationController(
    _balls.take(count).toList(),
    arenaRadius: _arenaRadius,
    seed: seed,
    layoutRotation: 0,
    mode: mode,
    lookAhead: false,
  );
  final balls = c.state.balls;
  for (final b in balls) {
    b.velocity = Offset.zero;
  }
  final side = mode == MatchMode.arsenal ? -1.0 : 1.0;
  balls[0].position = Offset(100 * side, 0);
  balls[1].position = Offset(-100 * side, 0);
  if (count > 2) balls[2].position = const Offset(0, 180);
  return c;
}

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.tick(1 / 60);
  }
}

/// Puts a power-up of [kind] under [ball] and runs one step, so the ball picks it up.
void _give(MatchSimulationController c, SimulationBall ball, PowerUpKind kind) {
  c.powerUps!.field.add(FieldPowerUp(kind: kind, position: ball.position, spawnStep: 0));
  _run(c, 1);
}

/// Sends [a] and [b] at each other from just apart, and runs until they bump (at most 30 steps).
void _bump(MatchSimulationController c, SimulationBall a, SimulationBall b) {
  final gap = a.radius + b.radius + 4;
  a
    ..position = Offset(-gap / 2, 0)
    ..velocity = const Offset(60, 0);
  b
    ..position = Offset(gap / 2, 0)
    ..velocity = const Offset(-60, 0);
  final before = c.ballHits;
  for (var i = 0; i < 30 && c.ballHits == before; i++) {
    _run(c, 1);
  }
  expect(c.ballHits, before + 1, reason: 'the balls never bumped');
}

/// A bullet from [owner] about to strike [target] from the left.
Projectile _bulletAt(SimulationBall owner, SimulationBall target, {PowerUpKind kind = PowerUpKind.pistol}) =>
    Projectile(
      owner: owner,
      kind: kind,
      position: target.position - Offset(target.radius + 5, 0),
      velocity: const Offset(_arenaRadius * PowerUpTuning.bulletSpeedRatio, 0),
    );

void main() {
  test('a knife damages on contact and is used up', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.knife;
    _bump(c, a, b);
    expect(b.life, _life - PowerUpTuning.arenaDamage[PowerUpKind.knife]!);
    expect(a.life, _life);
    expect(a.held, isNull);
    expect(c.powerUps!.slashes, 1);
    final blood = c.state.particles.particles.whereType<Particle>().where((p) => p.color == b.config.primaryColor);
    expect(blood, isNotEmpty);
  });

  test('a shield blocks 75% of the next hit, then breaks', () {
    final c = _match();
    final [a, b] = c.state.balls;
    b.held = PowerUpKind.shield;
    final bullet = _bulletAt(a, b);
    c.powerUps!.projectiles.add(bullet);
    _run(c, 1);
    expect(bullet.spent, isTrue);
    expect(
      b.life,
      closeTo(_life - PowerUpTuning.arenaDamage[PowerUpKind.pistol]! * (1 - PowerUpTuning.shieldBlock), 1e-9),
    );
    expect(b.held, isNull);
    expect(c.powerUps!.blocks, 1);

    // The next hit lands in full.
    final second = _bulletAt(a, b);
    c.powerUps!.projectiles.add(second);
    _run(c, 1);
    expect(
      b.life,
      closeTo(_life - PowerUpTuning.arenaDamage[PowerUpKind.pistol]! * (2 - PowerUpTuning.shieldBlock), 1e-9),
    );
  });

  test('a shield also blocks a knife, and the knife is still used up', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.knife;
    b.held = PowerUpKind.shield;
    _bump(c, a, b);
    expect(
      b.life,
      closeTo(_life - PowerUpTuning.arenaDamage[PowerUpKind.knife]! * (1 - PowerUpTuning.shieldBlock), 1e-9),
    );
    // A was armed, so B's shield blocked instead of bashing.
    expect(a.life, _life);
    expect(a.held, isNull);
    expect(b.held, isNull);
  });

  test('a shield bashes an unarmed opponent and breaks', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.shield;
    _bump(c, a, b);
    expect(b.life, _life - PowerUpTuning.arenaShieldBash);
    expect(a.life, _life);
    expect(a.held, isNull);

    // Against an armed opponent there is no bash.
    final d = _match();
    final [x, y] = d.state.balls;
    x.held = PowerUpKind.shield;
    y.held = PowerUpKind.pistol;
    _bump(d, x, y);
    expect(y.life, _life);
    expect(x.held, PowerUpKind.shield);
  });

  test('the shield turns toward an incoming bullet, else the nearest opponent', () {
    final c = _match(count: 3);
    final [a, b, other] = c.state.balls;
    a
      ..position = const Offset(0, 60)
      ..held = PowerUpKind.shield;
    _run(c, 60);
    final toB = b.position - a.position;
    expect(a.shieldAngle, closeTo(math.atan2(toB.dy, toB.dx), 1e-6));

    // A bullet from C coming up from below: the shield swings round to face it.
    c.powerUps!.projectiles.add(
      Projectile(
        owner: other,
        kind: PowerUpKind.pistol,
        position: a.position + const Offset(0, 150),
        velocity: const Offset(0, -30),
      ),
    );
    _run(c, 30);
    final bullet = c.powerUps!.projectiles.single;
    final toBullet = bullet.position - a.position;
    expect(a.shieldAngle, closeTo(math.atan2(toBullet.dy, toBullet.dx), 1e-6));
  });

  test('any pickup drops the held power-up, timed and instant kinds included (arming a bomb does not)', () {
    for (final kind in [
      PowerUpKind.apple,
      PowerUpKind.speed,
      PowerUpKind.ghost,
      PowerUpKind.magnet,
      PowerUpKind.shield,
    ]) {
      final c = _match();
      final a = c.state.balls.first;
      a
        ..held = PowerUpKind.knife
        ..life = _life / 2;
      _give(c, a, kind);
      expect(a.held, kind == PowerUpKind.shield ? PowerUpKind.shield : isNull, reason: kind.label);
      if (kind == PowerUpKind.apple) expect(a.life, _life / 2 + PowerUpTuning.arenaAppleHeal);
    }
  });

  test('in All-Out a shield halves the threads lost to the next hit', () {
    final c = _match(mode: MatchMode.allOut);
    final [a, b] = c.state.balls;
    b.held = PowerUpKind.shield;
    final before = b.fanLines.length;
    final bullet = _bulletAt(a, b);
    c.powerUps!.projectiles.add(bullet);
    _run(c, 1);
    expect(bullet.spent, isTrue);
    expect(
      b.fanLines.length,
      before - (PowerUpTuning.allOutThreads[PowerUpKind.pistol]! * PowerUpTuning.allOutShieldKeep).round(),
    );
    expect(b.held, isNull);
  });

  test('apple heals 25 in Arsenal, past full life up to the max', () {
    final c = _match();
    final a = c.state.balls.first;
    _give(c, a, PowerUpKind.apple);
    expect(a.life, _life + PowerUpTuning.arenaAppleHeal);
    expect(a.held, isNull);
    a.life = PowerUpTuning.arenaMaxLife - 5;
    _give(c, a, PowerUpKind.apple);
    expect(a.life, PowerUpTuning.arenaMaxLife);

    a.life = _life / 2;
    _give(c, a, PowerUpKind.apple);
    expect(a.life, _life / 2 + PowerUpTuning.arenaAppleHeal);

    // A green sparkle burst.
    final sparkles = c.state.particles.particles.whereType<Particle>().where(
      (p) => p.color == ParticleSystem.sparkleColor,
    );
    expect(sparkles, isNotEmpty);
  });

  test('apple in All-Out claims free rim slots, and gives 0 when none are free', () {
    final c = _match(mode: MatchMode.allOut);
    final [a, b] = c.state.balls;

    // Every slot is owned at the start: the apple does nothing.
    expect(c.freeSlotCount, 0);
    final start = a.fanLines.length;
    _give(c, a, PowerUpKind.apple);
    expect(a.fanLines.length, start);
    expect(c.freeSlotCount, 0);

    // With free slots it claims allOutAppleSlots of them and shows "+N LINES".
    // Free them near the bottom of the rim, where none of the new lines runs through b.
    c.cutThreads(b, 30, near: const Offset(0, _arenaRadius));
    expect(c.freeSlotCount, 30);
    _give(c, a, PowerUpKind.apple);
    expect(a.fanLines.length, start + PowerUpTuning.allOutAppleSlots);
    expect(a.lineCount, a.fanLines.length);
    expect(c.freeSlotCount, 30 - PowerUpTuning.allOutAppleSlots);
    expect(c.state.floatingTexts.items.where((t) => t.text == '+${PowerUpTuning.allOutAppleSlots} LINES'), isNotEmpty);
    // Every claimed slot is a distinct one.
    expect(
      {
        for (final l in [...a.fanLines, ...b.fanLines]) l.slotIndex,
      }.length,
      a.fanLines.length + b.fanLines.length,
    );
  });

  test('speed boost doubles speed for 180 steps', () {
    final c = _match();
    final a = c.state.balls.first;
    a.position = const Offset(-100, -100);
    _give(c, a, PowerUpKind.speed);
    a.velocity = const Offset(0, 30);
    expect(a.speedLeft, PowerUpTuning.speedSteps);
    for (var i = 0; i < PowerUpTuning.speedSteps; i++) {
      final before = a.position;
      _run(c, 1);
      expect(a.position.dy - before.dy, closeTo(30 / 60 * PowerUpTuning.speedFactor, 1e-9), reason: 'step $i');
    }
    expect(a.speedLeft, 0);
    final before = a.position;
    _run(c, 1);
    expect(a.position.dy - before.dy, closeTo(30 / 60, 1e-9));
    expect(a.velocity, const Offset(0, 30));
  });

  test('ghost passes through balls, cannot be hit and in All-Out neither loses nor cuts threads for 180 steps', () {
    // Arsenal: no bounce, no damage from bullets, knives or bombs.
    final c = _match();
    final [a, b] = c.state.balls;
    _give(c, a, PowerUpKind.ghost);
    expect(a.ghostLeft, PowerUpTuning.ghostSteps);
    b.held = PowerUpKind.knife;
    a
      ..position = Offset.zero
      ..velocity = const Offset(30, 0);
    b
      ..position = const Offset(20, 0)
      ..velocity = const Offset(-30, 0);
    _run(c, 1);
    expect(c.ballHits, 0);
    expect(a.velocity, const Offset(30, 0));
    expect(b.velocity, const Offset(-30, 0));
    expect(a.life, _life);
    expect(b.held, PowerUpKind.knife);

    final bullet = _bulletAt(b, a);
    c.powerUps!.projectiles.add(bullet);
    c.powerUps!.bombs.add(ArmedBomb(owner: b, position: a.position, armedStep: 0));
    _run(c, 1);
    expect(bullet.spent, isFalse);
    expect(a.life, _life);

    var ghostSteps = 2;
    while (a.isGhost) {
      _run(c, 1);
      ghostSteps++;
    }
    expect(ghostSteps, PowerUpTuning.ghostSteps);

    // All-Out: a ghost sitting across the opponent's threads, with the opponent across its own.
    final d = _match(mode: MatchMode.allOut);
    final [g, o] = d.state.balls;
    _give(d, g, PowerUpKind.ghost);
    g.position = const Offset(-150, 0);
    o.position = const Offset(150, 0);
    final gLines = g.fanLines.length;
    final oLines = o.fanLines.length;
    _run(d, 1);
    expect(g.fanLines.length, gLines);
    expect(o.fanLines.length, oLines);

    // A bullet through its threads cuts none of them.
    d.powerUps!.projectiles.add(
      Projectile(
        owner: o,
        kind: PowerUpKind.pistol,
        position: const Offset(200, -120),
        velocity: const Offset(0, _arenaRadius * PowerUpTuning.bulletSpeedRatio),
      ),
    );
    _run(d, 30);
    expect(g.fanLines.length, gLines);

    // Once the ghost wears off, the bodies cut again.
    _run(d, PowerUpTuning.ghostSteps);
    expect(g.isGhost, isFalse);
    expect(g.fanLines.length + o.fanLines.length, lessThan(gLines + oLines));
  });

  test('a bomb is armed where it lies by the first ball to touch it, and only an opponent sets it off', () {
    final c = _match(count: 3);
    final [a, b, other] = c.state.balls;
    a
      ..position = const Offset(-100, 0)
      ..held = PowerUpKind.knife;
    b.position = const Offset(-100 + 60, 0);
    final field = c.powerUps!.field;
    _give(c, a, PowerUpKind.bomb);
    // Arming doesn't cost the held power-up, and the armed bomb leaves the field (no limit slot).
    expect(a.held, PowerUpKind.knife);
    expect(field, isEmpty);
    final bomb = c.powerUps!.bombs.single;
    expect(bomb.owner, a);
    expect(bomb.position, a.position);

    // Its owner sitting on it never sets it off.
    _run(c, 120);
    expect(c.powerUps!.blasts, 0);
    expect(a.life, _life);

    // An opponent touching it does, at once; the owner is spared even in range.
    b.position = bomb.position + const Offset(10, 0);
    a.position = bomb.position - const Offset(40, 0);
    _run(c, 1);
    expect(c.powerUps!.blasts, 1);
    expect(c.powerUps!.bombs, isEmpty);
    // 3 balls: crowded Arsenal damage is x2.25 (never below 0).
    expect(b.life, math.max(0.0, _life - PowerUpTuning.arenaDamage[PowerUpKind.bomb]! * 2.25));
    expect(a.life, _life);
    expect(other.life, _life);
    expect(c.state.floatingTexts.items.map((t) => t.text), contains('KABOOM!'));
  });

  test('a bomb whose owner is out is gone', () {
    final c = _match(count: 3);
    final [a, b, _] = c.state.balls;
    c.powerUps!.bombs.add(ArmedBomb(owner: a, position: const Offset(0, -150), armedStep: 0));
    a.isEliminated = true;
    _run(c, 1);
    expect(c.powerUps!.bombs, isEmpty);
    b.position = const Offset(0, -150);
    _run(c, 1);
    expect(c.powerUps!.blasts, 0);
  });

  test('two balls shooting each other out in one step still leave a winner', () {
    final shot = PowerUpTuning.arenaDamage[PowerUpKind.pistol]!;
    // Unequal life before the hits: the one with more life at the start of the step survives, with 1.
    final c = _match();
    final [a, b] = c.state.balls;
    a
      ..position = const Offset(-40, 0)
      ..life = shot - 10;
    b
      ..position = const Offset(40, 0)
      ..life = shot - 5;
    c.powerUps!.projectiles
      ..add(_bulletAt(b, a))
      ..add(_bulletAt(a, b));
    _run(c, 1);
    expect(c.state.status, MatchStatus.finished);
    expect(c.state.winnerId, b.config.id);
    expect(b.isEliminated, isFalse);
    expect(b.life, 1);
    expect(a.isEliminated, isTrue);
    expect(c.lastEliminatedId, a.config.id);

    // Equal life: a seeded coin flip still names a winner.
    for (var seed = 1; seed <= 6; seed++) {
      final d = _match(seed: seed);
      final [x, y] = d.state.balls;
      x
        ..position = const Offset(-40, 0)
        ..life = shot;
      y
        ..position = const Offset(40, 0)
        ..life = shot;
      d.powerUps!.projectiles
        ..add(_bulletAt(y, x))
        ..add(_bulletAt(x, y));
      _run(d, 1);
      expect(d.state.status, MatchStatus.finished);
      expect(d.state.winnerId, isNotNull);
      expect(d.state.balls.where((ball) => !ball.isEliminated).single.life, 1);
    }
  });

  test('magnet pulls the nearest power-up at once, or the next spawn when the field is empty', () {
    final c = _match();
    final a = c.state.balls.first;
    final powerUps = c.powerUps!;
    powerUps.field
      ..add(FieldPowerUp(kind: PowerUpKind.knife, position: const Offset(0, 150), spawnStep: 0))
      ..add(FieldPowerUp(kind: PowerUpKind.pistol, position: const Offset(0, -200), spawnStep: 0));
    _give(c, a, PowerUpKind.magnet);
    final knife = powerUps.field.firstWhere((p) => p.kind == PowerUpKind.knife);
    expect(knife.position, a.position);
    expect(powerUps.field.firstWhere((p) => p.kind == PowerUpKind.pistol).position, const Offset(0, -200));
    expect(a.magnetPending, isFalse);
    _run(c, 1);
    expect(a.held, PowerUpKind.knife);

    // Empty field: it waits for the next spawn.
    final d = _match();
    final x = d.state.balls.first;
    _give(d, x, PowerUpKind.magnet);
    expect(d.powerUps!.field, isEmpty);
    expect(x.magnetPending, isTrue);
    while (d.powerUps!.field.isEmpty && d.stepCount < PowerUpTuning.spawnIntervalSteps * 2) {
      _run(d, 1);
    }
    expect(d.powerUps!.field.single.position, x.position);
    expect(x.magnetPending, isFalse);
  });

  test('a magnet whose ball is eliminated does nothing', () {
    final c = _match(count: 3);
    final a = c.state.balls.first;
    a.magnetPending = true;
    a.isEliminated = true;
    while (c.powerUps!.field.isEmpty && c.stepCount < PowerUpTuning.spawnIntervalSteps * 2) {
      _run(c, 1);
    }
    expect(c.powerUps!.field.single.position, isNot(a.position));
    expect(a.magnetPending, isFalse);
  });

  test('a ball with no life or threads left this step neither fires nor is aimed at', () {
    // Arsenal: A is at 0 life but not yet marked out.
    final c = _match(count: 3);
    final [a, b, other] = c.state.balls;
    a
      ..life = 0
      ..held = PowerUpKind.pistol
      ..aimLeft = 1;
    b
      ..held = PowerUpKind.pistol
      ..aimLeft = 1;
    _run(c, 1);
    final shots = c.powerUps!.projectiles;
    expect(shots.length, 1);
    expect(shots.single.owner, same(b));
    final toOther = other.position - b.position;
    expect(
      math.atan2(shots.single.velocity.dy, shots.single.velocity.dx),
      closeTo(math.atan2(toOther.dy, toOther.dx), 1e-9),
    );

    // All-Out: A has no threads left.
    final d = _match(mode: MatchMode.allOut, count: 3);
    final [x, y, z] = d.state.balls;
    d.cutThreads(x, x.fanLines.length);
    x
      ..held = PowerUpKind.pistol
      ..aimLeft = 1;
    y
      ..held = PowerUpKind.pistol
      ..aimLeft = 1;
    _run(d, 1);
    final shot = d.powerUps!.projectiles.single;
    expect(shot.owner, same(y));
    final toZ = z.position - y.position;
    expect(math.atan2(shot.velocity.dy, shot.velocity.dx), closeTo(math.atan2(toZ.dy, toZ.dx), 1e-9));
  });

  test('a shield softens a whole volley: every pellet of one shotgun blast is blocked the same way', () {
    final c = _match();
    final a = c.state.balls[0];
    final b = c.state.balls[1];
    b.held = PowerUpKind.shield;
    // Three pellets of one blast, all hitting B in the same step.
    for (final dy in [-6.0, 0.0, 6.0]) {
      c.powerUps!.projectiles.add(Projectile(
        owner: a,
        kind: PowerUpKind.shotgun,
        position: b.position + Offset(-b.radius - 2, dy),
        velocity: const Offset(600, 0),
        volley: 7,
      ));
    }
    _run(c, 1);
    final pellet = PowerUpTuning.arenaDamage[PowerUpKind.shotgun]!;
    expect(b.life, closeTo(_life - 3 * pellet * (1 - PowerUpTuning.shieldBlock), 1e-9));
    expect(b.held, isNull);
  });

  test('a ghost holding a gun does not aim or fire until the ghost wears off', () {
    final c = _match();
    final a = c.state.balls[0];
    a
      ..held = PowerUpKind.pistol
      ..ghostLeft = PowerUpTuning.aimSteps + 30;
    _run(c, PowerUpTuning.aimSteps + 20);
    expect(c.powerUps!.shots, 0);
    expect(a.held, PowerUpKind.pistol);
    _run(c, 10 + PowerUpTuning.aimSteps + 2);
    expect(c.powerUps!.shots, 1);
  });
}
