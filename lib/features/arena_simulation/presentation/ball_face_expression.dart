import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';

/// The "Faces" ball look: a classic smiley in the ball's own color, with white eyes whose pupils follow
/// the nearest opponent, and an expression that follows its health and hits. Cosmetic only.
enum FaceExpression { happy, worried, hurt, wince, shocked }

/// A fresh hit (wince) wins over everything, then frozen (shocked); otherwise health decides:
/// above 0.6 happy, 0.3 to 0.6 worried, below 0.3 hurt.
FaceExpression expressionFor(SimulationBall ball, double healthRatio) {
  if (ball.hurtFlashLeft > 0) return FaceExpression.wince;
  if (ball.frozenLeft > 0) return FaceExpression.shocked;
  if (healthRatio > 0.6) return FaceExpression.happy;
  if (healthRatio >= 0.3) return FaceExpression.worried;
  return FaceExpression.hurt;
}

/// Where the pupils sit inside an eye of [eyeRadius]: 35% of it toward the nearest opponent still in
/// the match, centered when there is none.
Offset pupilOffset(SimulationBall ball, List<SimulationBall> balls, double eyeRadius) {
  SimulationBall? nearest;
  var best = double.infinity;
  for (final other in balls) {
    if (identical(other, ball) || other.isEliminated) continue;
    final d = (other.position - ball.position).distanceSquared;
    if (d < best) {
      best = d;
      nearest = other;
    }
  }
  if (nearest == null) return Offset.zero;
  final to = nearest.position - ball.position;
  final length = to.distance;
  if (length == 0) return Offset.zero;
  return to * (0.35 * eyeRadius / length);
}

/// A ball's health for its face: life in Arsenal (no threads), otherwise the share of its starting
/// threads left.
double faceHealth(SimulationBall ball) =>
    ball.startLines > 0 ? ball.lineCount / ball.startLines : ball.life / PowerUpTuning.arenaLife;

/// Draws [ball]'s smiley: the ball's color, two white eyes with black pupils (or squeezed shut on a
/// fresh hit), brows only when worried or hurt, and a black mouth arc. By default it fills the ball (the
/// arena); with [center] and [radius] it is drawn there instead (beside the picture in the VS header),
/// with a dark outline.
void paintSmiley(
  Canvas canvas,
  SimulationBall ball,
  double healthRatio,
  List<SimulationBall> balls, {
  Offset? center,
  double? radius,
}) {
  final c = center ?? ball.position;
  final r = radius ?? ball.radius;
  final expression = expressionFor(ball, healthRatio);
  canvas.drawCircle(c, r, Paint()..color = ball.config.primaryColor);
  if (center != null) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, r * 0.1)
        ..color = const Color(0xFF111114),
    );
  }

  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, r * 0.09)
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF111114);
  final eyeR = r * 0.22;
  final eyes = [c + Offset(-r * 0.34, -r * 0.18), c + Offset(r * 0.34, -r * 0.18)];

  if (expression == FaceExpression.wince) {
    // > <
    for (final (i, eye) in eyes.indexed) {
      final dir = i == 0 ? 1.0 : -1.0;
      final path = Path()
        ..moveTo(eye.dx - dir * eyeR * 0.8, eye.dy - eyeR * 0.7)
        ..lineTo(eye.dx + dir * eyeR * 0.6, eye.dy)
        ..lineTo(eye.dx - dir * eyeR * 0.8, eye.dy + eyeR * 0.7);
      canvas.drawPath(path, ink);
    }
  } else {
    final look = pupilOffset(ball, balls, eyeR);
    for (final eye in eyes) {
      canvas.drawCircle(eye, eyeR, Paint()..color = Colors.white);
      canvas.drawCircle(eye, eyeR, ink..strokeWidth = math.max(1.0, r * 0.05));
      canvas.drawCircle(eye + look, eyeR * 0.5, Paint()..color = const Color(0xFF111114));
    }
    ink.strokeWidth = math.max(1.2, r * 0.09);
  }

  // Brows: worried tilts up in the middle, hurt tilts down (angry frown).
  if (expression == FaceExpression.worried || expression == FaceExpression.hurt) {
    final inner = expression == FaceExpression.worried ? -eyeR * 1.7 : -eyeR * 1.1;
    final outer = expression == FaceExpression.worried ? -eyeR * 1.2 : -eyeR * 1.7;
    for (final (i, eye) in eyes.indexed) {
      final dir = i == 0 ? 1.0 : -1.0;
      canvas.drawLine(eye + Offset(-dir * eyeR, outer), eye + Offset(dir * eyeR * 0.6, inner), ink);
    }
  }

  final mouth = c + Offset(0, r * 0.38);
  final w = r * 0.42;
  switch (expression) {
    case FaceExpression.happy:
      canvas.drawArc(Rect.fromCenter(center: mouth + Offset(0, -r * 0.12), width: w * 2, height: r * 0.5), 0.25,
          math.pi - 0.5, false, ink);
    case FaceExpression.worried:
      canvas.drawLine(mouth + Offset(-w * 0.6, 0), mouth + Offset(w * 0.6, 0), ink);
    case FaceExpression.hurt:
    case FaceExpression.wince:
      canvas.drawArc(Rect.fromCenter(center: mouth + Offset(0, r * 0.12), width: w * 1.6, height: r * 0.4),
          math.pi + 0.3, math.pi - 0.6, false, ink);
    case FaceExpression.shocked:
      canvas.drawCircle(mouth, r * 0.12, ink);
  }
}
