import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/ray_clipper.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

SimulationBall _ball(String id, Offset position) {
  return SimulationBall(
    config: CustomBall(id: id, name: id, primaryColor: Colors.red, glowColor: Colors.pink),
    position: position,
    velocity: Offset.zero,
    radius: 20.8,
    lineCount: 0,
  );
}

void main() {
  group('computeWedges', () {
    test('produces a wedge only for the ball owning that contiguous run', () {
      final owners = List<String>.filled(360, 'r');
      for (var i = 45; i <= 90; i++) {
        owners[i] = 'u';
      }
      final balls = [_ball('r', const Offset(-80, 60)), _ball('u', const Offset(90, -20))];

      final wedges = RayClipper.computeWedges(
        sectorOwners: owners,
        balls: balls,
        rimAngle: 0,
        arenaRadius: 260,
      );

      expect(wedges.keys, containsAll(['r', 'u']));
      expect(wedges['u']!.minAngle, closeTo(45 * math.pi / 180, 1e-9));
      expect(wedges['u']!.maxAngle, closeTo(90 * math.pi / 180, 1e-9));
    });
  });

  group('visibleRaySegments', () {
    test('a ray pointing away from a small opposing wedge is not blocked', () {
      // Reproduces the reported scenario: R owns a wide arc (mostly "up"),
      // U owns a small down-right sliver (45-90 degrees). A ray from R
      // straight up (270 degrees) points away from U's wedge entirely and
      // must not be cut.
      final owners = List<String>.filled(360, 'r');
      for (var i = 45; i <= 90; i++) {
        owners[i] = 'u';
      }
      final rBall = _ball('r', const Offset(-80, 60));
      final uBall = _ball('u', const Offset(90, -20));
      final balls = [rBall, uBall];

      final wedges = RayClipper.computeWedges(
        sectorOwners: owners,
        balls: balls,
        rimAngle: 0,
        arenaRadius: 260,
      );

      const theta = 270 * math.pi / 180;
      final rimPoint = Offset(math.cos(theta), math.sin(theta)) * 260;

      final segments = RayClipper.visibleRaySegments(
        origin: rBall.position,
        target: rimPoint,
        ownerId: 'r',
        ownerRadius: rBall.radius,
        balls: balls,
        wedges: wedges,
      );

      expect(segments.length, 1);
      expect(segments.first[0], rBall.position);
      expect(segments.first[1], rimPoint);
    });

    test('a ray whose path crosses an opposing wedge is cut there, but stays connected to its own ball', () {
      // U sits exactly on R's straight path to its own (unrelated) target,
      // and owns a wedge pointing back toward where R is coming from (170
      // to 190 degrees, i.e. leftward) -- so the segment of R's ray between
      // its own ball and U must be cut, while the far side (past U, toward
      // R's own target) must remain visible.
      final owners = List<String>.filled(360, 'r');
      for (var i = 170; i <= 190; i++) {
        owners[i] = 'u';
      }
      final rBall = _ball('r', const Offset(-200, 0));
      final uBall = _ball('u', const Offset(0, 0));
      final balls = [rBall, uBall];

      final wedges = RayClipper.computeWedges(
        sectorOwners: owners,
        balls: balls,
        rimAngle: 0,
        arenaRadius: 260,
      );

      const theta = 0 * math.pi / 180; // R's own sector, straight right.
      final rimPoint = Offset(math.cos(theta), math.sin(theta)) * 260;

      final segments = RayClipper.visibleRaySegments(
        origin: rBall.position,
        target: rimPoint,
        ownerId: 'r',
        ownerRadius: rBall.radius,
        balls: balls,
        wedges: wedges,
      );

      // Must be cut into at least 2 pieces (blocked between R and U).
      expect(segments.length, greaterThanOrEqualTo(2));
      // The first segment must still touch R's own ball.
      expect(segments.first[0], rBall.position);
      // The last segment must still reach R's actual target rim point.
      expect(segments.last[1], rimPoint);
    });
  });
}
