import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/math_utils.dart';
import '../domain/simulation_state.dart';

class ArenaPainter extends CustomPainter {
  final SimulationState state;
  final double arenaRadius;
  final double rimAngle;

  ArenaPainter({
    required this.state,
    required this.arenaRadius,
    required this.rimAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.shortestSide / (2 * arenaRadius);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);

    _paintBackground(canvas);
    _paintRim(canvas);
    _paintLaserRays(canvas);
    _paintParticles(canvas);
    _paintBallTokens(canvas);
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
  }

  void _paintRim(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = AppColors.rimGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
    canvas.drawCircle(Offset.zero, arenaRadius, paint);
  }

  void _paintLaserRays(Canvas canvas) {
    final owners = state.territory.sectorOwners;
    for (var i = 0; i < owners.length; i++) {
      final ownerId = owners[i];
      if (ownerId.isEmpty) continue;
      final ownerBall = state.balls.where((b) => b.config.id == ownerId);
      if (ownerBall.isEmpty) continue;
      final ball = ownerBall.first;

      final theta = rimAngle + (i * (2 * math.pi / 360));
      final rimPoint = Offset(math.cos(theta), math.sin(theta)) * arenaRadius;
      final endPoint = _clipRayAgainstOtherBalls(ball.position, rimPoint, ownerId);

      final paint = Paint()
        ..color = ball.config.primaryColor.withOpacity(0.85)
        ..strokeWidth = 1.2;
      canvas.drawLine(ball.position, endPoint, paint);
    }
  }

  /// Cuts a laser ray short at the point it first enters another ball's
  /// body, so the ray appears blocked instead of drawing through it.
  Offset _clipRayAgainstOtherBalls(Offset origin, Offset target, String ownerId) {
    var closestPoint = target;
    var closestDistanceSquared = (target - origin).distanceSquared;

    for (final ball in state.balls) {
      if (ball.config.id == ownerId) continue;
      final hit = MathUtils.segmentCircleIntersection(origin, target, ball.position, ball.radius);
      if (hit == null) continue;

      final distanceSquared = (hit - origin).distanceSquared;
      if (distanceSquared < closestDistanceSquared) {
        closestDistanceSquared = distanceSquared;
        closestPoint = hit;
      }
    }

    return closestPoint;
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in state.particles.particles) {
      final lifeRatio = 1.0 - (particle.age / particle.lifespan).clamp(0.0, 1.0);
      final paint = Paint()..color = particle.color.withOpacity(lifeRatio);
      canvas.drawCircle(particle.position, 3.0 * lifeRatio, paint);
    }
  }

  void _paintBallTokens(Canvas canvas) {
    for (final ball in state.balls) {
      final glowPaint = Paint()
        ..color = ball.config.glowColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6.0);
      canvas.drawCircle(ball.position, ball.radius + 4, glowPaint);

      final fillPaint = Paint()..color = ball.config.primaryColor;
      canvas.drawCircle(ball.position, ball.radius, fillPaint);

      final image = ball.cachedUiImage;
      if (image != null) {
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: ball.position, radius: ball.radius)));
        final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
        final dstRect = Rect.fromCircle(center: ball.position, radius: ball.radius);
        canvas.drawImageRect(image, srcRect, dstRect, Paint());
        canvas.restore();
      } else {
        final textPainter = TextPainter(
          text: TextSpan(
            text: ball.config.name.isNotEmpty ? ball.config.name.substring(0, 1).toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontSize: ball.radius, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          ball.position - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white;
      canvas.drawCircle(ball.position, ball.radius, borderPaint);
    }
  }

  void _paintFloatingText(Canvas canvas) {
    for (final text in state.floatingTexts.items) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: text.color.withOpacity(text.opacity),
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
