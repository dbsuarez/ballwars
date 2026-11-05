import 'dart:math' as math;
import 'dart:ui';
import 'arena_geometry.dart';

/// Shared clearance checks for authoring, spawning and test-only placement.
class ArenaPlacement {
  static bool fits(
    Offset p, {
    required double radius,
    required double ballRadius,
    required ArenaShape shape,
    required CenterObstacle obstacle,
    required double obstacleScale,
  }) {
    final edge = radius - ballRadius - .01;
    if (edge <= 0 ||
        (shape == ArenaShape.circle
            ? p.distance > edge
            : math.max(p.dx.abs(), p.dy.abs()) > edge)) {
      return false;
    }
    final wall = radius * obstacleScale;
    return switch (obstacle) {
      CenterObstacle.none => true,
      CenterObstacle.circle => p.distance >= wall + ballRadius + .01,
      CenterObstacle.square =>
        p.dx.abs() >= wall + ballRadius + .01 ||
            p.dy.abs() >= wall + ballRadius + .01,
    };
  }

  static String? problem({
    required ArenaShape shape,
    required CenterObstacle obstacle,
    required double obstacleScale,
    required double minimumScale,
    required double ballRadiusRatio,
  }) {
    if (obstacle == CenterObstacle.none) return null;
    final wallReach =
        obstacleScale *
        (shape == ArenaShape.circle && obstacle == CenterObstacle.square
            ? math.sqrt2
            : 1);
    // Obstacles shrink with the arena too. Require a whole ball plus clearance
    // through even the narrowest passage at the final boundary size.
    final passage = minimumScale * (1 - wallReach);
    if (passage < 2 * ballRadiusRatio + .02) {
      return 'Center wall leaves too little room at the minimum arena size. Reduce the wall or ball size, or increase the minimum arena size.';
    }
    return null;
  }

  static Offset? nearest(
    Offset desired, {
    required double radius,
    required double ballRadius,
    required ArenaShape shape,
    required CenterObstacle obstacle,
    required double obstacleScale,
    List<(Offset, double)> occupied = const [],
  }) {
    bool valid(Offset p) =>
        fits(
          p,
          radius: radius,
          ballRadius: ballRadius,
          shape: shape,
          obstacle: obstacle,
          obstacleScale: obstacleScale,
        ) &&
        occupied.every(
          (other) => (p - other.$1).distance >= ballRadius + other.$2 + .01,
        );
    if (valid(desired)) return desired;
    Offset? best;
    var distance = double.infinity;
    // Fixed-order search consumes no gameplay RNG.
    for (var y = -20; y <= 20; y++) {
      for (var x = -20; x <= 20; x++) {
        final p = Offset(x * radius / 20, y * radius / 20);
        final d = (p - desired).distanceSquared;
        if (d < distance && valid(p)) {
          best = p;
          distance = d;
        }
      }
    }
    return best;
  }
}
