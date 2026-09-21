import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';
import 'package:ballwars/features/arena_simulation/domain/floating_text.dart';

void main() {
  group('ParticleSystem', () {
    test('spawnBurst adds 60 to 100 particles', () {
      final system = ParticleSystem();
      system.spawnBurst(
        origin: Offset.zero,
        normal: const Offset(1, 0),
        color: Colors.red,
        rng: SeededRandom(1),
      );
      expect(system.particles.length, inInclusiveRange(60, 100));
    });

    test('update ages particles and removes expired ones', () {
      final system = ParticleSystem();
      system.spawnBurst(
        origin: Offset.zero,
        normal: const Offset(1, 0),
        color: Colors.red,
        rng: SeededRandom(1),
      );
      final countBefore = system.particles.length;
      system.update(0.1);
      expect(system.particles.length, lessThanOrEqualTo(countBefore));
      // Advance well past any plausible lifespan.
      for (var i = 0; i < 50; i++) {
        system.update(0.1);
      }
      expect(system.particles, isEmpty);
    });
  });

  group('FloatingTextManager', () {
    test('spawn adds a floating text item with full opacity', () {
      final manager = FloatingTextManager();
      manager.spawn(Offset.zero, '+35 LINES', Colors.green);
      expect(manager.items.length, 1);
      expect(manager.items.first.opacity, closeTo(1.0, 1e-9));
    });

    test('update fades and removes expired items', () {
      final manager = FloatingTextManager();
      manager.spawn(Offset.zero, '+35 LINES', Colors.green);
      manager.update(0.6);
      expect(manager.items.first.opacity, closeTo(0.5, 0.05));
      manager.update(1.0);
      expect(manager.items, isEmpty);
    });
  });
}
