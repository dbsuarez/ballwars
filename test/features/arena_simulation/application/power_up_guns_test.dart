import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/application/power_up_system.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _arenaRadius = 260.0;

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

/// A match with [count] balls held still, the first two at (-100, 0) and (100, 0).
MatchSimulationController _match({
  MatchMode mode = MatchMode.arsenal,
  int count = 2,
}) {
  final c = MatchSimulationController(
    _balls.take(count).toList(),
    arenaRadius: _arenaRadius,
    seed: 1,
    layoutRotation: 0,
    mode: mode,
    lookAhead: false,
  );
  final balls = c.state.balls;
  for (final b in balls) {
    b.velocity = Offset.zero;
  }
  balls[0].position = const Offset(-100, 0);
  balls[1].position = const Offset(100, 0);
  if (count > 2) balls[2].position = const Offset(0, 180);
  return c;
}

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.tick(1 / 60);
  }
}

double _heading(Projectile p) => math.atan2(p.velocity.dy, p.velocity.dx);

double _bulletSpeed() => _arenaRadius * PowerUpTuning.bulletSpeedRatio;

/// Runs until [p] is spent (at most [limit] steps).
void _runUntilSpent(
  MatchSimulationController c,
  Projectile p, {
  int limit = 200,
}) {
  for (var i = 0; i < limit && !p.spent; i++) {
    c.tick(1 / 60);
  }
}

bool _segmentsCross(Offset p1, Offset p2, Offset q1, Offset q2) {
  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final d1 = cross(q1, q2, p1);
  final d2 = cross(q1, q2, p2);
  final d3 = cross(p1, p2, q1);
  final d4 = cross(p1, p2, q2);
  return d1 * d2 < 0 && d3 * d4 < 0;
}

void main() {
  test(
    'a pistol aims for aimSteps steps then fires one bullet at the nearest opponent',
    () {
      final c = _match(count: 3);
      final [a, b, _] = c.state.balls;
      a.held = PowerUpKind.pistol;
      _run(c, PowerUpTuning.aimSteps - 1);
      expect(c.powerUps!.projectiles, isEmpty);
      expect(a.aimTarget, same(b));
      _run(c, 1);
      final shots = c.powerUps!.projectiles;
      expect(shots.length, 1);
      expect(c.powerUps!.shots, 1);
      final toTarget = b.position - a.position;
      expect(
        _heading(shots.single),
        closeTo(math.atan2(toTarget.dy, toTarget.dx), 0.05),
      );
      expect(a.held, PowerUpKind.pistol);
      _run(c, PowerUpSystem.firedWeaponHoldSteps);
      expect(a.held, isNull);
    },
  );

  test('a shotgun fires 10 pellets fanned over the spread', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.shotgun;
    _run(c, PowerUpTuning.aimSteps);
    final pellets = c.powerUps!.projectiles;
    expect(pellets.length, PowerUpTuning.shotgunPellets);
    final toTarget = b.position - a.position;
    final aim = math.atan2(toTarget.dy, toTarget.dx);
    final headings = [for (final p in pellets) _heading(p) - aim];
    expect(
      headings.reduce(math.max) - headings.reduce(math.min),
      closeTo(PowerUpTuning.shotgunSpread, 0.01),
    );
    for (final h in headings) {
      expect(
        h.abs(),
        lessThanOrEqualTo(PowerUpTuning.shotgunSpread / 2 + 1e-9),
      );
    }
    expect(a.held, PowerUpKind.shotgun);
    _run(c, PowerUpSystem.firedWeaponHoldSteps);
    expect(a.held, isNull);
  });

  test('a bow fires a low-damage volley twice a grenade blast wide', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.bow;
    final distance = (b.position - a.position).distance;
    _run(c, PowerUpTuning.aimSteps);

    final arrows = c.powerUps!.projectiles;
    expect(arrows, hasLength(PowerUpTuning.bowArrows));
    expect(arrows.every((arrow) => arrow.kind == PowerUpKind.bow), isTrue);
    final aim = math.atan2(
      b.position.dy - a.position.dy,
      b.position.dx - a.position.dx,
    );
    final headings = [for (final arrow in arrows) _heading(arrow) - aim];
    expect(
      headings.reduce(math.max) - headings.reduce(math.min),
      closeTo(PowerUpTuning.bowSpread(distance, _arenaRadius), 0.01),
    );
    expect(PowerUpTuning.arenaDamage[PowerUpKind.bow], 4);
    expect(a.held, PowerUpKind.bow);
    _run(c, PowerUpSystem.firedWeaponHoldSteps);
    expect(a.held, isNull);
  });

  test('a gatling fires 10 rounds, one every gatlingIntervalSteps steps', () {
    final c = _match();
    final a = c.state.balls.first;
    a.held = PowerUpKind.gatling;
    _run(c, PowerUpTuning.aimSteps);
    expect(c.powerUps!.shots, 1);
    for (var k = 1; k < PowerUpTuning.gatlingRounds; k++) {
      _run(c, PowerUpTuning.gatlingIntervalSteps - 1);
      expect(c.powerUps!.shots, k, reason: 'round ${k + 1} not yet');
      _run(c, 1);
      expect(c.powerUps!.shots, k + 1);
    }
    _run(c, PowerUpTuning.gatlingIntervalSteps * 3);
    expect(c.powerUps!.shots, PowerUpTuning.gatlingRounds);
    expect(a.burstLeft, 0);
  });

  test('a bullet that reaches the target damages it once', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.pistol;
    _run(c, PowerUpTuning.aimSteps);
    final bullet = c.powerUps!.projectiles.single;
    _runUntilSpent(c, bullet);
    expect(bullet.spent, isTrue);
    expect(
      b.life,
      PowerUpTuning.arenaLife - PowerUpTuning.arenaDamage[PowerUpKind.pistol]!,
    );
    expect(c.powerUps!.hits, 1);
    expect(c.powerUps!.projectiles, isEmpty);
    _run(c, 60);
    expect(
      b.life,
      PowerUpTuning.arenaLife - PowerUpTuning.arenaDamage[PowerUpKind.pistol]!,
    );
    expect(a.life, PowerUpTuning.arenaLife);
  });

  test('a hit splashes particles in the configured blood color', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.pistol;
    _run(c, PowerUpTuning.aimSteps);
    final bullet = c.powerUps!.projectiles.single;
    _runUntilSpent(c, bullet);
    final colored = c.state.particles.particles.whereType<Particle>().where(
      (p) => p.color == c.bloodColor,
    );
    expect(colored, isNotEmpty);
  });

  test(
    'in All-Out a bullet cuts the opponent threads it flies through and a hit snaps threads near the impact',
    () {
      final c = _match(mode: MatchMode.allOut);
      final [a, b] = c.state.balls;
      a.position = const Offset(150, 100);
      b.position = Offset.zero;
      // b owns the left half of the rim. A bullet from the left, passing b's center at 0.8 r, flies through
      // b's threads anchored up-left before it strikes b off-center.
      final offset = b.radius * 0.8;
      final start = Offset(-200, offset);
      final impactX = -math.sqrt(b.radius * b.radius - offset * offset);
      final beforeImpact = Offset(impactX - 10, offset);
      final crossed = {
        for (final line in b.fanLines)
          if (_segmentsCross(start, beforeImpact, line.startPoint, b.position))
            line.slotIndex,
      };
      expect(crossed, isNotEmpty);
      final linesBefore = b.fanLines.length;
      final freeBefore = c.freeSlotCount;
      final bullet = Projectile(
        owner: a,
        kind: PowerUpKind.pistol,
        position: start,
        velocity: Offset(_bulletSpeed(), 0),
      );
      c.powerUps!.projectiles.add(bullet);
      _runUntilSpent(c, bullet);
      expect(bullet.spent, isTrue);
      final left = {for (final line in b.fanLines) line.slotIndex};
      expect(left.intersection(crossed), isEmpty);
      final drop = linesBefore - b.fanLines.length;
      expect(
        drop,
        greaterThanOrEqualTo(
          crossed.length + PowerUpTuning.allOutThreads[PowerUpKind.pistol]!,
        ),
      );
      expect(c.freeSlotCount - freeBefore, drop);
    },
  );

  test('bullets from an eliminated ball still fly; it fires nothing new', () {
    // Killed mid-aim: nothing is fired.
    final c = _match(count: 3);
    final a = c.state.balls.first;
    a.held = PowerUpKind.pistol;
    _run(c, PowerUpTuning.aimSteps ~/ 2);
    a.isEliminated = true;
    _run(c, PowerUpTuning.aimSteps);
    expect(c.powerUps!.projectiles, isEmpty);
    expect(c.powerUps!.shots, 0);

    // Killed with a bullet in flight: it still lands.
    final d = _match(count: 3);
    final [holder, target, bystander] = d.state.balls;
    holder.held = PowerUpKind.pistol;
    _run(d, PowerUpTuning.aimSteps);
    final bullet = d.powerUps!.projectiles.single;
    holder.isEliminated = true;
    _runUntilSpent(d, bullet);
    // 3 balls: crowded Arsenal damage is x2.25 (never below 0).
    expect(
      target.life,
      math.max(
        0.0,
        PowerUpTuning.arenaLife -
            PowerUpTuning.arenaDamage[PowerUpKind.pistol]! * 2.25,
      ),
    );
    expect(bystander.life, PowerUpTuning.arenaLife);
  });

  test('freeze ray stops the target for freezeSteps steps', () {
    final c = _match();
    final [a, b] = c.state.balls;
    b.position = Offset.zero;
    const velocity = Offset(60, 0);
    b.velocity = velocity;
    // A freeze shot waiting where b will be after its next move.
    c.powerUps!.projectiles.add(
      Projectile(
        owner: a,
        kind: PowerUpKind.freeze,
        position: b.position + velocity / 60,
        velocity: Offset(_bulletSpeed(), 0),
      ),
    );
    _run(c, 1);
    expect(b.frozenLeft, PowerUpTuning.freezeSteps);
    final held = b.position;
    for (var i = 0; i < PowerUpTuning.freezeSteps; i++) {
      expect(b.velocity, Offset.zero, reason: 'step $i');
      _run(c, 1);
      expect(b.position, held, reason: 'step $i');
    }
    expect(b.frozenLeft, 0);
    expect(b.velocity, velocity);
    expect(b.life, PowerUpTuning.arenaLife);
    _run(c, 1);
    expect(b.position, isNot(held));
  });

  test('frozen holders do not aim', () {
    final c = _match();
    final a = c.state.balls.first;
    a.held = PowerUpKind.pistol;
    a.frozenLeft = PowerUpTuning.aimSteps;
    _run(c, PowerUpTuning.aimSteps);
    expect(c.powerUps!.shots, 0);
    _run(c, PowerUpTuning.aimSteps);
    expect(c.powerUps!.shots, 1);
  });

  test('a ball takes at most one field power-up per step', () {
    final c = _match();
    final a = c.state.balls.first;
    final powerUps = c.powerUps!;
    powerUps.field
      ..add(
        FieldPowerUp(
          kind: PowerUpKind.knife,
          position: a.position,
          spawnStep: 0,
        ),
      )
      ..add(
        FieldPowerUp(
          kind: PowerUpKind.apple,
          position: a.position + const Offset(2, 0),
          spawnStep: 0,
        ),
      );
    _run(c, 1);
    expect(a.held, PowerUpKind.knife);
    expect(powerUps.pickups, 1);
    expect(powerUps.field.single.kind, PowerUpKind.apple);
  });
}
