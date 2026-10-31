import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/arena_boundary_geometry.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  test('square ray intersects flat wall instead of circular arc', () {
    final point = arenaBoundaryPoint(math.pi / 4, 100, ArenaShape.square);
    expect(point.dx, closeTo(100, 0.0001));
    expect(point.dy, closeTo(100, 0.0001));
    expect(arenaBoundaryPoint(math.pi / 4, 100, ArenaShape.circle).dx,
        closeTo((math.sqrt(0.5)) * 100, 0.0001));
  });

  test('square hazard band reaches walls and corners', () {
    expect(inArenaBoundaryBand(const Offset(90, 0), 100, 15, ArenaShape.square), isTrue);
    expect(inArenaBoundaryBand(const Offset(90, 90), 100, 15, ArenaShape.square), isTrue);
    expect(inArenaBoundaryBand(const Offset(70, 70), 100, 15, ArenaShape.square), isFalse);
    expect(inArenaBoundaryBand(const Offset(70, 70), 100, 15, ArenaShape.circle), isTrue);
  });

  test('square rim normals align with flat faces', () {
    expect(arenaBoundaryNormal(const Offset(100, 20), ArenaShape.square), const Offset(1, 0));
    expect(arenaBoundaryNormal(const Offset(20, -100), ArenaShape.square), const Offset(0, -1));
    final corner = arenaBoundaryNormal(const Offset(100, 100), ArenaShape.square);
    expect(corner.dx, closeTo((math.sqrt(0.5)), 0.0001));
    expect(corner.dy, closeTo((math.sqrt(0.5)), 0.0001));
  });

  test('outline shape uses rectangular bounds for square', () {
    final bounds = arenaBoundaryPath(100, ArenaShape.square).getBounds();
    expect(bounds, const Rect.fromLTRB(-100, -100, 100, 100));
  });
  test('square rim trap samples follow flat walls through corners', () {
    final samples = arenaRimSamples(const Offset(100, -80), 100, 15, 15, ArenaShape.square);
    expect(samples, hasLength(15));
    for (final point in samples) {
      expect(math.max(point.dx.abs(), point.dy.abs()), closeTo(100, 0.0001));
    }
    for (var i = 1; i < samples.length; i++) {
      final delta = samples[i] - samples[i - 1];
      expect(delta.dx.abs() + delta.dy.abs(), closeTo(15, 0.0001));
    }
  });

  test('circular trap samples remain on circular rim', () {
    final samples = arenaRimSamples(const Offset(70, 70), 100, 5, 15, ArenaShape.circle);
    expect(samples, hasLength(15));
    for (final point in samples) {
      expect(point.distance, closeTo(100, 0.0001));
    }
  });

}
