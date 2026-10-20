import 'dart:math' as math;
import 'package:flutter/material.dart';

class MathUtils {
  MathUtils._();

  static double clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double distance(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  static Offset rotateVector(Offset v, double radians) {
    final cosR = math.cos(radians);
    final sinR = math.sin(radians);
    return Offset(
      v.dx * cosR - v.dy * sinR,
      v.dx * sinR + v.dy * cosR,
    );
  }

  /// Returns the [tEntry, tExit] parametric range (each clamped to [0, 1])
  /// along segment [p0]->[p1] where it lies within [radius] of [center], or
  /// null if the segment never overlaps the circle within that range.
  static List<double>? segmentCircleOverlapRange(
    Offset p0,
    Offset p1,
    Offset center,
    double radius,
  ) {
    final d = p1 - p0;
    final f = p0 - center;

    final a = d.dx * d.dx + d.dy * d.dy;
    if (a == 0) return null;
    final b = 2 * (f.dx * d.dx + f.dy * d.dy);
    final c = (f.dx * f.dx + f.dy * f.dy) - radius * radius;

    final discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return null;

    final sqrtDisc = math.sqrt(discriminant);
    var t1 = (-b - sqrtDisc) / (2 * a);
    var t2 = (-b + sqrtDisc) / (2 * a);
    if (t1 > t2) {
      final tmp = t1;
      t1 = t2;
      t2 = tmp;
    }

    t1 = clampDouble(t1, 0.0, 1.0);
    t2 = clampDouble(t2, 0.0, 1.0);
    if (t1 >= t2) return null;

    return [t1, t2];
  }

  /// Returns the parametric t (along segment [p0]->[p1]) where it crosses
  /// segment [q0]->[q1], or null if they don't cross within both segments.
  static double? segmentSegmentIntersectionT(
    Offset p0,
    Offset p1,
    Offset q0,
    Offset q1,
  ) {
    final r = p1 - p0;
    final s = q1 - q0;
    final rxs = r.dx * s.dy - r.dy * s.dx;
    if (rxs == 0) return null;

    final qp = q0 - p0;
    final t = (qp.dx * s.dy - qp.dy * s.dx) / rxs;
    final u = (qp.dx * r.dy - qp.dy * r.dx) / rxs;
    if (t < 0 || t > 1 || u < 0 || u > 1) return null;

    return t;
  }

  /// Whether [angle] falls within [minAngle]..[maxAngle] going the forward
  /// (increasing) direction, correctly handling a range that wraps through
  /// 0/2*pi and spans that are wider than pi (reflex wedges).
  static bool isAngleInRange(double angle, double minAngle, double maxAngle) {
    final twoPi = 2 * math.pi;
    double normalize(double a) {
      var result = a % twoPi;
      if (result < 0) result += twoPi;
      return result;
    }

    final normAngle = normalize(angle);
    final normMin = normalize(minAngle);
    final normMax = normalize(maxAngle);

    if (normMin <= normMax) {
      return normAngle >= normMin && normAngle <= normMax;
    }
    return normAngle >= normMin || normAngle <= normMax;
  }

  /// Returns the squared distance from [point] to the line segment [a]-[b].
  static double distancePointToSegmentSquared(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final ap = point - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 == 0) return ap.dx * ap.dx + ap.dy * ap.dy;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
    if (t < 0) return ap.dx * ap.dx + ap.dy * ap.dy;
    if (t > 1) {
      final bp = point - b;
      return bp.dx * bp.dx + bp.dy * bp.dy;
    }
    final projection = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    final diff = point - projection;
    return diff.dx * diff.dx + diff.dy * diff.dy;
  }
}
