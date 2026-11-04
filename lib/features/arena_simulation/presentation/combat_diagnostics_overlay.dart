import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../match_setup/domain/match_config.dart';
import '../application/match_simulation_controller.dart';
import '../domain/combat_targeting.dart';

/// Read-only debug view. Never selects targets or advances the simulation.
/// All geometry is in world coordinates; overlays cannot affect gameplay RNG.
class CombatDiagnosticsOverlay extends CustomPainter {
  CombatDiagnosticsOverlay(this.match, {this.worldRadius});

  final MatchSimulationController match;
  final double? worldRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = worldRadius ?? match.arenaRadius;
    final scale = size.shortestSide / (2 * (radius + 10));
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);
    final targetPen = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final blockedPen = Paint()
      ..color = Colors.deepOrangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final ballPen = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final obstacle = match.state.centerObstacle;
    final extent = match.arenaRadius * match.state.centerObstacleScale;
    if (obstacle != CenterObstacle.none) {
      if (obstacle == CenterObstacle.circle) {
        canvas.drawCircle(Offset.zero, extent, blockedPen);
      } else {
        canvas.drawRect(Rect.fromLTWH(-extent, -extent, 2 * extent, 2 * extent), blockedPen);
      }
    }
    for (final ball in match.state.balls) {
      if (ball.isEliminated || ball.isGhost) continue;
      canvas.drawCircle(ball.position, ball.radius, ballPen);
      final target = ball.aimTarget;
      if (target == null || target.isEliminated || target.isGhost ||
          !target.position.dx.isFinite || !target.position.dy.isFinite) {
        continue;
      }
      final blocked = CombatTargeting.centerObstacleBlocks(
        ball.position, target.position, obstacle, extent,
      );
      final pen = blocked ? blockedPen : targetPen;
      canvas.drawLine(ball.position, target.position, pen);
      canvas.drawCircle(target.position, target.radius + 3, pen);
    }
    final projectiles = match.powerUps?.projectiles;
    if (projectiles != null) {
      for (final shot in projectiles) {
        if (!shot.position.dx.isFinite || !shot.position.dy.isFinite) continue;
        canvas.drawCircle(shot.position, match.powerUps!.projectileCollisionRadius(shot), targetPen);
        final speed = shot.velocity.distance;
        if (speed > 0 && speed.isFinite) {
          final length = math.min(40.0, speed * .15);
          canvas.drawLine(shot.position, shot.position + shot.velocity / speed * length, targetPen);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CombatDiagnosticsOverlay oldDelegate) => true;
}
