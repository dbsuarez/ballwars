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
}
