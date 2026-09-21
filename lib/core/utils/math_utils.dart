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

  /// Returns the point along segment [p0]->[p1] where it first enters the
  /// circle at [center] with the given [radius] (nearest to [p0]), or null
  /// if the segment never enters the circle within [0, 1].
  static Offset? segmentCircleIntersection(
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
    final t1 = (-b - sqrtDisc) / (2 * a);
    final t2 = (-b + sqrtDisc) / (2 * a);

    double? t;
    if (t1 >= 0 && t1 <= 1) {
      t = t1;
    } else if (t2 >= 0 && t2 <= 1 && c < 0) {
      // p0 starts inside the circle: clip to the segment start.
      t = 0;
    } else {
      return null;
    }

    return p0 + d * t;
  }
}
