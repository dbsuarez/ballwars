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
    test('reflects velocity, clamps position, and reports a bounce when past boundary', () {
      final engine = ArenaPhysicsEngine(100.0, SeededRandom(1));
      final ball = _ball(
        position: const Offset(95, 0),
        velocity: const Offset(10, 0),
        radius: 10.0,
      );
      final result = engine.resolveWallCollision(ball);

      expect(result, isNotNull);
      expect(result!.wallAnchorPoint, isNotNull);
      // radius from center must not exceed (arenaRadius - ballRadius)
      final dist = ball.position.distance;
      expect(dist, lessThanOrEqualTo(90.0 + 1e-6));
      // velocity x-component should have flipped sign (reflected inward)
      expect(ball.velocity.dx, lessThan(0));
    });

    test('does nothing and reports no bounce when ball is well within boundary', () {
      final engine = ArenaPhysicsEngine(100.0, SeededRandom(1));
      final ball = _ball(
        position: const Offset(0, 0),
        velocity: const Offset(5, 5),
        radius: 10.0,
      );
      final result = engine.resolveWallCollision(ball);
      expect(result, isNull);
      expect(ball.position, const Offset(0, 0));
      expect(ball.velocity, const Offset(5, 5));
    });

    test('handles ball at center (d==0) without NaN', () {
      final engine = ArenaPhysicsEngine(100.0, SeededRandom(1));
      final ball = _ball(
        position: Offset.zero,
        velocity: const Offset(10, 0),
        radius: 10.0,
      );
      final result = engine.resolveWallCollision(ball);
      // Ball at center with velocity outward - should not bounce yet (d=0 < maxDist)
      expect(result, isNull);
      expect(ball.position, Offset.zero);
      expect(ball.velocity, const Offset(10, 0));
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

    test('applies restitution (energy loss)', () {
      final engine = ArenaPhysicsEngine(200.0, SeededRandom(1), restitution: 0.5);
      final a = _ball(position: const Offset(-5, 0), velocity: const Offset(10, 0), radius: 10, mass: 1.0);
      final b = _ball(position: const Offset(5, 0), velocity: const Offset(-10, 0), radius: 10, mass: 1.0);

      final result = engine.resolveBallCollision(a, b);

      expect(result, isNotNull);
      // With restitution 0.5, relative speed after collision should be half
      final relativeSpeedAfter = (a.velocity - b.velocity).distance;
      final relativeSpeedBefore = 20.0; // 10 - (-10)
      expect(relativeSpeedAfter, closeTo(relativeSpeedBefore * 0.5, 1e-6));
    });

    test('handles dist==0 case without NaN', () {
      final engine = ArenaPhysicsEngine(200.0, SeededRandom(1));
      final a = _ball(position: Offset.zero, velocity: const Offset(10, 0), radius: 10);
      final b = _ball(position: Offset.zero, velocity: const Offset(-10, 0), radius: 10);

      final result = engine.resolveBallCollision(a, b);

      expect(result, isNull); // dist == 0 returns null
      expect(a.position, Offset.zero);
      expect(b.position, Offset.zero);
    });
  });
}