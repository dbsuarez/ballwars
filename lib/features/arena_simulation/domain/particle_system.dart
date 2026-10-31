import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';
import '../../match_setup/domain/match_config.dart';

abstract class BaseParticle {
  double age = 0.0;
  double get lifespan;
  bool get isExpired => age >= lifespan;
  void update(double dt) => age += dt;
}

enum ParticleKind { generic, wallSpark, blood }

class Particle extends BaseParticle {
  Offset position;
  Offset velocity;
  @override
  final double lifespan;
  final Color color;
  final double baseRadius;
  final ParticleKind kind;

  Particle({
    required this.position,
    required this.velocity,
    required this.lifespan,
    required this.color,
    required this.baseRadius,
    this.kind = ParticleKind.generic,
  });

  @override
  void update(double dt) {
    age += dt;
    position += velocity * dt;
  }
}

class RimArcParticle extends BaseParticle {
  final Offset origin;
  final Offset velocity;
  @override
  final double lifespan;
  final Color color;
  final double arcLength;
  final double arenaRadius;
  final double rimAngle;
  final ArenaShape arenaShape;

  RimArcParticle({
    required this.origin,
    required this.velocity,
    required this.lifespan,
    required this.color,
    required this.arcLength,
    required this.arenaRadius,
    required this.rimAngle,
    this.arenaShape = ArenaShape.circle,
  });

  @override
  void update(double dt) => age += dt;

  Offset get position => origin;

  /// Returns the arc segment start and end points for rendering
  (Offset, Offset) getArcSegment() {
    if (arenaShape == ArenaShape.square) {
      // Travel around the actual square perimeter, including its corners.
      final perimeter = arenaRadius * 8;
      if (perimeter <= 0) return (origin, origin);
      final start = _squareDistance(origin, arenaRadius);
      final direction = velocity.dx * _squareTangent(origin, arenaRadius).dx +
          velocity.dy * _squareTangent(origin, arenaRadius).dy >= 0 ? 1.0 : -1.0;
      final center = start + direction * velocity.distance * age;
      return (
        _squarePoint(center - arcLength, arenaRadius),
        _squarePoint(center + arcLength, arenaRadius),
      );
    }
    final traveled = velocity.distance * (lifespan - age);
    final angleOffset = traveled / arenaRadius;

    // Arc extends from behind to ahead of current position
    final startAngle = rimAngle - angleOffset - arcLength / arenaRadius;
    final endAngle = rimAngle - angleOffset + arcLength / arenaRadius;

    final startPt = Offset(
      math.cos(startAngle) * arenaRadius,
      math.sin(startAngle) * arenaRadius,
    );
    final endPt = Offset(
      math.cos(endAngle) * arenaRadius,
      math.sin(endAngle) * arenaRadius,
    );

    return (startPt, endPt);
  }
}

/// Clockwise distance along a square rim, starting at the top-left corner.
double _squareDistance(Offset p, double r) {
  if (p.dy <= -r + 0.001) return (p.dx + r).clamp(0.0, 2 * r);
  if (p.dx >= r - 0.001) return 2 * r + (p.dy + r).clamp(0.0, 2 * r);
  if (p.dy >= r - 0.001) return 4 * r + (r - p.dx).clamp(0.0, 2 * r);
  return 6 * r + (r - p.dy).clamp(0.0, 2 * r);
}

Offset _squarePoint(double distance, double r) {
  if (r <= 0) return Offset.zero;
  final d = distance % (8 * r);
  if (d < 2 * r) return Offset(-r + d, -r);
  if (d < 4 * r) return Offset(r, -r + d - 2 * r);
  if (d < 6 * r) return Offset(r - (d - 4 * r), r);
  return Offset(-r, r - (d - 6 * r));
}

Offset _squareTangent(Offset p, double r) {
  if (p.dy <= -r + 0.001) return const Offset(1, 0);
  if (p.dx >= r - 0.001) return const Offset(0, 1);
  if (p.dy >= r - 0.001) return const Offset(-1, 0);
  return const Offset(0, -1);
}

class ParticleSystem {
  final List<BaseParticle> _particles = [];

  /// Color of the sparkle burst when a ball takes an apple.
  static const Color sparkleColor = Color(0xFF4ADE80);

  List<BaseParticle> get particles => List.unmodifiable(_particles);

  void spawnBurst({
    required Offset origin,
    required Offset normal,
    required Color color,
    required SeededRandom rng,
  }) {
    final count = 60 + rng.nextInt(41); // 60..100
    final baseAngle = math.atan2(normal.dy, normal.dx);

    for (var i = 0; i < count; i++) {
      final spread = rng.nextDoubleRange(-math.pi / 2, math.pi / 2);
      final angle = baseAngle + spread;
      final speed = rng.nextDoubleRange(80.0, 320.0);
      final velocity = Offset(math.cos(angle), math.sin(angle)) * speed;
      final lifespan = rng.nextDoubleRange(0.5, 1.1);
      final baseRadius = rng.nextDoubleRange(2.0, 6.0);

      _particles.add(
        Particle(
          position: origin,
          velocity: velocity,
          lifespan: lifespan,
          color: color,
          baseRadius: baseRadius,
          kind: ParticleKind.wallSpark,
        ),
      );
    }
  }

  /// Spawns a short "blood" splash in the hit ball's [color] where a weapon struck it, thrown along
  /// [direction] (the way the blow travelled).
  void spawnBlood({
    required Offset origin,
    required Offset direction,
    required Color color,
    required SeededRandom rng,
  }) {
    final count = 10 + rng.nextInt(7); // 10..16
    final baseAngle = math.atan2(direction.dy, direction.dx);

    for (var i = 0; i < count; i++) {
      final angle = baseAngle + rng.nextDoubleRange(-math.pi / 3, math.pi / 3);
      final speed = rng.nextDoubleRange(60.0, 220.0);
      _particles.add(
        Particle(
          position: origin,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          lifespan: rng.nextDoubleRange(0.25, 0.5),
          color: color,
          baseRadius: rng.nextDoubleRange(1.5, 3.5),
          kind: ParticleKind.blood,
        ),
      );
    }
  }

  /// Small bright contact flash used when a weapon visibly connects.
  void spawnImpact({
    required Offset origin,
    required SeededRandom rng,
    required Color color,
    required Color accent,
    int count = 10,
    double displayScale = 1,
  }) {
    count += rng.nextInt(5);
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDoubleRange(0, 2 * math.pi);
      final speed = rng.nextDoubleRange(70.0, 190.0);
      _particles.add(
        Particle(
          position: origin,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          lifespan: rng.nextDoubleRange(0.12, 0.28),
          color: i.isEven ? color : accent,
          baseRadius: rng.nextDoubleRange(1.2, 2.8) * displayScale,
        ),
      );
    }
  }

  /// Spawns a burst of small green sparkles all around [origin], when a ball takes an apple.
  void spawnSparkle({
    required Offset origin,
    required SeededRandom rng,
    double displayScale = 1,
  }) {
    final count = 14 + rng.nextInt(7); // 14..20

    for (var i = 0; i < count; i++) {
      final angle = rng.nextDoubleRange(0, 2 * math.pi);
      final speed = rng.nextDoubleRange(40.0, 160.0);
      _particles.add(
        Particle(
          position: origin,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          lifespan: rng.nextDoubleRange(0.3, 0.6),
          color: sparkleColor,
          baseRadius: rng.nextDoubleRange(1.2, 2.8) * displayScale,
        ),
      );
    }
  }

  /// Spawns cut sparks - small white dots, short burst (3-4 frames worth)
  void spawnCutSparks({
    required Offset origin,
    required Offset normal,
    required SeededRandom rng,
  }) {
    final count = 8 + rng.nextInt(8); // 8..15 small sparks
    final baseAngle = math.atan2(normal.dy, normal.dx);

    for (var i = 0; i < count; i++) {
      final spread = rng.nextDoubleRange(
        -math.pi / 3,
        math.pi / 3,
      ); // Tighter spread
      final angle = baseAngle + spread;
      final speed = rng.nextDoubleRange(150.0, 400.0);
      final velocity = Offset(math.cos(angle), math.sin(angle)) * speed;
      final lifespan = rng.nextDoubleRange(0.15, 0.35); // 3-4 frames at 60fps
      final baseRadius = rng.nextDoubleRange(1.0, 2.5); // 1-2px dots

      _particles.add(
        Particle(
          position: origin,
          velocity: velocity,
          lifespan: lifespan,
          color: Colors.white,
          baseRadius: baseRadius,
        ),
      );
    }
  }

  /// Spawns directional spark trail along beam direction
  void spawnBeamTrailSparks({
    required Offset origin,
    required Offset direction, // Normalized direction along beam
    required SeededRandom rng,
  }) {
    final count = 3 + rng.nextInt(4); // 3-6 trail sparks
    final baseAngle = math.atan2(direction.dy, direction.dx);

    for (var i = 0; i < count; i++) {
      // Very tight spread along beam direction
      final spread = rng.nextDoubleRange(-0.15, 0.15);
      final angle = baseAngle + spread;
      final speed = rng.nextDoubleRange(200.0, 500.0);
      final velocity = Offset(math.cos(angle), math.sin(angle)) * speed;
      final lifespan = rng.nextDoubleRange(0.1, 0.25);
      final baseRadius = rng.nextDoubleRange(1.0, 2.0);

      _particles.add(
        Particle(
          position: origin,
          velocity: velocity,
          lifespan: lifespan,
          color: Colors.white.withValues(alpha: 0.9),
          baseRadius: baseRadius,
        ),
      );
    }
  }

  /// Spawns thin white arcs leaving the rim (on cut events)
  /// Arcs travel tangentially along the arena rim
  void spawnRimArcs({
    required Offset origin, // Cut point on rim
    required Offset normal, // Direction of cut (for arc direction)
    required double arenaRadius,
    required SeededRandom rng,
    ArenaShape arenaShape = ArenaShape.circle,
  }) {
    final arcCount = 2 + rng.nextInt(3); // 2-4 arcs
    // Tangent direction at rim point
    final rimAngle = math.atan2(origin.dy, origin.dx);
    // Two tangent directions (both ways along rim)
    final tangent1 = arenaShape == ArenaShape.square
        ? _squareTangent(origin, arenaRadius)
        : Offset(-math.sin(rimAngle), math.cos(rimAngle));
    final tangent2 = -tangent1;

    for (var i = 0; i < arcCount; i++) {
      // Alternate directions
      final tangent = i % 2 == 0 ? tangent1 : tangent2;
      // Slight spread
      final spreadAngle = rng.nextDoubleRange(-0.1, 0.1);
      final tangentWithSpread = Offset(
        tangent.dx * math.cos(spreadAngle) - tangent.dy * math.sin(spreadAngle),
        tangent.dx * math.sin(spreadAngle) + tangent.dy * math.cos(spreadAngle),
      );
      final speed = rng.nextDoubleRange(200.0, 400.0);
      final velocity = tangentWithSpread * speed;
      final lifespan = rng.nextDoubleRange(0.15, 0.35); // 3-4 frames at 60fps
      final arcLength = rng.nextDoubleRange(15.0, 30.0); // Arc length in pixels

      _particles.add(
        RimArcParticle(
          origin: origin,
          velocity: velocity,
          lifespan: lifespan,
          color: Colors.white,
          arcLength: arcLength,
          arenaRadius: arenaRadius,
          rimAngle: rimAngle,
          arenaShape: arenaShape,
        ),
      );
    }
  }

  void update(double dt) {
    for (final particle in _particles) {
      particle.update(dt);
    }
    _particles.removeWhere((p) => p.isExpired);
  }
}
