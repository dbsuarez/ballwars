import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';

abstract class BaseParticle {
  double age = 0.0;
  double get lifespan;
  bool get isExpired => age >= lifespan;
  void update(double dt) => age += dt;
}

class Particle extends BaseParticle {
  Offset position;
  Offset velocity;
  @override
  final double lifespan;
  final Color color;
  final double baseRadius;

  Particle({
    required this.position,
    required this.velocity,
    required this.lifespan,
    required this.color,
    required this.baseRadius,
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

  RimArcParticle({
    required this.origin,
    required this.velocity,
    required this.lifespan,
    required this.color,
    required this.arcLength,
    required this.arenaRadius,
    required this.rimAngle,
  });

  @override
  void update(double dt) => age += dt;

  Offset get position => origin;

  /// Returns the arc segment start and end points for rendering
  (Offset, Offset) getArcSegment() {
    final traveled = velocity.distance * (lifespan - age);
    final angleOffset = traveled / arenaRadius;

    // Arc extends from behind to ahead of current position
    final startAngle = rimAngle - angleOffset - arcLength / arenaRadius;
    final endAngle = rimAngle - angleOffset + arcLength / arenaRadius;

    final startPt = Offset(math.cos(startAngle) * arenaRadius, math.sin(startAngle) * arenaRadius);
    final endPt = Offset(math.cos(endAngle) * arenaRadius, math.sin(endAngle) * arenaRadius);

    return (startPt, endPt);
  }
}

class ParticleSystem {
  final List<BaseParticle> _particles = [];

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

      _particles.add(Particle(
        position: origin,
        velocity: velocity,
        lifespan: lifespan,
        color: color,
        baseRadius: baseRadius,
      ));
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
      _particles.add(Particle(
        position: origin,
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        lifespan: rng.nextDoubleRange(0.25, 0.5),
        color: color,
        baseRadius: rng.nextDoubleRange(1.5, 3.5),
      ));
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
      final spread = rng.nextDoubleRange(-math.pi / 3, math.pi / 3); // Tighter spread
      final angle = baseAngle + spread;
      final speed = rng.nextDoubleRange(150.0, 400.0);
      final velocity = Offset(math.cos(angle), math.sin(angle)) * speed;
      final lifespan = rng.nextDoubleRange(0.15, 0.35); // 3-4 frames at 60fps
      final baseRadius = rng.nextDoubleRange(1.0, 2.5); // 1-2px dots

      _particles.add(Particle(
        position: origin,
        velocity: velocity,
        lifespan: lifespan,
        color: Colors.white,
        baseRadius: baseRadius,
      ));
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

      _particles.add(Particle(
        position: origin,
        velocity: velocity,
        lifespan: lifespan,
        color: Colors.white.withValues(alpha: 0.9),
        baseRadius: baseRadius,
      ));
    }
  }

  /// Spawns thin white arcs leaving the rim (on cut events)
  /// Arcs travel tangentially along the arena rim
  void spawnRimArcs({
    required Offset origin, // Cut point on rim
    required Offset normal, // Direction of cut (for arc direction)
    required double arenaRadius,
    required SeededRandom rng,
  }) {
    final arcCount = 2 + rng.nextInt(3); // 2-4 arcs
    // Tangent direction at rim point
    final rimAngle = math.atan2(origin.dy, origin.dx);
    // Two tangent directions (both ways along rim)
    final tangent1 = Offset(-math.sin(rimAngle), math.cos(rimAngle));
    final tangent2 = Offset(math.sin(rimAngle), -math.cos(rimAngle));

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

      _particles.add(RimArcParticle(
        origin: origin,
        velocity: velocity,
        lifespan: lifespan,
        color: Colors.white,
        arcLength: arcLength,
        arenaRadius: arenaRadius,
        rimAngle: rimAngle,
      ));
    }
  }

  void update(double dt) {
    for (final particle in _particles) {
      particle.update(dt);
    }
    _particles.removeWhere((p) => p.isExpired);
  }
}
