import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/math_utils.dart';

void main() {
  test('clampDouble clamps to range', () {
    expect(MathUtils.clampDouble(5, 0, 10), 5);
    expect(MathUtils.clampDouble(-5, 0, 10), 0);
    expect(MathUtils.clampDouble(15, 0, 10), 10);
  });

  test('distance computes euclidean distance', () {
    final d = MathUtils.distance(const Offset(0, 0), const Offset(3, 4));
    expect(d, closeTo(5.0, 1e-9));
  });

  test('rotateVector rotates by 90 degrees', () {
    final rotated = MathUtils.rotateVector(const Offset(1, 0), math.pi / 2);
    expect(rotated.dx, closeTo(0.0, 1e-9));
    expect(rotated.dy, closeTo(1.0, 1e-9));
  });
}
