import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';
import 'simulation_ball.dart';

class CollisionResult {
  final Offset contactPoint;
  final Offset normal;
  final double relativeImpactSpeed;

  const CollisionResult({
    required this.contactPoint,
    required this.normal,
    required this.relativeImpactSpeed,
  });
}

class ArenaPhysicsEngine {
  final double arenaRadius;
  final SeededRandom rng;

  static const double _jitterMaxRadians = 2 * math.pi / 180.0;

  ArenaPhysicsEngine(this.arenaRadius, this.rng);

  /// Reflects [ball] off the arena wall if it has reached the boundary.
  /// Returns whether a bounce actually occurred.
  bool resolveWallCollision(SimulationBall ball) {
    final d = ball.position.distance;
    final maxDist = arenaRadius - ball.radius;
    if (d < maxDist || d == 0) return false;

    final normal = ball.position / d;
    final dot = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
    var reflected = ball.velocity - normal * (2 * dot);

    final jitter = rng.nextDoubleRange(-_jitterMaxRadians, _jitterMaxRadians);
    final cosJ = math.cos(jitter);
    final sinJ = math.sin(jitter);
    reflected = Offset(
      reflected.dx * cosJ - reflected.dy * sinJ,
      reflected.dx * sinJ + reflected.dy * cosJ,
    );

    ball.velocity = reflected;
    ball.position = normal * maxDist;
    return true;
  }

  CollisionResult? resolveBallCollision(SimulationBall a, SimulationBall b) {
    final delta = b.position - a.position;
    final dist = delta.distance;
    final minDist = a.radius + b.radius;
    if (dist >= minDist || dist == 0) return null;

    final normal = delta / dist;
    final overlap = 0.5 * (minDist - dist);
    a.position -= normal * overlap;
    b.position += normal * overlap;

    final relativeVelocity = a.velocity - b.velocity;
    final massA = a.config.mass;
    final massB = b.config.mass;
    final impulseScalar =
        (2 * (relativeVelocity.dx * normal.dx + relativeVelocity.dy * normal.dy)) /
            (massA + massB);

    a.velocity -= normal * (impulseScalar * massB);
    b.velocity += normal * (impulseScalar * massA);

    final relativeImpactSpeed =
        (relativeVelocity.dx * normal.dx + relativeVelocity.dy * normal.dy).abs();

    final contactPoint = a.position + normal * a.radius;

    return CollisionResult(
      contactPoint: contactPoint,
      normal: normal,
      relativeImpactSpeed: relativeImpactSpeed,
    );
  }
}
