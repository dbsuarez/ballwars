import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  test('square rim sparks follow the flat outer wall', () {
    final particle = RimArcParticle(
      origin: const Offset(100, 0),
      velocity: const Offset(0, 100),
      lifespan: 1,
      color: Colors.white,
      arcLength: 5,
      arenaRadius: 100,
      rimAngle: 0,
      arenaShape: ArenaShape.square,
    );
    final (start, end) = particle.getArcSegment();
    expect(start.dx, 100);
    expect(end.dx, 100);
    particle.update(0.2);
    final (movedStart, movedEnd) = particle.getArcSegment();
    expect(movedStart.dx, 100);
    expect(movedEnd.dx, 100);
    expect(movedStart.dy, greaterThan(start.dy));
  });

  test('square rim sparks turn corners instead of following a circle', () {
    final particle = RimArcParticle(
      origin: const Offset(98, -100),
      velocity: const Offset(100, 0),
      lifespan: 1,
      color: Colors.white,
      arcLength: 1,
      arenaRadius: 100,
      rimAngle: 0,
      arenaShape: ArenaShape.square,
    );
    particle.update(0.1);
    final (start, end) = particle.getArcSegment();
    expect(start.dx, 100);
    expect(end.dx, 100);
    expect(start.dy, greaterThan(-100));
  });
}
