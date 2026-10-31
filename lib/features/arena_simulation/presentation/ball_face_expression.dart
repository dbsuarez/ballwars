import '../../settings/domain/ball_appearance.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import 'power_up_painter.dart';

/// The "Faces" ball look: a classic smiley in the ball's own color, with white eyes whose pupils follow
/// the nearest opponent, and an expression that follows its health and hits. Cosmetic only.
enum FaceExpression {
  happy('Happy'),
  worried('Worried'),
  hurt('Hurt'),
  wince('Wincing'),
  shocked('Shocked'),
  grinning('Grinning'),
  angry('Angry'),
  dizzy('Dizzy'),
  determined('Focused'),
  sad('Sad'),
  knockedOut('Knocked out');

  const FaceExpression(this.label);
  final String label;
}

/// A fresh hit (wince) wins over everything, then frozen (shocked); otherwise health decides:
/// above 0.6 happy, 0.3 to 0.6 worried, below 0.3 hurt.
FaceExpression expressionFor(
  SimulationBall ball,
  double healthRatio, {
  bool expressive = true,
}) {
  if (ball.hurtFlashLeft > 0) return FaceExpression.wince;
  if (ball.frozenLeft > 0) return FaceExpression.shocked;
  if (expressive) {
    if (ball.isEliminated) return FaceExpression.knockedOut;
    if (ball.stunnedLeft > 0) return FaceExpression.dizzy;
    if (ball.overchargeLeft > 0) return FaceExpression.angry;
    if (ball.aimLeft > 0 || ball.burstLeft > 0) {
      return FaceExpression.determined;
    }
    if (healthRatio > 1) return FaceExpression.grinning;
    if (healthRatio < .15 || ball.poisonLeft > 0) return FaceExpression.sad;
  }
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
  BallAppearance appearance = BallAppearance.defaults,
  FaceExpression? expressionOverride,
}) {
  final c = center ?? ball.position;
  final r = radius ?? ball.radius;
  final expression =
      expressionOverride ??
      expressionFor(ball, healthRatio, expressive: appearance.expressiveFaces);
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
  final eyeR = r * 0.22 * appearance.eyeScale;
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
  } else if (expression == FaceExpression.knockedOut) {
    for (final eye in eyes) {
      canvas.drawLine(
        eye + Offset(-eyeR, -eyeR),
        eye + Offset(eyeR, eyeR),
        ink,
      );
      canvas.drawLine(
        eye + Offset(eyeR, -eyeR),
        eye + Offset(-eyeR, eyeR),
        ink,
      );
    }
  } else if (expression == FaceExpression.dizzy) {
    for (final eye in eyes) {
      final spiral = Path();
      for (var i = 0; i <= 36; i++) {
        final a = i * math.pi / 10;
        final at = eye + Offset(math.cos(a), math.sin(a)) * (eyeR * i / 36);
        if (i == 0) {
          spiral.moveTo(at.dx, at.dy);
        } else {
          spiral.lineTo(at.dx, at.dy);
        }
      }
      canvas.drawPath(spiral, ink);
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
  if ({
    FaceExpression.worried,
    FaceExpression.hurt,
    FaceExpression.angry,
    FaceExpression.sad,
    FaceExpression.determined,
  }.contains(expression)) {
    final inner =
        expression == FaceExpression.worried || expression == FaceExpression.sad
        ? -eyeR * 1.7
        : -eyeR * 1.1;
    final outer =
        expression == FaceExpression.worried || expression == FaceExpression.sad
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

  final mouth = c + Offset(0, r * (0.38 + appearance.mouthOffset));
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
    case FaceExpression.determined:
    case FaceExpression.worried:
      canvas.drawLine(
        mouth + Offset(-w * 0.6, 0),
        mouth + Offset(w * 0.6, 0),
        ink,
      );
    case FaceExpression.sad:
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
    case FaceExpression.angry:
      final teeth = RRect.fromRectAndRadius(
        Rect.fromCenter(center: mouth, width: r * .6, height: r * .2),
        Radius.circular(r * .04),
      );
      canvas.drawRRect(teeth, Paint()..color = Colors.white);
      canvas.drawRRect(teeth, ink);
      for (final x in [-.12, .12]) {
        canvas.drawLine(
          mouth + Offset(r * x, -r * .08),
          mouth + Offset(r * x, r * .08),
          ink..strokeWidth = math.max(1, r * .04),
        );
      }
    case FaceExpression.grinning:
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: mouth, width: r * .75, height: r * .35),
        Radius.circular(r * .12),
      );
      canvas.drawRRect(rect, Paint()..color = Colors.white);
      canvas.drawRRect(rect, ink);
      canvas.drawLine(
        mouth + Offset(-r * .32, 0),
        mouth + Offset(r * .32, 0),
        ink..strokeWidth = math.max(1, r * .04),
      );
    case FaceExpression.knockedOut:
      canvas.drawOval(
        Rect.fromCenter(center: mouth, width: r * .3, height: r * .2),
        ink,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: mouth + Offset(r * .04, r * .13),
          width: r * .12,
          height: r * .2,
        ),
        Paint()..color = const Color(0xFFFF8CA6),
      );
    case FaceExpression.dizzy:
      final wave = Path()..moveTo(mouth.dx - w, mouth.dy);
      wave.cubicTo(
        mouth.dx - w / 2,
        mouth.dy - r * .2,
        mouth.dx + w / 2,
        mouth.dy + r * .2,
        mouth.dx + w,
        mouth.dy,
      );
      canvas.drawPath(wave, ink);
  }
}

/// Draws the Faces look's white cartoon gloves. A held item gets one gripping
/// hand and a second hand on the lower free side; an unarmed smiley carries a
/// relaxed hand on each side. Draw this after [PowerUpPainter.paintBallEffects]
/// so the grip sits visibly over the weapon.
///
/// The hand stays at the kind's standard grip point; a skill's own grip
/// values only slide the weapon sprite relative to it.
void paintHands(
  Canvas canvas,
  SimulationBall ball, {
  BallAppearance appearance = BallAppearance.defaults,
}) {
  final r = ball.radius;
  final held = ball.held;
  if (held == null) {
    _paintHandAt(
      canvas,
      ball.position + _unit(math.pi / 2 - 1.2) * (r * 0.98),
      r,
      appearance: appearance,
    );
    _paintHandAt(
      canvas,
      ball.position + _unit(math.pi / 2 + 1.2) * (r * 0.98),
      r,
      appearance: appearance,
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
        appearance: appearance,
        gripAngle: aim,
      );
    }
    return;
  }

  final aim = PowerUpPainter.heldAngle(ball);
  _paintHandAt(
    canvas,
    gripHandPosition(ball),
    r,
    gripAngle: aim,
    appearance: appearance,
  );

  final freeA = aim - 2.3;
  final freeB = aim + 2.3;
  final freeAngle = math.sin(freeA) >= math.sin(freeB) ? freeA : freeB;
  _paintHandAt(
    canvas,
    ball.position + _unit(freeAngle) * (r * 0.98),
    r,
    appearance: appearance,
  );
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
  BallAppearance appearance = BallAppearance.defaults,
}) {
  final handRadius = ballRadius * 0.22 * appearance.handScale;
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.0, ballRadius * 0.07)
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF111114);
  final fill = Paint()..color = const Color(0xFFF7F7F4);

  // A short cuff makes the circle read as a glove rather than another ball.
  if (gripAngle != null && appearance.handStyle != BallHandStyle.circles) {
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
  if (appearance.handStyle == BallHandStyle.mittens) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(gripAngle ?? 0);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: handRadius * 1.6,
        height: handRadius * 2,
      ),
      Radius.circular(handRadius * .65),
    );
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, outline);
    canvas.drawCircle(
      Offset(handRadius * .8, handRadius * .3),
      handRadius * .4,
      fill,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(handRadius * .8, handRadius * .3),
        radius: handRadius * .4,
      ),
      -math.pi / 2,
      math.pi * 1.4,
      false,
      outline,
    );
    canvas.restore();
  } else {
    canvas.drawCircle(center, handRadius, fill);
    canvas.drawCircle(center, handRadius, outline);
  }
}
