import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/application/power_up_system.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _arenaRadius = 260.0;

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
];

MatchSimulationController _arsenal({int seed = 1, bool still = true}) {
  final c = MatchSimulationController(
    _balls,
    arenaRadius: _arenaRadius,
    seed: seed,
    layoutRotation: 0,
    mode: MatchMode.arsenal,
    lookAhead: false,
  );
  if (still) {
    for (final b in c.state.balls) {
      b.velocity = Offset.zero;
    }
  }
  return c;
}

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.tick(1 / 60);
  }
}

void main() {
  test('the first power-up spawns early, then one every 300 steps, away from the rim and clear of balls', () {
    final c = _arsenal();
    _run(c, PowerUpTuning.firstSpawnSteps - 1);
    expect(c.powerUps!.field, isEmpty);
    _run(c, 1);
    expect(c.powerUps!.field.length, 1);
    _run(c, PowerUpTuning.spawnIntervalSteps - 1);
    expect(c.powerUps!.field.length, 1);
    _run(c, 1);
    final field = c.powerUps!.field;
    expect(field.length, 2);
    final r = c.powerUps!.fieldRadius;
    for (final f in field) {
      if (f.kind.isTrap) {
        expect(f.position.distance, closeTo(_arenaRadius - r * 1.6, 1e-9));
        continue;
      }
      expect(f.position.distance, lessThanOrEqualTo(_arenaRadius * PowerUpTuning.spawnMaxDistance + 1e-9));
      expect(f.position.distance, greaterThanOrEqualTo(_arenaRadius * PowerUpTuning.spawnMinDistance - 1e-9));
      for (final b in c.state.balls) {
        expect((b.position - f.position).distance, greaterThanOrEqualTo(b.radius + r));
      }
    }
  });

  test('power-ups are a little smaller than the balls, at every ball size', () {
    for (final scale in [0.6, 1.0, 1.25]) {
      final c = MatchSimulationController(_balls,
          arenaRadius: _arenaRadius, seed: 1, mode: MatchMode.arsenal, lookAhead: false, ballScale: scale);
      final ball = c.state.balls.first.radius;
      expect(c.powerUps!.fieldRadius, closeTo(ball * PowerUpTuning.fieldRadiusRatio, 1e-9));
      expect(c.powerUps!.fieldRadius, lessThan(ball));
    }
  });

  test('more balls: more power-ups on the field (balls + 1) and faster spawns; a new one removes the oldest', () {
    for (final n in [2, 3, 4]) {
      final balls = [
        for (var i = 0; i < n; i++)
          CustomBall(id: 'b$i', name: 'B$i', primaryColor: Colors.primaries[i], glowColor: Colors.white),
      ];
      final c = MatchSimulationController(balls,
          arenaRadius: _arenaRadius, seed: 1, mode: MatchMode.arsenal, lookAhead: false, layoutRotation: 0);
      // Balls far out on the rim, still, so they pick nothing up.
      for (var i = 0; i < n; i++) {
        final angle = 2 * math.pi * (i + 0.5) / n;
        c.state.balls[i]
          ..velocity = Offset.zero
          ..position = Offset(math.cos(angle), math.sin(angle)) * (_arenaRadius - c.state.balls[i].radius - 1);
      }
      final interval = PowerUpTuning.spawnInterval(n);
      expect(interval, (PowerUpTuning.spawnIntervalSteps * 2 / n).round());
      final max = PowerUpTuning.maxOnField(n);
      expect(max, n + 1);
      _run(c, PowerUpTuning.firstSpawnSteps + interval * max);
      final field = c.powerUps!.field;
      expect(field.length, max, reason: '$n balls');
      expect(field.first.spawnStep, PowerUpTuning.firstSpawnSteps + interval, reason: '$n balls');
    }
  });

  test('each spawn goes to an empty quadrant, so they never pile up on one side', () {
    for (var seed = 1; seed <= 5; seed++) {
      final c = _arsenal(seed: seed);
      for (final b in c.state.balls) {
        b.position = Offset(b.position.dx.sign * (_arenaRadius - b.radius - 1), 0);
      }
      _run(c, PowerUpTuning.firstSpawnSteps + PowerUpTuning.spawnIntervalSteps * 2);
      final quadrants = [for (final f in c.powerUps!.field) PowerUpSystem.quadrantOf(f.position)];
      expect(quadrants.length, 3, reason: 'seed $seed');
      expect(quadrants.toSet().length, 3, reason: 'seed $seed');
    }
  });

  test('a spawn with no clear spot is skipped', () {
    final c = _arsenal();
    // One ball covering the whole arena: nowhere is clear.
    c.state.balls.first
      ..position = Offset.zero
      ..radius = _arenaRadius;
    _run(c, PowerUpTuning.firstSpawnSteps + PowerUpTuning.spawnIntervalSteps);
    expect(c.powerUps!.field, isEmpty);
  });

  test('touching a power-up picks it up and replaces the held one', () {
    final c = _arsenal();
    final a = c.state.balls.first;
    a.held = PowerUpKind.pistol;
    c.powerUps!.field.add(FieldPowerUp(kind: PowerUpKind.knife, position: a.position, spawnStep: 0));
    _run(c, 1);
    expect(a.held, PowerUpKind.knife);
    expect(c.powerUps!.field, isEmpty);
    expect(c.powerUps!.pickups, 1);
  });

  test('spawns are seeded', () {
    List<(PowerUpKind, Offset)> fieldOf(int seed) {
      final c = _arsenal(seed: seed);
      _run(c, 900);
      return [for (final f in c.powerUps!.field) (f.kind, f.position)];
    }

    expect(fieldOf(5), fieldOf(5));
    expect(fieldOf(5), isNot(fieldOf(6)));
  });

  test('only chosen pickups plus automatic traps spawn', () {
    final c = MatchSimulationController(
      _balls,
      arenaRadius: _arenaRadius,
      seed: 4,
      layoutRotation: 0,
      mode: MatchMode.arsenal,
      lookAhead: false,
      powerUpKinds: {PowerUpKind.apple},
    );
    for (final b in c.state.balls) {
      b.velocity = Offset.zero;
    }
    final seen = <PowerUpKind>{};
    for (var i = 0; i < 60 * 40; i++) {
      c.tick(1 / 60);
      seen.addAll(c.powerUps!.field.map((p) => p.kind));
    }
    expect(seen, isNotEmpty);
    expect(
      seen.difference({PowerUpKind.apple, ...PowerUpKind.values.where((kind) => kind.isTrap)}),
      isEmpty,
    );
    expect(seen.any((kind) => kind.isTrap), isTrue);
  });

  test('traps spawn only along the arena boundary', () {
    final c = MatchSimulationController(
      _balls,
      arenaRadius: _arenaRadius,
      seed: 4,
      layoutRotation: 0,
      mode: MatchMode.arsenal,
      lookAhead: false,
      powerUpKinds: {PowerUpKind.portal},
    );
    for (final b in c.state.balls) {
      b.velocity = Offset.zero;
    }
    _run(c, PowerUpTuning.firstSpawnSteps);
    expect(
      c.powerUps!.field.where((item) => item.kind == PowerUpKind.portal),
      isEmpty,
    );
    final portal = c.powerUps!.portals.single;
    expect(
      portal.position.distance,
      closeTo(_arenaRadius - c.powerUps!.fieldRadius * 1.6, 0.001),
    );
  });

  test('spike wall spawns as a six-spike arena hazard, not a pickup', () {
    final c = MatchSimulationController(
      _balls,
      arenaRadius: _arenaRadius,
      seed: 4,
      layoutRotation: 0,
      mode: MatchMode.arsenal,
      lookAhead: false,
      powerUpKinds: {PowerUpKind.spikeWall},
    );
    for (final b in c.state.balls) {
      b.velocity = Offset.zero;
    }
    for (var i = 0; i < 60 * 60 && c.powerUps!.spikeWalls.isEmpty; i++) {
      c.tick(1 / 60);
      c.state.balls[0]
        ..position = const Offset(-60, 0)
        ..velocity = Offset.zero;
      c.state.balls[1]
        ..position = const Offset(60, 0)
        ..velocity = Offset.zero;
    }

    expect(
      c.powerUps!.field.where((item) => item.kind == PowerUpKind.spikeWall),
      isEmpty,
    );
    expect(c.powerUps!.spikeWalls, hasLength(1));
    expect(c.powerUps!.spikeWalls.single.spikeCount, greaterThanOrEqualTo(6));
    final spikePositions = c.powerUps!.spikeWalls.single.spikePositions(
      c.powerUps!.fieldRadius * 0.96,
    );
    expect(
      spikePositions.map((position) => position.distance),
      everyElement(
        closeTo(c.powerUps!.spikeWalls.single.position.distance, 1e-9),
      ),
    );
    expect(
      c.powerUps!.spikeWalls.single.position.distance,
      closeTo(_arenaRadius - c.powerUps!.fieldRadius * 1.6, 0.001),
    );
  });

  test('choosing every power-up draws exactly like not choosing', () {
    List<PowerUpKind> kinds(Set<PowerUpKind>? chosen) {
      final c = MatchSimulationController(
        _balls,
        arenaRadius: _arenaRadius,
        seed: 9,
        layoutRotation: 0,
        mode: MatchMode.arsenal,
        lookAhead: false,
        powerUpKinds: chosen,
      );
      for (final b in c.state.balls) {
        b.velocity = Offset.zero;
      }
      final out = <PowerUpKind>[];
      for (var i = 0; i < 60 * 30; i++) {
        c.tick(1 / 60);
        if (c.powerUps!.field.isNotEmpty) out.add(c.powerUps!.field.last.kind);
      }
      return out;
    }

    expect(kinds(PowerUpKind.values.toSet()), kinds(null));
  });
}
