import 'dart:math' as math;
import 'dart:ui';

import '../../match_setup/domain/match_config.dart';

/// Visible arena outline, shared by shape-dependent effects.
Path arenaBoundaryPath(double radius, ArenaShape shape) {
  final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
  return shape == ArenaShape.square
      ? (Path()..addRect(rect))
      : (Path()..addOval(rect));
}

/// Ray from the origin to the actual outer boundary.
Offset arenaBoundaryPoint(double angle, double radius, ArenaShape shape) {
  final direction = Offset(math.cos(angle), math.sin(angle));
  if (shape == ArenaShape.circle) return direction * radius;
  final extent = math.max(direction.dx.abs(), direction.dy.abs());
  return extent == 0 ? Offset.zero : direction * (radius / extent);
}

/// Outward wall normal; corners use the diagonal normal.
Offset arenaBoundaryNormal(Offset point, ArenaShape shape) {
  if (shape == ArenaShape.circle) {
    final length = point.distance;
    return length == 0 ? const Offset(1, 0) : point / length;
  }
  if (point.dx.abs() > point.dy.abs()) {
    return Offset(point.dx.sign, 0);
  }
  if (point.dy.abs() > point.dx.abs()) {
    return Offset(0, point.dy.sign);
  }
  final length = point.distance;
  return length == 0 ? const Offset(1, 0) : point / length;
}

/// Distance from a ball center to the nearest outer wall, not the center obstacle.
double arenaOuterWallDistance(Offset point, double radius, ArenaShape shape) {
  if (shape == ArenaShape.circle) return math.max(0, radius - point.distance);
  return math.max(0, radius - math.max(point.dx.abs(), point.dy.abs()));
}

bool inArenaBoundaryBand(Offset point, double radius, double bandWidth,
    ArenaShape shape) =>
    arenaOuterWallDistance(point, radius, shape) <= bandWidth;

/// Equally spaced points along the actual arena perimeter, including corners.
/// The square coordinate travels clockwise from the top-left corner.
List<Offset> arenaRimSamples(
  Offset center,
  double arenaRadius,
  double spacing,
  int count,
  ArenaShape shape,
) {
  if (count <= 0) return const [];
  if (shape == ArenaShape.circle) {
    final angle = math.atan2(center.dy, center.dx);
    return [
      for (var i = 0; i < count; i++)
        Offset.fromDirection(
          angle + (i - (count - 1) / 2) * spacing / arenaRadius,
          arenaRadius,
        ),
    ];
  }
  final r = arenaRadius;
  final wall = arenaBoundaryPoint(math.atan2(center.dy, center.dx), r, shape);
  double at;
  if (wall.dy <= -r + 1e-6) {
    at = wall.dx + r;
  } else if (wall.dx >= r - 1e-6) {
    at = 2 * r + wall.dy + r;
  } else if (wall.dy >= r - 1e-6) {
    at = 4 * r + r - wall.dx;
  } else {
    at = 6 * r + r - wall.dy;
  }
  return [
    for (var i = 0; i < count; i++)
      _squareRimPoint(at + (i - (count - 1) / 2) * spacing, r),
  ];
}

Offset _squareRimPoint(double distance, double r) {
  final t = ((distance % (8 * r)) + 8 * r) % (8 * r);
  if (t < 2 * r) return Offset(-r + t, -r);
  if (t < 4 * r) return Offset(r, -r + t - 2 * r);
  if (t < 6 * r) return Offset(r - (t - 4 * r), r);
  return Offset(-r, r - (t - 6 * r));
}


/// True only for an interior crossing of two finite segments.
///
/// Normalizing the coordinate differences before multiplying prevents the
/// determinant and the product of two orientation tests from overflowing for
/// very fast projectile paths. End-point touches remain non-crossings, as in
/// the original All-Out thread-cutting rules.
bool segmentsProperlyCross(Offset p1, Offset p2, Offset q1, Offset q2) {
  if (![p1.dx, p1.dy, p2.dx, p2.dy, q1.dx, q1.dy, q2.dx, q2.dy]
      .every((value) => value.isFinite)) {
        return false;
      }

  int orientation(Offset a, Offset b, Offset c) {
    final ax = b.dx - a.dx;
    final ay = b.dy - a.dy;
    final bx = c.dx - a.dx;
    final by = c.dy - a.dy;
    final scale = math.max(math.max(ax.abs(), ay.abs()),
        math.max(bx.abs(), by.abs()));
    if (scale == 0 || !scale.isFinite) return 0;
    final cross = (ax / scale) * (by / scale) -
        (ay / scale) * (bx / scale);
    return cross > 0 ? 1 : (cross < 0 ? -1 : 0);
  }

  final a = orientation(q1, q2, p1);
  final b = orientation(q1, q2, p2);
  if (a == 0 || b == 0 || a == b) return false;
  final c = orientation(p1, p2, q1);
  final d = orientation(p1, p2, q2);
  return c != 0 && d != 0 && c != d;
}

/// A diameter across the active shape, including diagonal square corners.
(Offset, Offset) arenaGateSegment(double angle, double radius, ArenaShape shape) {
  final end=arenaBoundaryPoint(angle,radius,shape);
  return (-end,end);
}
