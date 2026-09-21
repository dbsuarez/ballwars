import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/seeded_random.dart';

class Particle {
  Offset position;
  Offset velocity;
  double age;
  final double lifespan;
  final Color color;
  final double baseRadius;

  Particle({
    required this.position,
    required this.velocity,
    required this.lifespan,
    required this.color,
    required this.baseRadius,
    this.age = 0.0,
  });

  bool get isExpired => age >= lifespan;
}

class ParticleSystem {
  final List<Particle> _particles = [];

  List<Particle> get particles => List.unmodifiable(_particles);

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

  void update(double dt) {
    for (final particle in _particles) {
      particle.age += dt;
      particle.position += particle.velocity * dt;
    }
    _particles.removeWhere((p) => p.isExpired);
  }
}
