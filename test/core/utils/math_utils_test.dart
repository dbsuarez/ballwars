import 'dart:math' as math;
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

  group('segmentCircleOverlapRange', () {
    test('returns null when the segment never reaches the circle', () {
      final range = MathUtils.segmentCircleOverlapRange(
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(100, 0),
        5,
      );
      expect(range, isNull);
    });

    test('returns the entry/exit t values when the segment passes through the circle', () {
      final range = MathUtils.segmentCircleOverlapRange(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(50, 0),
        10,
      );
      expect(range, isNotNull);
      expect(range![0], closeTo(0.4, 1e-9)); // enters at x=40 -> t=0.4
      expect(range[1], closeTo(0.6, 1e-9)); // exits at x=60 -> t=0.6
    });

    test('clamps to segment start when the circle starts before it', () {
      final range = MathUtils.segmentCircleOverlapRange(
        const Offset(50, 0),
        const Offset(100, 0),
        const Offset(45, 0),
        10,
      );
      expect(range, isNotNull);
      expect(range![0], 0.0);
    });

    test('clamps to segment end when the circle extends past it', () {
      final range = MathUtils.segmentCircleOverlapRange(
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(55, 0),
        10,
      );
      expect(range, isNotNull);
      expect(range![1], 1.0);
    });

    test('returns null when the circle is entirely behind the segment start', () {
      final range = MathUtils.segmentCircleOverlapRange(
        const Offset(50, 0),
        const Offset(100, 0),
        const Offset(0, 0),
        10,
      );
      expect(range, isNull);
    });

    test('returns null when the circle is entirely past the segment end', () {
      final range = MathUtils.segmentCircleOverlapRange(
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(50, 0),
        10,
      );
      expect(range, isNull);
    });
  });

  group('segmentSegmentIntersectionT', () {
    test('returns t where two crossing segments intersect', () {
      final t = MathUtils.segmentSegmentIntersectionT(
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(5, -5),
        const Offset(5, 5),
      );
      expect(t, closeTo(0.5, 1e-9));
    });

    test('returns null for parallel segments', () {
      final t = MathUtils.segmentSegmentIntersectionT(
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(0, 5),
        const Offset(10, 5),
      );
      expect(t, isNull);
    });

    test('returns null when segments do not actually cross within both bounds', () {
      final t = MathUtils.segmentSegmentIntersectionT(
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(20, -5),
        const Offset(20, 5),
      );
      expect(t, isNull);
    });
  });

  group('isAngleInRange', () {
    test('handles a normal (non-wrapping) range', () {
      expect(MathUtils.isAngleInRange(1.0, 0.5, 1.5), isTrue);
      expect(MathUtils.isAngleInRange(2.0, 0.5, 1.5), isFalse);
    });

    test('handles a range that wraps through 0/2pi (wide wedge)', () {
      // Range from 5.5 rad wrapping through 0 to 1.0 rad (a >180 degree span).
      expect(MathUtils.isAngleInRange(0.1, 5.5, 1.0), isTrue);
      expect(MathUtils.isAngleInRange(6.0, 5.5, 1.0), isTrue);
      expect(MathUtils.isAngleInRange(3.0, 5.5, 1.0), isFalse);
    });

    test('normalizes angles outside [0, 2pi)', () {
      final twoPi = 2 * math.pi;
      expect(MathUtils.isAngleInRange(-0.1, 0.0, 1.0), isFalse);
      expect(MathUtils.isAngleInRange(twoPi + 0.1, 0.0, 1.0), isTrue);
    });
  });
}
