import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
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
  test('a power-up spawns every 300 steps at a free spot inside the arena', () {
    final c = _arsenal();
    _run(c, PowerUpTuning.spawnIntervalSteps - 1);
    expect(c.powerUps!.field, isEmpty);
    _run(c, 1);
    final field = c.powerUps!.field;
    expect(field.length, 1);
    final r = _arenaRadius * PowerUpTuning.fieldRadiusRatio;
    expect(field.first.position.distance, lessThanOrEqualTo(_arenaRadius - r));
    for (final b in c.state.balls) {
      expect((b.position - field.first.position).distance, greaterThanOrEqualTo(b.radius + r));
    }
  });

  test('at most 3 on the field; a 4th removes the oldest', () {
    final c = _arsenal();
    _run(c, PowerUpTuning.spawnIntervalSteps * 4);
    final field = c.powerUps!.field;
    expect(field.length, PowerUpTuning.maxOnField);
    expect(field.first.spawnStep, PowerUpTuning.spawnIntervalSteps * 2);
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
}
