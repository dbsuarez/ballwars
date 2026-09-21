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

  group('segmentCircleIntersection', () {
    test('returns null when the segment never reaches the circle', () {
      final hit = MathUtils.segmentCircleIntersection(
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(100, 0),
        5,
      );
      expect(hit, isNull);
    });

    test('returns the nearest entry point when the segment passes through the circle', () {
      final hit = MathUtils.segmentCircleIntersection(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(50, 0),
        10,
      );
      expect(hit, isNotNull);
      expect(hit!.dx, closeTo(40.0, 1e-9));
      expect(hit.dy, closeTo(0.0, 1e-9));
    });

    test('returns null when the circle is behind the segment start (t < 0)', () {
      final hit = MathUtils.segmentCircleIntersection(
        const Offset(50, 0),
        const Offset(100, 0),
        const Offset(0, 0),
        10,
      );
      expect(hit, isNull);
    });

    test('returns null when the circle starts after the segment end (t > 1)', () {
      final hit = MathUtils.segmentCircleIntersection(
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(50, 0),
        10,
      );
      expect(hit, isNull);
    });

    test('origin already inside the circle clips to the segment start', () {
      final hit = MathUtils.segmentCircleIntersection(
        const Offset(50, 0),
        const Offset(100, 0),
        const Offset(55, 0),
        10,
      );
      expect(hit, isNotNull);
      expect(hit!.dx, closeTo(50.0, 1e-9));
      expect(hit.dy, closeTo(0.0, 1e-9));
    });
  });
}
