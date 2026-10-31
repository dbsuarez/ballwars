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
