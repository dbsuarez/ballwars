import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/simulation_state.dart';
import '../domain/simulation_ball.dart';
import '../domain/particle_system.dart';
import 'ball_face_painter.dart';

class ArenaPainter extends CustomPainter {
  final SimulationState state;
  final double arenaRadius;
  final double rimAngle;

  /// Sparks and particles. Off only hides them: they are still simulated,
  /// so the match plays out the same either way.
  final bool showEffects;

  static const double _ballGlowPadding = 4.0;
  static const double _rimMargin = 10.0;

  ArenaPainter({
    required this.state,
    required this.arenaRadius,
    required this.rimAngle,
    this.showEffects = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Leave room for the rim's stroke and glow so they aren't clipped at the edges.
    final scale = size.shortestSide / (2 * (arenaRadius + _rimMargin));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);

    _paintBackground(canvas);
    _paintRim(canvas);
    _paintFanLines(canvas);
    _paintBeamAttack(canvas);
    if (showEffects) _paintParticles(canvas);
    // Depth order: sort balls by distance from center (farthest drawn first = behind)
    final sortedBalls = List<SimulationBall>.from(state.balls)
      ..sort((a, b) => b.position.distance.compareTo(a.position.distance));
    for (final ball in sortedBalls) {
      if (ball.isEliminated) continue;
      _paintSingleBall(canvas, ball);
    }
    _paintFloatingText(canvas);

    canvas.restore();
  }

  void _paintBackground(Canvas canvas) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        arenaRadius,
        [AppColors.arenaDiscStart, AppColors.arenaDiscEnd],
      );
    canvas.drawCircle(Offset.zero, arenaRadius, paint);

    // Halftone dot field (faint dots inside arena, visible under lit areas)
    _paintHalftoneDots(canvas);
  }

  void _paintHalftoneDots(Canvas canvas) {
    const double dotRadius = 0.8;
    const double spacing = 8.0;
    const int gridSize = 80; // Covers ~80x80 = 6400 dots

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    for (int gx = -gridSize ~/ 2; gx < gridSize ~/ 2; gx++) {
      for (int gy = -gridSize ~/ 2; gy < gridSize ~/ 2; gy++) {
        final x = gx * spacing;
        final y = gy * spacing;
        // Only draw dots inside arena radius
        if (x * x + y * y <= arenaRadius * arenaRadius) {
          canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), dotRadius, paint);
        }
      }
    }
  }

  void _paintRim(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = AppColors.rimGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
    canvas.drawCircle(Offset.zero, arenaRadius, paint);
  }

  /// Paints every ball's lines: rim anchor to the owner's center.
  /// Plain strokes for now; glow/haze effects come later.
  void _paintFanLines(Canvas canvas) {
    for (final ball in state.balls) {
      if (ball.isEliminated || ball.fanLines.isEmpty) continue;

      final path = Path();
      for (final line in ball.fanLines) {
        if (!line.isActive) continue;
        path.moveTo(line.startPoint.dx, line.startPoint.dy);
        path.lineTo(ball.position.dx, ball.position.dy);
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = ball.config.primaryColor.withValues(alpha: 0.85);
      canvas.drawPath(path, paint);
    }
  }

  void _paintBeamAttack(Canvas canvas) {
    if (state.beamPhase == 0 || state.beamFirer == null || state.beamTarget == null) return;

    final firer = state.beamFirer!;
    final target = state.beamTarget!;

    // Beam direction from firer to target
    final beamAngle = math.atan2(
      target.position.dy - firer.position.dy,
      target.position.dx - firer.position.dx,
    );

    // Extend ray past target to arena rim
    final endPt = Offset(math.cos(beamAngle) * arenaRadius, math.sin(beamAngle) * arenaRadius);

    Color beamColor;
    double alpha;
    double strokeWidth;

    switch (state.beamPhase) {
      case 1: // Solid ray
        beamColor = firer.config.primaryColor;
        alpha = 1.0;
        strokeWidth = 1.0;
        break;
      case 2: // Dotted ray
        beamColor = firer.config.primaryColor;
        alpha = 0.7;
        strokeWidth = 1.0;
        break;
      case 3: // Haze
        beamColor = firer.config.primaryColor;
        alpha = 0.3;
        strokeWidth = 2.0;
        break;
      default:
        return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = beamColor.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    if (state.beamPhase == 2) {
      // Dotted line - draw segments
      const segmentLength = 8.0;
      const gapLength = 8.0;
      double distance = 0.0;
      final totalLength = (endPt - firer.position).distance;

      while (distance < totalLength) {
        final startRatio = distance / totalLength;
        final endRatio = (distance + segmentLength) / totalLength;
        if (endRatio > 1.0) break;

        final startPt = Offset.lerp(firer.position, endPt, startRatio)!;
        final endPtSeg = Offset.lerp(firer.position, endPt, endRatio)!;
        canvas.drawLine(startPt, endPtSeg, paint);

        distance += segmentLength + gapLength;
      }
    } else {
      // Solid or haze - draw full line
      canvas.drawLine(firer.position, endPt, paint);
    }

    // Target keeps small cone while pinned (phase 1-3)
    if (state.beamPhase <= 3 && state.beamPhase > 0) {
      _paintTargetCone(canvas, target, beamAngle);
    }
  }

  void _paintTargetCone(Canvas canvas, SimulationBall target, double beamAngle) {
    // Small cone at target (opposite direction of beam)
    final coneAngle = beamAngle + math.pi;
    final halfWidth = 0.15; // Small fixed width

    final path = Path();
    path.moveTo(target.position.dx, target.position.dy);
    final rimAngle1 = coneAngle - halfWidth;
    final rimPt1 = Offset(math.cos(rimAngle1) * arenaRadius, math.sin(rimAngle1) * arenaRadius);
    path.lineTo(rimPt1.dx, rimPt1.dy);
    path.arcTo(Rect.fromCircle(center: Offset.zero, radius: arenaRadius), rimAngle1, halfWidth * 2, false);
    path.lineTo(target.position.dx, target.position.dy);
    path.close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = target.config.primaryColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawPath(path, paint);
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in state.particles.particles) {
      if (particle is Particle) {
        final lifeRatio = 1.0 - (particle.age / particle.lifespan).clamp(0.0, 1.0);
        final hotness = (lifeRatio * 1.6).clamp(0.0, 1.0);
        final sparkColor = Color.lerp(particle.color, Colors.white, hotness)!;
        final paint = Paint()
          ..color = sparkColor.withValues(alpha: lifeRatio)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        canvas.drawCircle(particle.position, particle.baseRadius * lifeRatio, paint);
      } else if (particle is RimArcParticle) {
        // Render thin white arc along rim
        final (startPt, endPt) = particle.getArcSegment();
        final lifeRatio = 1.0 - (particle.age / particle.lifespan).clamp(0.0, 1.0);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(alpha: lifeRatio)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);
        canvas.drawLine(startPt, endPt, paint);
      }
    }
  }

  void _paintSingleBall(Canvas canvas, SimulationBall ball) {
    if (ball.isEliminated) return;

    // Glow with edge compression (glow compresses against arena edge instead of clipping)
    final distToCenter = ball.position.distance;
    final edgeDist = arenaRadius - distToCenter;
    final glowRadius = ball.radius + _ballGlowPadding;
    final effectiveGlowRadius = edgeDist < glowRadius ? glowRadius * (edgeDist / glowRadius).clamp(0.0, 1.0) : glowRadius;

    final glowPaint = Paint()
      ..color = ball.config.glowColor.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6.0);
    canvas.drawCircle(ball.position, effectiveGlowRadius, glowPaint);

    BallFacePainter.paint(canvas, ball.position, ball.radius, ball.config, ball.cachedUiImage);
  }

  void _paintFloatingText(Canvas canvas) {
    for (final text in state.floatingTexts.items) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: text.color.withValues(alpha: text.opacity),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, text.position);
    }
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}