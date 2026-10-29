import 'package:flutter/material.dart';
import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../domain/skill_library.dart';
import 'area_indicator.dart';

/// Debug geometry reads physical sources, never artwork scale/offsets.
class SkillDemoCollisionPainter extends CustomPainter {
  SkillDemoCollisionPainter(this.match);
  final MatchSimulationController match;
  @override
  void paint(Canvas canvas, Size size) {
    final p = match.powerUps;
    if (p == null) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.shortestSide / (2 * (match.arenaRadius + 10)));
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.yellowAccent;
    void circle(Offset at, double r) => paintAreaIndicator(
      canvas,
      at,
      r,
      AreaGuideStyle.dashed,
      Colors.yellowAccent,
      opacity: .9,
      width: 1.2,
    );
    circle(Offset.zero, match.arenaRadius);
    for (final b in match.state.balls) {
      if (!b.isEliminated) circle(b.position, b.radius);
    }
    for (final shot in p.projectiles) {
      circle(shot.position, p.projectileCollisionRadius(shot));
    }
    for (final fire in p.burningZones) {
      circle(fire.position, fire.radius);
    }
    for (final blast in p.explosions) {
      circle(blast.position, blast.radius);
    }
    for (final wall in p.fireWalls) {
      final d = Offset.fromDirection(wall.angle) * p.fieldRadius * 2.4;
      final path = Path()
        ..moveTo((wall.center - d).dx, (wall.center - d).dy)
        ..lineTo((wall.center + d).dx, (wall.center + d).dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = p.fieldRadius * .76
          ..color = Colors.yellowAccent.withValues(alpha: .25),
      );
    }
    for (final wall in p.spikeWalls) {
      for (final at in wall.spikePositions(p.fieldRadius * .96)) {
        circle(at, p.fieldRadius * .48);
      }
    }
    for (final goo in p.stickyGoo) {
      for (final at in goo.blobPositions(p.fieldRadius * .36)) {
        circle(at, p.fieldRadius * .48);
      }
    }
    for (final swamp in p.poisonSwamps) {
      for (final at in swamp.samplePositions(p.fieldRadius * .36)) {
        circle(at, p.fieldRadius * .5);
      }
    }
    for (final portal in p.portals) {
      circle(portal.position, p.fieldRadius);
    }
    for (final mine in p.mines) {
      circle(mine.position, p.fieldRadius);
    }
    for (final hazard in p.arenaThemeHazards) {
      final r = match.arenaRadius * .18;
      if (hazard.kind == ArenaThemeHazardKind.laserGate) {
        final d = Offset.fromDirection(hazard.angle, match.arenaRadius);
        canvas.drawLine(-d, d, pen);
      } else {
        circle(
          hazard.position,
          hazard.kind == ArenaThemeHazardKind.gravityWell ? r * 2.2 : r,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SkillDemoCollisionPainter oldDelegate) => true;
}
