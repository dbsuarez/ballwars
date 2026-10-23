import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/math_utils.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _arenaRadius = 260.0;

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
];

/// An All-Out match with both balls held still: ball 0 at (100, 0), ball 1 at (-100, 0).
MatchSimulationController _match() {
  final c = MatchSimulationController(
    _balls,
    arenaRadius: _arenaRadius,
    seed: 1,
    layoutRotation: 0,
    mode: MatchMode.allOut,
    lookAhead: false,
  );
  final balls = c.state.balls;
  for (final b in balls) {
    b.velocity = Offset.zero;
  }
  balls[0].position = const Offset(100, 0);
  balls[1].position = const Offset(-100, 0);
  return c;
}

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.tick(1 / 60);
  }
}

/// Threads of [ball] whose segment (rim anchor to the ball) passes within [radius] of [point].
int _linesNear(SimulationBall ball, Offset point, double radius) => ball.fanLines
    .where((l) => MathUtils.distancePointToSegmentSquared(point, l.startPoint, ball.position) <= radius * radius)
    .length;

void main() {
  test('a bomb blast clears every thread through the blast, from all balls', () {
    final c = _match();
    final a = c.state.balls[0];
    final b = c.state.balls[1];
    final radius = _arenaRadius * PowerUpTuning.bombRadiusRatio;
    // Between the two balls, near the rim at the top: crosses threads of both.
    const at = Offset(0, -170);
    expect(_linesNear(a, at, radius), greaterThan(0));
    expect(_linesNear(b, at, radius), greaterThan(0));

    c.powerUps!.bombs.add(PendingBomb(owner: a, position: at, fuseSteps: 1));
    _run(c, 1);

    expect(_linesNear(a, at, radius), 0);
    expect(_linesNear(b, at, radius), 0);
    // The blast is recorded where it happened, for drawing.
    expect(c.powerUps!.explosions.single.position, at);
  });

  test('a ghost keeps its threads in a bomb blast', () {
    final c = _match();
    final a = c.state.balls[0];
    final b = c.state.balls[1];
    final radius = _arenaRadius * PowerUpTuning.bombRadiusRatio;
    const at = Offset(0, -170);
    b.ghostLeft = 30;
    final before = _linesNear(b, at, radius);

    c.powerUps!.bombs.add(PendingBomb(owner: a, position: at, fuseSteps: 1));
    _run(c, 1);

    expect(_linesNear(b, at, radius), before);
  });

  test('a sword sweep cuts every opponent thread the holder passes through for 60 steps', () {
    final c = _match();
    final a = c.state.balls[0];
    final b = c.state.balls[1];
    c.powerUps!.field.add(FieldPowerUp(kind: PowerUpKind.knife, position: a.position, spawnStep: 0));
    _run(c, 1);
    // Timers count down before pickups, so the sweep starts full.
    expect(a.sweepLeft, PowerUpTuning.sweepSteps);

    // A reach wider than the body: threads of B that pass just outside A's body are cut too.
    final reach = a.radius * PowerUpTuning.sweepReach;
    a.position = const Offset(-40, -120);
    final outside = b.fanLines
        .where((l) {
          final d = MathUtils.distancePointToSegmentSquared(a.position, l.startPoint, b.position);
          return d > a.radius * a.radius && d <= reach * reach;
        })
        .length;
    expect(outside, greaterThan(0));
    _run(c, 1);
    expect(_linesNear(b, a.position, reach), 0);
  });

  test('without a sweep, threads just outside the body are not cut', () {
    final c = _match();
    final a = c.state.balls[0];
    final b = c.state.balls[1];
    final reach = a.radius * PowerUpTuning.sweepReach;
    a.position = const Offset(-40, -120);
    final before = _linesNear(b, a.position, reach);
    _run(c, 1);
    expect(_linesNear(b, a.position, reach), greaterThan(0));
    expect(_linesNear(b, a.position, reach), lessThanOrEqualTo(before));
  });

  test('a ghost sweeping cuts nothing', () {
    final c = _match();
    final a = c.state.balls[0];
    final b = c.state.balls[1];
    a
      ..sweepLeft = 30
      ..ghostLeft = 30
      ..position = const Offset(-40, -120);
    final lines = b.fanLines.length;
    _run(c, 1);
    expect(b.fanLines.length, lines);
  });

  test('a thread snap shows cut sparks, an apple grab shows "+N LINES"', () {
    final c = _match();
    final a = c.state.balls[0];
    // A bullet from A straight at B.
    c.powerUps!.projectiles.add(
      Projectile(owner: a, kind: PowerUpKind.pistol, position: const Offset(40, 0), velocity: const Offset(-600, 0)),
    );
    final arcsBefore = c.state.particles.particles.whereType<RimArcParticle>().length;
    _run(c, 20);
    expect(c.state.particles.particles.whereType<RimArcParticle>().length, greaterThan(arcsBefore));

    // Free a few of A's slots, then let A eat an apple.
    c.cutThreads(a, 5);
    final texts = c.state.floatingTexts.items.length;
    c.powerUps!.field.add(FieldPowerUp(kind: PowerUpKind.apple, position: a.position, spawnStep: 0));
    _run(c, 1);
    expect(c.state.floatingTexts.items.length, greaterThan(texts));
    expect(c.state.floatingTexts.items.last.text, startsWith('+'));
  });
}
