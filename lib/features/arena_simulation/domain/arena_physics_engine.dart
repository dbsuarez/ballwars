import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';
import 'simulation_ball.dart';
import '../../match_setup/domain/match_config.dart';

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
  double arenaRadius;
  final SeededRandom rng;
  final double restitution;
  final ArenaShape shape;

  static const double _jitterMaxRadians = 2 * math.pi / 180.0;

  ArenaPhysicsEngine(this.arenaRadius, this.rng, {this.restitution = 0.85, this.shape = ArenaShape.circle});

  /// Reflects [ball] off the arena wall if it has reached or crossed the boundary.
  /// Uses continuous collision detection to handle high velocities.
  /// Returns a CollisionResult with the wall anchor point if a bounce occurred.
  CollisionResult? resolveWallCollision(
    SimulationBall ball, {
    Offset? previousPosition,
  }) {
    if (shape == ArenaShape.square) {
      return _resolveSquareWall(ball);
    }
    final d = ball.position.distance;
    final maxDist = arenaRadius - ball.radius;

    // Check if ball is currently outside or on the boundary
    final currentlyOutside = d >= maxDist;

    // Also check if ball crossed the boundary this frame (CCD)
    bool crossedBoundary = false;
    Offset? collisionNormal;
    Offset? collisionPoint;

    if (previousPosition != null) {
      final prevD = previousPosition.distance;
      // Check if line segment from previous to current crosses the boundary
      if (prevD < maxDist && d >= maxDist) {
        crossedBoundary = true;
        // Find exact collision point on the boundary
        final dir = ball.position - previousPosition;
        final segmentLength = dir.distance;
        if (segmentLength > 0) {
          final t = (maxDist - prevD) / (d - prevD);
          collisionPoint = previousPosition + dir * t;
          // Linear interpolation of the distance lands near, not exactly on,
          // the boundary: normalize so the reflection preserves speed.
          collisionNormal = collisionPoint / collisionPoint.distance;
        }
      }
    }

    // Fallback 1: if ball is currently outside but we didn't detect crossing (edge case),
    // force a collision with current position
    if (currentlyOutside && !crossedBoundary) {
      crossedBoundary = true;
      collisionNormal = d == 0 ? const Offset(1.0, 0.0) : ball.position / d;
      collisionPoint = collisionNormal * maxDist;
    }

    // Fallback 2: ultimate safety net - if ball center is past the arena wall (past arenaRadius),
    // it has completely tunneled through. Force it back to the wall.
    if (d > arenaRadius) {
      crossedBoundary = true;
      collisionNormal = d == 0 ? const Offset(1.0, 0.0) : ball.position / d;
      collisionPoint = collisionNormal * maxDist;
    }

    // If currently inside and didn't cross, no collision
    if (!currentlyOutside && !crossedBoundary) return null;

    // Use CCD collision point/normal if available, otherwise use current position
    final normal =
        collisionNormal ??
        (d == 0 ? const Offset(1.0, 0.0) : ball.position / d);
    final contactPt = collisionPoint ?? (normal * maxDist);

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
    ball.position = contactPt;

    // Return wall anchor point for thread attachment
    final wallAnchorPoint = normal * arenaRadius;
    return CollisionResult(
      contactPoint: contactPt,
      normal: normal,
      relativeImpactSpeed: dot.abs() * restitution,
      wallAnchorPoint: wallAnchorPoint,
    );
  }


  /// Resolves square walls using the ball's radius as padding. Both corner
  /// components are reflected, with a deterministic jitter draw per contact.
  CollisionResult? _resolveSquareWall(SimulationBall ball) {
    final bound = math.max(0.0, arenaRadius - ball.radius);
    final x = ball.position.dx;
    final y = ball.position.dy;
    final hitX = x.abs() >= bound;
    final hitY = y.abs() >= bound;
    if (!hitX && !hitY) return null;

    final nx = hitX ? (x < 0 ? -1.0 : 1.0) : 0.0;
    final ny = hitY ? (y < 0 ? -1.0 : 1.0) : 0.0;
    final normal = Offset(nx, ny) / math.sqrt(nx * nx + ny * ny);
    final contact = Offset(x.clamp(-bound, bound).toDouble(),
        y.clamp(-bound, bound).toDouble());
    final impact = ball.velocity.dx * normal.dx +
        ball.velocity.dy * normal.dy;
    var vx = hitX ? -ball.velocity.dx : ball.velocity.dx;
    var vy = hitY ? -ball.velocity.dy : ball.velocity.dy;
    final jitter = rng.nextDoubleRange(-_jitterMaxRadians, _jitterMaxRadians);
    final cosJ = math.cos(jitter);
    final sinJ = math.sin(jitter);
    ball.velocity = Offset(vx * cosJ - vy * sinJ,
        vx * sinJ + vy * cosJ) * restitution;
    ball.position = contact;
    final anchor = Offset(
      hitX ? nx * arenaRadius : contact.dx,
      hitY ? ny * arenaRadius : contact.dy,
    );
    return CollisionResult(
      contactPoint: contact,
      normal: normal,
      relativeImpactSpeed: impact.abs() * restitution,
      wallAnchorPoint: anchor,
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
    final impulseScalar =
        (1.0 + restitution) * relativeNormalVelocity / invMassSum;

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
