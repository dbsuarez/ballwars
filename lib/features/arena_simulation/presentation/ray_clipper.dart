import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/math_utils.dart';
import '../domain/simulation_ball.dart';

/// A ball's currently owned territory, as an angular wedge fanning out from
/// its current position to the rim points of its first/last owned sector.
class Wedge {
  final Offset apex;
  final Offset edge1;
  final Offset edge2;
  final double minAngle;
  final double maxAngle;

  const Wedge({
    required this.apex,
    required this.edge1,
    required this.edge2,
    required this.minAngle,
    required this.maxAngle,
  });
}

/// Pure geometry for cutting a ball's laser rays wherever they cross another
/// ball's body or currently-owned territory wedge. Kept free of Canvas/paint
/// concerns so it can be unit tested directly.
class RayClipper {
  RayClipper._();

  static const double ballGlowPadding = 4.0;

  /// Computes each ball's current owned territory as a wedge. Assumes each
  /// ball's owned sectors form a single contiguous run (guaranteed by
  /// TerritoryEngine.resolveSteal).
  static Map<String, Wedge> computeWedges({
    required List<String> sectorOwners,
    required List<SimulationBall> balls,
    required double rimAngle,
    required double arenaRadius,
  }) {
    final total = sectorOwners.length;
    final sectorAngleStep = 2 * math.pi / total;
    final wedges = <String, Wedge>{};

    Offset rimPointAt(int index) {
      final theta = rimAngle + (index * sectorAngleStep);
      return Offset(math.cos(theta), math.sin(theta)) * arenaRadius;
    }

    for (var i = 0; i < total; i++) {
      final id = sectorOwners[i];
      if (id.isEmpty) continue;
      final prev = (i - 1 + total) % total;
      if (sectorOwners[prev] == id) continue; // not the start of this ball's run

      var end = i;
      while (sectorOwners[(end + 1) % total] == id) {
        end = (end + 1) % total;
      }

      final ownerBall = balls.where((b) => b.config.id == id);
      if (ownerBall.isEmpty) continue;

      wedges[id] = Wedge(
        apex: ownerBall.first.position,
        edge1: rimPointAt(i),
        edge2: rimPointAt(end),
        minAngle: rimAngle + i * sectorAngleStep,
        maxAngle: rimAngle + end * sectorAngleStep,
      );
    }

    return wedges;
  }

  /// Splits a ray into the sub-segments that are NOT covered by any other
  /// ball's body or territory wedge, so the ray visibly cuts wherever an
  /// opposing ball or its owned fan crosses it, while staying visible
  /// before and after that crossing, and always connecting to its own
  /// owner ball regardless of whose wedge that ball is standing in.
  static List<List<Offset>> visibleRaySegments({
    required Offset origin,
    required Offset target,
    required String ownerId,
    required double ownerRadius,
    required List<SimulationBall> balls,
    required Map<String, Wedge> wedges,
  }) {
    final blocked = <List<double>>[];
    for (final ball in balls) {
      if (ball.config.id == ownerId) continue;
      final range = MathUtils.segmentCircleOverlapRange(origin, target, ball.position, ball.radius);
      if (range != null) blocked.add(range);
    }

    for (final entry in wedges.entries) {
      if (entry.key == ownerId) continue;
      blocked.addAll(blockedRangesForWedge(origin, target, entry.value));
    }

    final rayLength = (target - origin).distance;
    if (rayLength > 0 && blocked.isNotEmpty) {
      final minVisibleT = ((ownerRadius + ballGlowPadding) / rayLength).clamp(0.0, 1.0);
      final trimmed = <List<double>>[];
      for (final range in blocked) {
        if (range[1] <= minVisibleT) continue;
        trimmed.add([math.max(range[0], minVisibleT), range[1]]);
      }
      blocked
        ..clear()
        ..addAll(trimmed);
    }

    if (blocked.isEmpty) return [[origin, target]];

    blocked.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<double>>[];
    for (final range in blocked) {
      if (merged.isNotEmpty && range[0] <= merged.last[1]) {
        merged.last[1] = math.max(merged.last[1], range[1]);
      } else {
        merged.add([range[0], range[1]]);
      }
    }

    final segments = <List<Offset>>[];
    final delta = target - origin;
    var cursor = 0.0;
    for (final range in merged) {
      if (range[0] > cursor) {
        segments.add([origin + delta * cursor, origin + delta * range[0]]);
      }
      cursor = range[1];
    }
    if (cursor < 1.0) {
      segments.add([origin + delta * cursor, origin + delta * 1.0]);
    }
    return segments;
  }

  /// Finds the t-ranges along segment [origin]->[target] that fall inside
  /// [wedge]'s angular span as seen from its apex, by crossing the ray
  /// against the wedge's two boundary edges and sampling each resulting
  /// sub-interval's midpoint (robust to any number/order of crossings).
  static List<List<double>> blockedRangesForWedge(Offset origin, Offset target, Wedge wedge) {
    final tValues = <double>[0.0, 1.0];
    final t1 = MathUtils.segmentSegmentIntersectionT(origin, target, wedge.apex, wedge.edge1);
    if (t1 != null) tValues.add(t1);
    final t2 = MathUtils.segmentSegmentIntersectionT(origin, target, wedge.apex, wedge.edge2);
    if (t2 != null) tValues.add(t2);
    tValues.sort();

    final delta = target - origin;
    final blocked = <List<double>>[];
    for (var i = 0; i < tValues.length - 1; i++) {
      final segStart = tValues[i];
      final segEnd = tValues[i + 1];
      if (segEnd - segStart < 1e-9) continue;

      final mid = (segStart + segEnd) / 2;
      final midPoint = origin + delta * mid;
      final angle = math.atan2(midPoint.dy - wedge.apex.dy, midPoint.dx - wedge.apex.dx);
      if (MathUtils.isAngleInRange(angle, wedge.minAngle, wedge.maxAngle)) {
        blocked.add([segStart, segEnd]);
      }
    }
    return blocked;
  }
}
