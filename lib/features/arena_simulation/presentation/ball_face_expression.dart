import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import 'power_up_painter.dart';

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
Offset pupilOffset(
  SimulationBall ball,
  List<SimulationBall> balls,
  double eyeRadius,
) {
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
double faceHealth(SimulationBall ball) => ball.startLines > 0
    ? ball.lineCount / ball.startLines
    : ball.life / PowerUpTuning.arenaLife;

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
  double backgroundAlpha = 1,
}) {
  final c = center ?? ball.position;
  final r = radius ?? ball.radius;
  final expression = expressionFor(ball, healthRatio);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..color = ball.config.primaryColor.withValues(alpha: backgroundAlpha),
  );
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
  final eyes = [
    c + Offset(-r * 0.34, -r * 0.18),
    c + Offset(r * 0.34, -r * 0.18),
  ];

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
      canvas.drawCircle(
        eye + look,
        eyeR * 0.5,
        Paint()..color = const Color(0xFF111114),
      );
    }
    ink.strokeWidth = math.max(1.2, r * 0.09);
  }

  // Brows: worried tilts up in the middle, hurt tilts down (angry frown).
  if (expression == FaceExpression.worried ||
      expression == FaceExpression.hurt) {
    final inner = expression == FaceExpression.worried
        ? -eyeR * 1.7
        : -eyeR * 1.1;
    final outer = expression == FaceExpression.worried
        ? -eyeR * 1.2
        : -eyeR * 1.7;
    for (final (i, eye) in eyes.indexed) {
      final dir = i == 0 ? 1.0 : -1.0;
      canvas.drawLine(
        eye + Offset(-dir * eyeR, outer),
        eye + Offset(dir * eyeR * 0.6, inner),
        ink,
      );
    }
  }

  final mouth = c + Offset(0, r * 0.38);
  final w = r * 0.42;
  switch (expression) {
    case FaceExpression.happy:
      canvas.drawArc(
        Rect.fromCenter(
          center: mouth + Offset(0, -r * 0.12),
          width: w * 2,
          height: r * 0.5,
        ),
        0.25,
        math.pi - 0.5,
        false,
        ink,
      );
    case FaceExpression.worried:
      canvas.drawLine(
        mouth + Offset(-w * 0.6, 0),
        mouth + Offset(w * 0.6, 0),
        ink,
      );
    case FaceExpression.hurt:
    case FaceExpression.wince:
      canvas.drawArc(
        Rect.fromCenter(
          center: mouth + Offset(0, r * 0.12),
          width: w * 1.6,
          height: r * 0.4,
        ),
        math.pi + 0.3,
        math.pi - 0.6,
        false,
        ink,
      );
    case FaceExpression.shocked:
      canvas.drawCircle(mouth, r * 0.12, ink);
  }
}

/// Draws the Faces look's white cartoon gloves. A held item gets one gripping
/// hand and a second hand on the lower free side; an unarmed smiley carries a
/// relaxed hand on each side. Draw this after [PowerUpPainter.paintBallEffects]
/// so the grip sits visibly over the weapon.
///
/// The hand stays at the kind's standard grip point; a skill's own grip
/// values only slide the weapon sprite relative to it.
void paintHands(Canvas canvas, SimulationBall ball) {
  final r = ball.radius;
  final held = ball.held;
  if (held == null) {
    _paintHandAt(
      canvas,
      ball.position + _unit(math.pi / 2 - 1.2) * (r * 0.98),
      r,
    );
    _paintHandAt(
      canvas,
      ball.position + _unit(math.pi / 2 + 1.2) * (r * 0.98),
      r,
    );
    return;
  }

  if (ball.heldSecondary != null) {
    for (var slot = 0; slot < ball.equippedWeapons.length; slot++) {
      final weapon = ball.equippedWeapons[slot];
      final aim = PowerUpPainter.heldAngle(ball, weapon: weapon, slot: slot);
      final center = PowerUpPainter.heldCenter(
        ball,
        weapon: weapon,
        slot: slot,
      );
      final dir = _unit(aim);
      _paintHandAt(
        canvas,
        weapon == PowerUpKind.shield
            ? ball.position + dir * (r * 0.95)
            : center -
                  dir *
                      (r *
                          (weapon.isBlade
                              ? 1.3
                              : weapon == PowerUpKind.hook ||
                                    weapon == PowerUpKind.threadHarpoon
                              ? 0.65
                              : 0.5)),
        r,
        gripAngle: aim,
      );
    }
    return;
  }

  final aim = PowerUpPainter.heldAngle(ball);
  _paintHandAt(canvas, gripHandPosition(ball), r, gripAngle: aim);

  final freeA = aim - 2.3;
  final freeB = aim + 2.3;
  final freeAngle = math.sin(freeA) >= math.sin(freeB) ? freeA : freeB;
  _paintHandAt(canvas, ball.position + _unit(freeAngle) * (r * 0.98), r);
}

/// Where [paintHands] puts the gripping hand of a ball's single held item:
/// the standard grip point of the weapon's kind, whatever grip values the skill
/// sets (those slide the sprite relative to the hand). The grip preview marks
/// this spot so a hilt can be lined up with it.
Offset gripHandPosition(SimulationBall ball) {
  final held = ball.held;
  if (held == null) return ball.position;
  final r = ball.radius;
  final aim = PowerUpPainter.heldAngle(ball);
  final flipped = math.cos(aim) < 0;
  final dir = _unit(aim);
  final side = Offset(-dir.dy, dir.dx);
  final weaponCenter = PowerUpPainter.heldCenter(ball);
  if (held == PowerUpKind.shield) {
    return ball.position + dir * (r * 0.95);
  } else if (held.isBlade ||
      held == PowerUpKind.hook ||
      held == PowerUpKind.threadHarpoon) {
    return weaponCenter - dir * (r * (held.isBlade ? 1.3 : 0.65));
  }
  // The sprite flips vertically when it points left, so its local grip does
  // the same.
  final localY = flipped ? -0.3 : 0.3;
  return weaponCenter - dir * (r * 0.45) + side * (r * localY);
}

Offset _unit(double angle) => Offset(math.cos(angle), math.sin(angle));

void _paintHandAt(
  Canvas canvas,
  Offset center,
  double ballRadius, {
  double? gripAngle,
}) {
  final handRadius = ballRadius * 0.22;
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.0, ballRadius * 0.07)
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF111114);
  final fill = Paint()..color = const Color(0xFFF7F7F4);

  // A short cuff makes the circle read as a glove rather than another ball.
  if (gripAngle != null) {
    final back = _unit(gripAngle + math.pi);
    final side = Offset(-back.dy, back.dx);
    final cuffCenter = center + back * (handRadius * 0.72);
    final cuff = Path()
      ..moveTo(
        (cuffCenter + side * handRadius * 0.55).dx,
        (cuffCenter + side * handRadius * 0.55).dy,
      )
      ..lineTo(
        (cuffCenter + back * handRadius * 0.72 + side * handRadius * 0.46).dx,
        (cuffCenter + back * handRadius * 0.72 + side * handRadius * 0.46).dy,
      )
      ..lineTo(
        (cuffCenter + back * handRadius * 0.72 - side * handRadius * 0.46).dx,
        (cuffCenter + back * handRadius * 0.72 - side * handRadius * 0.46).dy,
      )
      ..lineTo(
        (cuffCenter - side * handRadius * 0.55).dx,
        (cuffCenter - side * handRadius * 0.55).dy,
      )
      ..close();
    canvas.drawPath(cuff, fill);
    canvas.drawPath(cuff, outline);
  }
  canvas.drawCircle(center, handRadius, fill);
  canvas.drawCircle(center, handRadius, outline);
}
