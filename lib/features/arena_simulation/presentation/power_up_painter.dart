import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';

/// Draws the power-up layer of an Arsenal / All-Out match in the arena's coordinates (center at 0, 0):
/// field power-ups with a soft glow, aim lines, bullets, bombs and blasts ([paint]), plus the per-ball
/// looks drawn over each ball ([paintBallEffects]: held badge, aiming shield, frozen tint).
///
/// Flat style and cheap to draw (see CLAUDE.md "Painting performance"): no blur filters (glows are
/// radial gradients), bullets are one batched drawRawPoints call.
class PowerUpPainter {
  PowerUpPainter._();

  static const Map<PowerUpKind, Color> _colors = {
    PowerUpKind.pistol: Color(0xFFF2B33D),
    PowerUpKind.shotgun: Color(0xFFE8833A),
    PowerUpKind.gatling: Color(0xFFD9534F),
    PowerUpKind.knife: Color(0xFFB8C2CC),
    PowerUpKind.shield: Color(0xFF4F8EF7),
    PowerUpKind.apple: Color(0xFF3BB54A),
    PowerUpKind.speed: Color(0xFFF5E050),
    PowerUpKind.freeze: Color(0xFF7FDBFF),
    PowerUpKind.bomb: Color(0xFF6B6B78),
    PowerUpKind.magnet: Color(0xFFE0457B),
    PowerUpKind.ghost: Color(0xFFC9B8F0),
  };

  /// The color a power-up is drawn in.
  static Color colorOf(PowerUpKind kind) => _colors[kind]!;

  /// Field power-ups, aim lines, bullets, bombs and blasts. Call after the fan lines, before the balls.
  /// [showEffects] covers only the decorative blast flash; gameplay objects always draw.
  static void paint(Canvas canvas, SimulationState state, double arenaRadius, {bool showEffects = true}) {
    final p = state.powerUps;
    if (p == null) return;
    final r = arenaRadius * PowerUpTuning.fieldRadiusRatio;

    for (final e in p.explosions) {
      final t = e.age / PowerUpTuning.explosionShowSteps;
      final fade = (1 - t).clamp(0.0, 1.0);
      if (showEffects) {
        canvas.drawCircle(
          e.position,
          e.radius,
          Paint()..color = const Color(0xFFFFB347).withValues(alpha: 0.25 * fade),
        );
      }
      canvas.drawCircle(
        e.position,
        e.radius * (0.6 + 0.4 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFF7A3D).withValues(alpha: fade),
      );
    }

    for (final item in p.field) {
      final color = colorOf(item.kind);
      // Subtle glow: a radial gradient fading out around the token.
      canvas.drawCircle(
        item.position,
        r * 2,
        Paint()
          ..shader = ui.Gradient.radial(item.position, r * 2, [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(item.position, r, Paint()..color = const Color(0xFF15151A));
      canvas.drawCircle(
        item.position,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color,
      );
      drawGlyph(canvas, item.kind, item.position, r * 0.62);
    }

    for (final ball in state.balls) {
      final target = ball.aimTarget;
      if (ball.isEliminated || target == null || ball.aimLeft <= 0) continue;
      canvas.drawLine(
        ball.position,
        target.position,
        Paint()
          ..strokeWidth = 1
          ..color = colorOf(ball.held ?? PowerUpKind.pistol).withValues(alpha: 0.45),
      );
    }

    if (p.projectiles.isNotEmpty) {
      final points = Float32List(p.projectiles.length * 2);
      var n = 0;
      for (final shot in p.projectiles) {
        points[n++] = shot.position.dx;
        points[n++] = shot.position.dy;
      }
      canvas.drawRawPoints(
        ui.PointMode.points,
        points,
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFF3C4),
      );
    }

    for (final bomb in p.bombs) {
      final pulse = 0.5 + 0.5 * math.sin(bomb.fuseSteps * 0.6);
      canvas.drawCircle(bomb.position, r * 0.8, Paint()..color = colorOf(PowerUpKind.bomb));
      canvas.drawCircle(
        bomb.position,
        r * (1.1 + 0.4 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFF5A3D).withValues(alpha: 0.4 + 0.5 * pulse),
      );
    }
  }

  /// Looks drawn over [ball]: a frozen ball gets an icy tint, a held shield an arc on the side it
  /// faces, and any other held power-up a small badge on the ball's edge.
  static void paintBallEffects(Canvas canvas, SimulationBall ball) {
    if (ball.frozenLeft > 0) {
      canvas.drawCircle(ball.position, ball.radius, Paint()..color = const Color(0xFF9FE3FF).withValues(alpha: 0.45));
    }
    final held = ball.held;
    if (held == null) return;
    if (held == PowerUpKind.shield) {
      canvas.drawArc(
        Rect.fromCircle(center: ball.position, radius: ball.radius + 4),
        ball.shieldAngle - 0.9,
        1.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = colorOf(PowerUpKind.shield),
      );
      return;
    }
    final badge = ball.position + Offset(ball.radius * 0.72, -ball.radius * 0.72);
    final r = math.max(6.0, ball.radius * 0.36);
    canvas.drawCircle(badge, r, Paint()..color = const Color(0xFF15151A));
    canvas.drawCircle(
      badge,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = colorOf(held),
    );
    drawGlyph(canvas, held, badge, r * 0.62);
  }

  /// A simple flat glyph for [kind], about [s] in half-size, centered at [c] (also used for the
  /// weapons list in Match Setup).
  static void drawGlyph(Canvas canvas, PowerUpKind kind, Offset c, double s) {
    final color = colorOf(kind);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.28)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    Offset at(double x, double y) => c + Offset(x * s, y * s);
    switch (kind) {
      case PowerUpKind.pistol:
        canvas.drawPath(
          Path()
            ..moveTo(at(-0.9, -0.5).dx, at(-0.9, -0.5).dy)
            ..lineTo(at(0.9, -0.5).dx, at(0.9, -0.5).dy)
            ..lineTo(at(0.9, -0.1).dx, at(0.9, -0.1).dy)
            ..lineTo(at(-0.2, -0.1).dx, at(-0.2, -0.1).dy)
            ..lineTo(at(-0.35, 0.8).dx, at(-0.35, 0.8).dy)
            ..lineTo(at(-0.85, 0.8).dx, at(-0.85, 0.8).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.shotgun:
        canvas.drawLine(at(-0.95, 0.35), at(0.95, -0.35), stroke);
        canvas.drawLine(at(-0.95, 0.35), at(-0.6, 0.75), stroke);
      case PowerUpKind.gatling:
        for (final y in [-0.45, 0.0, 0.45]) {
          canvas.drawLine(at(-0.8, y), at(0.9, y), stroke..strokeWidth = math.max(1.0, s * 0.2));
        }
      case PowerUpKind.knife:
        canvas.drawPath(
          Path()
            ..moveTo(at(-0.9, 0.9).dx, at(-0.9, 0.9).dy)
            ..lineTo(at(0.9, -0.9).dx, at(0.9, -0.9).dy)
            ..lineTo(at(0.1, 0.1).dx, at(0.1, 0.1).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.shield:
        canvas.drawPath(
          Path()
            ..moveTo(at(0, -0.95).dx, at(0, -0.95).dy)
            ..lineTo(at(0.8, -0.6).dx, at(0.8, -0.6).dy)
            ..quadraticBezierTo(at(0.75, 0.55).dx, at(0.75, 0.55).dy, at(0, 0.95).dx, at(0, 0.95).dy)
            ..quadraticBezierTo(at(-0.75, 0.55).dx, at(-0.75, 0.55).dy, at(-0.8, -0.6).dx, at(-0.8, -0.6).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.apple:
        canvas.drawCircle(at(0, 0.15), s * 0.75, Paint()..color = const Color(0xFFE53935));
        canvas.drawLine(at(0, -0.55), at(0.35, -0.95), stroke);
      case PowerUpKind.speed:
        canvas.drawPath(
          Path()
            ..moveTo(at(0.2, -1).dx, at(0.2, -1).dy)
            ..lineTo(at(-0.55, 0.1).dx, at(-0.55, 0.1).dy)
            ..lineTo(at(0, 0.1).dx, at(0, 0.1).dy)
            ..lineTo(at(-0.25, 1).dx, at(-0.25, 1).dy)
            ..lineTo(at(0.6, -0.2).dx, at(0.6, -0.2).dy)
            ..lineTo(at(0.05, -0.2).dx, at(0.05, -0.2).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.freeze:
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(at(math.cos(a), math.sin(a)), at(-math.cos(a), -math.sin(a)), stroke);
        }
      case PowerUpKind.bomb:
        canvas.drawCircle(at(-0.1, 0.2), s * 0.7, Paint()..color = const Color(0xFF2B2B33));
        canvas.drawLine(
          at(0.35, -0.35),
          at(0.75, -0.85),
          Paint()
            ..strokeWidth = math.max(1.0, s * 0.2)
            ..color = const Color(0xFFFFB347),
        );
      case PowerUpKind.magnet:
        canvas.drawArc(Rect.fromCircle(center: at(0, 0.1), radius: s * 0.65), 0, math.pi, false, stroke);
        canvas.drawLine(at(-0.65, 0.1), at(-0.65, -0.8), stroke);
        canvas.drawLine(at(0.65, 0.1), at(0.65, -0.8), stroke);
      case PowerUpKind.ghost:
        canvas.drawPath(
          Path()
            ..moveTo(at(-0.75, 0.9).dx, at(-0.75, 0.9).dy)
            ..lineTo(at(-0.75, -0.1).dx, at(-0.75, -0.1).dy)
            ..arcToPoint(at(0.75, -0.1), radius: Radius.circular(s * 0.75))
            ..lineTo(at(0.75, 0.9).dx, at(0.75, 0.9).dy)
            ..lineTo(at(0.4, 0.6).dx, at(0.4, 0.6).dy)
            ..lineTo(at(0, 0.9).dx, at(0, 0.9).dy)
            ..lineTo(at(-0.4, 0.6).dx, at(-0.4, 0.6).dy)
            ..close(),
          fill,
        );
    }
  }
}
