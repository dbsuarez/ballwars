import 'dart:math' as math;
import 'dart:ui';

import '../../match_setup/domain/match_config.dart';
import 'simulation_ball.dart';

/// Deterministic target selection shared by aimed attacks and diagnostics.
/// This never mutates a ball or consumes simulation randomness.
class CombatTargeting {
  const CombatTargeting._();

  /// Keep a valid target until another opponent is meaningfully nearer.
  static const double retentionRatio = 1.20;

  static SimulationBall? select({
    required Offset origin,
    required Iterable<SimulationBall> candidates,
    SimulationBall? owner,
    SimulationBall? previous,
    bool Function(SimulationBall)? isEligible,
    Set<SimulationBall> excluded = const {},
    CenterObstacle obstacle = CenterObstacle.none,
    double obstacleExtent = 0,
    bool preferClearLine = true,
    bool legacyOrder = false,
  }) {
    if (!origin.dx.isFinite || !origin.dy.isFinite) return null;
    final eligible = <SimulationBall>[];
    for (final ball in candidates) {
      if (identical(ball, owner) ||
          excluded.contains(ball) ||
          (isEligible != null && !isEligible(ball)) ||
          ball.isEliminated ||
          ball.isGhost ||
          !ball.position.dx.isFinite ||
          !ball.position.dy.isFinite) {
        continue;
      }
      eligible.add(ball);
    }
    if (eligible.isEmpty) return null;

    // Prefer unoccluded opponents, but preserve legacy targeting when every
    // opponent is behind the center obstacle (rather than disabling attacks).
    final visible = preferClearLine && !legacyOrder
        ? eligible
              .where(
                (ball) => !centerObstacleBlocks(
                  origin,
                  ball.position,
                  obstacle,
                  obstacleExtent,
                ),
              )
              .toList()
        : eligible;
    final pool = visible.isNotEmpty ? visible : eligible;
    SimulationBall? nearest;
    var nearestDistance = double.infinity;
    for (final ball in pool) {
      final distance = (ball.position - origin).distanceSquared;
      if (!distance.isFinite) continue;
      if (distance < nearestDistance ||
          (!legacyOrder &&
              distance == nearestDistance &&
              nearest != null &&
              ball.config.id.compareTo(nearest.config.id) < 0)) {
        nearest = ball;
        nearestDistance = distance;
      }
    }
    if (legacyOrder ||
        previous == null ||
        nearest == null ||
        !pool.contains(previous)) {
      return nearest;
    }
    final previousDistance = (previous.position - origin).distanceSquared;
    if (!previousDistance.isFinite) return nearest;
    // Compare squared distances to avoid square roots on every step.
    return previousDistance <= nearestDistance * retentionRatio * retentionRatio
        ? previous
        : nearest;
  }

  /// True only if the *interior* of the central wall obstructs the segment.
  /// Endpoints touching the rim are not considered blocked.
  static bool centerObstacleBlocks(
    Offset from,
    Offset to,
    CenterObstacle obstacle,
    double extent,
  ) {
    if (obstacle == CenterObstacle.none ||
        extent <= 0 ||
        !extent.isFinite ||
        !from.dx.isFinite ||
        !from.dy.isFinite ||
        !to.dx.isFinite ||
        !to.dy.isFinite) {
      return false;
    }
    final delta = to - from;
    if (!delta.dx.isFinite || !delta.dy.isFinite) return false;
    if (obstacle == CenterObstacle.circle) {
      final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
      if (lengthSquared == 0 || !lengthSquared.isFinite) return false;
      final t = (-(from.dx * delta.dx + from.dy * delta.dy) / lengthSquared)
          .clamp(0.0, 1.0);
      final nearest = from + delta * t;
      return nearest.dx * nearest.dx + nearest.dy * nearest.dy <
          extent * extent;
    }
    // Segment vs open square (-extent, extent)^2. Shrinking the wall by
    // numerical tolerance avoids treating a grazing edge as an obstruction.
    final bound = extent - math.max(1e-9, extent * 1e-9);
    if (bound <= 0) return false;
    var enter = 0.0;
    var exit = 1.0;
    for (var axis = 0; axis < 2; axis++) {
      final start = axis == 0 ? from.dx : from.dy;
      final direction = axis == 0 ? delta.dx : delta.dy;
      if (direction == 0) {
        if (start.abs() >= bound) return false;
        continue;
      }
      final a = (-bound - start) / direction;
      final b = (bound - start) / direction;
      enter = math.max(enter, math.min(a, b));
      exit = math.min(exit, math.max(a, b));
      if (enter >= exit) return false;
    }
    return exit > 0 && enter < 1;
  }
}
