import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/domain/arena_physics_engine.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

SimulationBall _ball({
  required Offset position,
  required Offset velocity,
  double radius = 20.0,
  double mass = 1.0,
}) {
  return SimulationBall(
    config: CustomBall(
      id: 'b',
      name: 'B',
      primaryColor: Colors.red,
      glowColor: Colors.pink,
      mass: mass,
    ),
    position: position,
    velocity: velocity,
    radius: radius,
    lineCount: 180,
  );
}

void main() {
  group('resolveWallCollision', () {
    test('reflects velocity and clamps position when past boundary', () {
      final engine = ArenaPhysicsEngine(100.0, SeededRandom(1));
      final ball = _ball(
        position: const Offset(95, 0),
        velocity: const Offset(10, 0),
        radius: 10.0,
      );
      engine.resolveWallCollision(ball);

      // radius from center must not exceed (arenaRadius - ballRadius)
      final dist = ball.position.distance;
      expect(dist, lessThanOrEqualTo(90.0 + 1e-6));
      // velocity x-component should have flipped sign (reflected inward)
      expect(ball.velocity.dx, lessThan(0));
    });

    test('does nothing when ball is well within boundary', () {
      final engine = ArenaPhysicsEngine(100.0, SeededRandom(1));
      final ball = _ball(
        position: const Offset(0, 0),
        velocity: const Offset(5, 5),
        radius: 10.0,
      );
      engine.resolveWallCollision(ball);
      expect(ball.position, const Offset(0, 0));
      expect(ball.velocity, const Offset(5, 5));
    });
  });

  group('resolveBallCollision', () {
    test('returns null when balls do not overlap', () {
      final engine = ArenaPhysicsEngine(200.0, SeededRandom(1));
      final a = _ball(position: const Offset(-100, 0), velocity: Offset.zero, radius: 10);
      final b = _ball(position: const Offset(100, 0), velocity: Offset.zero, radius: 10);
      expect(engine.resolveBallCollision(a, b), isNull);
    });

    test('separates overlapping balls and reflects velocities', () {
      final engine = ArenaPhysicsEngine(200.0, SeededRandom(1));
      final a = _ball(position: const Offset(-5, 0), velocity: const Offset(10, 0), radius: 10);
      final b = _ball(position: const Offset(5, 0), velocity: const Offset(-10, 0), radius: 10);

      final result = engine.resolveBallCollision(a, b);

      expect(result, isNotNull);
      // after separation, distance should be >= sum of radii
      final dist = (b.position - a.position).distance;
      expect(dist, greaterThanOrEqualTo(20.0 - 1e-6));
      // a was moving right into b, so it should now be moving left (or stopped)
      expect(a.velocity.dx, lessThanOrEqualTo(10.0));
      expect(result!.relativeImpactSpeed, greaterThan(0));
    });
  });
}
