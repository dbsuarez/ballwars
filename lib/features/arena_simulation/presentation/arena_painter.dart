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

  static const double _ballGlowPadding = 4.0;

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

      final paint = Paint()
        ..color = ball.config.primaryColor.withOpacity(0.85)
        ..strokeWidth = 1.2;

      for (final segment in _visibleRaySegments(ball.position, rimPoint, ownerId)) {
        canvas.drawLine(segment[0], segment[1], paint);
      }
    }
  }

  /// Splits a ray into the sub-segments that are NOT covered by any other
  /// ball's body, so the ray visibly cuts wherever an opposing ball's path
  /// crosses it, while staying visible before and after that crossing.
  List<List<Offset>> _visibleRaySegments(Offset origin, Offset target, String ownerId) {
    final blocked = <List<double>>[];
    for (final ball in state.balls) {
      if (ball.config.id == ownerId) continue;
      final range = MathUtils.segmentCircleOverlapRange(origin, target, ball.position, ball.radius);
      if (range != null) blocked.add(range);
    }

    if (blocked.isEmpty) return [[origin, target]];

    blocked.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<double>>[];
    for (final range in blocked) {
      if (merged.isNotEmpty && range[0] <= merged.last[1]) {
        merged.last[1] = math.max(merged.last[1], range[1]);
      } else {
        merged.add([range[0], range[1]]);
      }
    }

    final segments = <List<Offset>>[];
    final delta = target - origin;
    var cursor = 0.0;
    for (final range in merged) {
      if (range[0] > cursor) {
        segments.add([origin + delta * cursor, origin + delta * range[0]]);
      }
      cursor = range[1];
    }
    if (cursor < 1.0) {
      segments.add([origin + delta * cursor, origin + delta * 1.0]);
    }
    return segments;
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in state.particles.particles) {
      final lifeRatio = 1.0 - (particle.age / particle.lifespan).clamp(0.0, 1.0);
      // Young particles flash white-hot and cool into their collision color
      // as they age, for a punchier spark burst.
      final hotness = (lifeRatio * 1.6).clamp(0.0, 1.0);
      final sparkColor = Color.lerp(particle.color, Colors.white, hotness)!;
      final paint = Paint()
        ..color = sparkColor.withOpacity(lifeRatio)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(particle.position, particle.baseRadius * lifeRatio, paint);
    }
  }

  void _paintBallTokens(Canvas canvas) {
    for (final ball in state.balls) {
      final glowPaint = Paint()
        ..color = ball.config.glowColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6.0);
      canvas.drawCircle(ball.position, ball.radius + _ballGlowPadding, glowPaint);

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
