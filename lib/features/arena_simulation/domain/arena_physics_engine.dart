import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';
import 'simulation_ball.dart';

class CollisionResult {
  final Offset contactPoint;
  final Offset normal;
  final double relativeImpactSpeed;
  final Offset? wallAnchorPoint;

  const CollisionResult({
    required this.contactPoint,
    required this.normal,
    required this.relativeImpactSpeed,
    this.wallAnchorPoint,
  });
}

class ArenaPhysicsEngine {
  final double arenaRadius;
  final SeededRandom rng;
  final double restitution;

  static const double _jitterMaxRadians = 2 * math.pi / 180.0;

  ArenaPhysicsEngine(this.arenaRadius, this.rng, {this.restitution = 0.85});

  /// Reflects [ball] off the arena wall if it has reached the boundary.
  /// Returns a CollisionResult with the wall anchor point if a bounce occurred.
  CollisionResult? resolveWallCollision(SimulationBall ball) {
    final d = ball.position.distance;
    final maxDist = arenaRadius - ball.radius;
    if (d < maxDist) return null;

    // Handle ball at exact center (d == 0) - pick arbitrary normal
    final normal = d == 0
        ? const Offset(1.0, 0.0)
        : ball.position / d;

    final dot = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
    var reflected = ball.velocity - normal * (2 * dot);

    // Apply restitution (energy loss)
    reflected = reflected * restitution;

    final jitter = rng.nextDoubleRange(-_jitterMaxRadians, _jitterMaxRadians);
    final cosJ = math.cos(jitter);
    final sinJ = math.sin(jitter);
    reflected = Offset(
      reflected.dx * cosJ - reflected.dy * sinJ,
      reflected.dx * sinJ + reflected.dy * cosJ,
    );

    ball.velocity = reflected;
    ball.position = normal * maxDist;

    // Return wall anchor point for thread attachment
    final wallAnchorPoint = normal * arenaRadius;
    return CollisionResult(
      contactPoint: ball.position,
      normal: normal,
      relativeImpactSpeed: dot.abs() * restitution,
      wallAnchorPoint: wallAnchorPoint,
    );
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
    final relativeNormalVelocity =
        relativeVelocity.dx * normal.dx + relativeVelocity.dy * normal.dy;

    // Only collide if approaching each other (relativeNormalVelocity > 0 means closing)
    if (relativeNormalVelocity <= 0) return null;

    // Impulse with restitution: J = (1 + e) * (v_rel · n) / (1/m_a + 1/m_b)
    final invMassSum = 1.0 / massA + 1.0 / massB;
    final impulseScalar = (1.0 + restitution) * relativeNormalVelocity / invMassSum;

    a.velocity -= normal * (impulseScalar / massA);
    b.velocity += normal * (impulseScalar / massB);

    final relativeImpactSpeed = relativeNormalVelocity * restitution;

    final contactPoint = a.position + normal * a.radius;

    return CollisionResult(
      contactPoint: contactPoint,
      normal: normal,
      relativeImpactSpeed: relativeImpactSpeed,
      wallAnchorPoint: null,
    );
  }
}