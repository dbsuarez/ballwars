import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import 'power_up_sprites.dart';

/// Draws the power-up layer of an Arsenal / All-Out match in the arena's coordinates (center at 0, 0):
/// pulsing field power-ups, armed mines, aim lines, bullets, blasts and knife slashes ([paint]), plus the
/// per-ball looks ([paintBallEffects]: the held weapon or shield on the ball, frozen tint).
///
/// Flat style and cheap to draw (see CLAUDE.md "Painting performance"): no blur filters, icons are
/// pre-tinted images ([PowerUpSprites]), bullets are one batched drawRawPoints call.
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
    PowerUpKind.mine: Color(0xFF9A9AAE),
    PowerUpKind.magnet: Color(0xFFE0457B),
    PowerUpKind.ghost: Color(0xFFC9B8F0),
    PowerUpKind.grenade: Color(0xFF8DBF4A),
    PowerUpKind.sword: Color(0xFFE6D3A3),
  };

  /// The color a power-up is drawn in.
  static Color colorOf(PowerUpKind kind) => _colors[kind]!;

  /// Field power-ups, aim lines, bullets, mines, blasts and slashes. Call after the fan lines, before the
  /// balls. [showEffects] covers only the decorative blast flash; gameplay objects always draw.
  static void paint(Canvas canvas, SimulationState state, double arenaRadius, {bool showEffects = true}) {
    final p = state.powerUps;
    if (p == null) return;
    final r = p.fieldRadius;

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
      // Subtle pulse: the token breathes about once a second.
      final pulse = 0.5 + 0.5 * math.sin((state.step - item.spawnStep) * 2 * math.pi / 60);
      _paintToken(canvas, item.kind, item.position, r * (0.96 + 0.08 * pulse), 0.5 + 0.5 * pulse);
    }

    for (final bomb in p.mines) {
      // Armed: ringed in its owner's color, with a red light blinking twice a second.
      final blink = ((state.step - bomb.armedStep) ~/ 15).isEven;
      _paintToken(canvas, PowerUpKind.mine, bomb.position, r, 1, ring: bomb.owner.config.primaryColor);
      canvas.drawCircle(
        bomb.position + Offset(r * 0.62, -r * 0.62),
        math.max(2.5, r * 0.18),
        Paint()..color = blink ? const Color(0xFFFF3B30) : const Color(0xFF5A1A16),
      );
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
        if (shot.landAt != null) {
          // A grenade in flight: its icon, tumbling.
          final sprite = PowerUpSprites.of(PowerUpKind.grenade);
          if (sprite == null) {
            canvas.drawCircle(shot.position, r * 0.4, Paint()..color = colorOf(PowerUpKind.grenade));
          } else {
            _drawSprite(canvas, sprite, shot.position, r * 0.6, state.step * 0.3);
          }
          continue;
        }
        points[n++] = shot.position.dx;
        points[n++] = shot.position.dy;
      }
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(points, 0, n),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFF3C4),
      );
    }

    for (final m in p.slashMarks) {
      // Two quick strokes across the cut, fading out.
      final fade = (1 - m.age / PowerUpTuning.slashShowSteps).clamp(0.0, 1.0);
      final along = Offset(math.cos(m.angle), math.sin(m.angle)) * (r * 1.6);
      final across = Offset(-along.dy, along.dx) * 0.18;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: fade);
      for (final shift in [-1.0, 1.0]) {
        final o = m.position + across * shift;
        canvas.drawLine(o - along, o + along, paint);
      }
    }
  }

  /// A power-up token: dark disc, colored ring ([ring] if given) at [ringAlpha], and the icon.
  static void _paintToken(Canvas canvas, PowerUpKind kind, Offset c, double r, double ringAlpha, {Color? ring}) {
    final color = colorOf(kind);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF15151A));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.12)
        ..color = (ring ?? color).withValues(alpha: ringAlpha),
    );
    final sprite = PowerUpSprites.of(kind);
    if (sprite == null) {
      drawGlyph(canvas, kind, c, r * 0.62);
    } else {
      _drawSprite(canvas, sprite, c, r * 0.72, 0);
    }
  }

  static final Paint _spritePaint = Paint()..filterQuality = FilterQuality.medium;

  /// Draws [image] centered at [c], [half] in half-size. The icon is first turned so its own direction
  /// [iconAngle] lies along +x, then mirrored top-to-bottom if [flip] (so a gun pointing left isn't upside
  /// down), then turned to [rotation].
  static void _drawSprite(
    Canvas canvas,
    ui.Image image,
    Offset c,
    double half,
    double rotation, {
    double iconAngle = 0,
    bool flip = false,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (flip) canvas.scale(1, -1);
    if (iconAngle != 0) canvas.rotate(-iconAngle);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: 2 * half, height: 2 * half),
      _spritePaint,
    );
    canvas.restore();
  }

  /// The direction, in radians, each weapon icon points in as drawn in its SVG (guns: the muzzle; knife:
  /// the tip). Weapons are turned from it to point where they are used.
  static const Map<PowerUpKind, double> _iconAngle = {
    PowerUpKind.pistol: 0,
    PowerUpKind.shotgun: -math.pi / 4,
    PowerUpKind.gatling: 0,
    PowerUpKind.freeze: 0,
    PowerUpKind.knife: math.pi / 4,
    PowerUpKind.grenade: 0,
    PowerUpKind.sword: -math.pi / 4,
  };

  /// Looks drawn over [ball]: a frozen ball gets an icy tint, and what it holds is drawn on it. A gun
  /// sits on its edge pointing at its target (or the way it moves), a knife points the way it moves, and
  /// a shield is held on the side it faces.
  static void paintBallEffects(Canvas canvas, SimulationBall ball) {
    if (ball.frozenLeft > 0) {
      canvas.drawCircle(ball.position, ball.radius, Paint()..color = const Color(0xFF9FE3FF).withValues(alpha: 0.45));
    }
    final held = ball.held;
    if (held == null) return;
    final sprite = PowerUpSprites.of(held);
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
      if (sprite != null) {
        final dir = Offset(math.cos(ball.shieldAngle), math.sin(ball.shieldAngle));
        _drawSprite(canvas, sprite, ball.position + dir * ball.radius, ball.radius * 0.7, ball.shieldAngle + math.pi / 2);
      }
      return;
    }
    if (sprite == null) {
      final badge = ball.position + Offset(ball.radius * 0.72, -ball.radius * 0.72);
      final r = math.max(6.0, ball.radius * 0.36);
      canvas.drawCircle(badge, r, Paint()..color = const Color(0xFF15151A));
      drawGlyph(canvas, held, badge, r * 0.62);
      return;
    }
    final target = ball.aimTarget;
    final Offset toward;
    if (held.isGun && target != null) {
      toward = target.position - ball.position;
    } else if (ball.velocity != Offset.zero) {
      toward = ball.velocity;
    } else {
      toward = const Offset(1, 0);
    }
    final angle = math.atan2(toward.dy, toward.dx);
    final dir = Offset(math.cos(angle), math.sin(angle));
    _drawSprite(
      canvas,
      sprite,
      ball.position + dir * (ball.radius * 1.2),
      ball.radius * 0.9,
      angle,
      iconAngle: _iconAngle[held] ?? 0,
      flip: dir.dx < 0,
    );
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
      case PowerUpKind.mine:
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
      case PowerUpKind.grenade:
        canvas.drawOval(Rect.fromCenter(center: at(0, 0.2), width: s * 1.3, height: s * 1.5), fill);
        canvas.drawLine(at(-0.2, -0.6), at(0.5, -0.9), stroke);
      case PowerUpKind.sword:
        canvas.drawLine(at(-0.85, 0.85), at(0.9, -0.9), stroke);
        canvas.drawLine(at(-0.75, 0.25), at(-0.25, 0.75), stroke);
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
