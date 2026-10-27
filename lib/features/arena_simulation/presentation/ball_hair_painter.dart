import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/simulation_ball.dart';

/// Lightweight deterministic hairstyles. All twenty styles are drawn from
/// paths and primitives, so they work identically in the arena and video.
class BallHairPainter {
  const BallHairPainter._();

  static void paint(Canvas canvas, SimulationBall ball) {
    final style = ball.hairstyle;
    final color = ball.hairColor;
    if (style == null || color == null) return;
    final c = ball.position;
    final r = ball.radius;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dark = Paint()
      ..color = Color.lerp(color, Colors.black, 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.07)
      ..strokeCap = StrokeCap.round;
    final variant = style % 5;
    final family = style ~/ 5;

    if (family == 0) {
      // Spikes: five silhouettes with different lean and height.
      final path = Path()..moveTo(c.dx - r * 0.82, c.dy - r * 0.45);
      for (var i = 0; i < 7; i++) {
        final x = c.dx - r * 0.75 + i * r * 0.25;
        final lean = (variant - 2) * r * 0.045;
        path
          ..lineTo(x + lean, c.dy - r * (1.02 + (i + variant) % 3 * 0.16))
          ..lineTo(x + r * 0.15, c.dy - r * 0.55);
      }
      path
        ..lineTo(c.dx + r * 0.82, c.dy - r * 0.28)
        ..quadraticBezierTo(
          c.dx,
          c.dy - r * 0.78,
          c.dx - r * 0.82,
          c.dy - r * 0.45,
        )
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, dark);
    } else if (family == 1) {
      // Rounded cuts: bowl, bob, afro, buns, and cloud curls.
      final bumps = 4 + variant;
      for (var i = 0; i < bumps; i++) {
        final t = bumps == 1 ? 0.5 : i / (bumps - 1);
        final x = c.dx + (t * 1.45 - 0.725) * r;
        final y = c.dy - r * (0.72 + math.sin(t * math.pi) * 0.3);
        canvas.drawCircle(
          x == c.dx ? Offset(x, y) : Offset(x, y),
          r * (0.28 + variant * 0.025),
          paint,
        );
      }
      if (variant == 3) {
        canvas.drawCircle(c + Offset(-r * 0.82, -r * 0.78), r * 0.3, paint);
        canvas.drawCircle(c + Offset(r * 0.82, -r * 0.78), r * 0.3, paint);
      }
    } else if (family == 2) {
      // Swept and mohawk cuts.
      final path = Path()
        ..moveTo(c.dx - r * 0.82, c.dy - r * 0.42)
        ..quadraticBezierTo(
          c.dx - r * (0.2 + variant * 0.08),
          c.dy - r * (1.25 + variant * 0.07),
          c.dx + r * 0.88,
          c.dy - r * (0.62 - variant * 0.03),
        )
        ..quadraticBezierTo(
          c.dx + r * 0.3,
          c.dy - r * 0.62,
          c.dx - r * 0.82,
          c.dy - r * 0.42,
        )
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, dark);
      if (variant >= 3) {
        canvas.drawRect(
          Rect.fromCenter(
            center: c - Offset(0, r * 1.02),
            width: r * 0.25,
            height: r * 0.75,
          ),
          paint,
        );
      }
    } else {
      // Long cuts and ponytails.
      final cap = Rect.fromCenter(
        center: c - Offset(0, r * 0.55),
        width: r * 1.65,
        height: r * (0.75 + variant * 0.05),
      );
      canvas.drawArc(cap, math.pi, math.pi, true, paint);
      final side = variant.isEven ? 1.0 : -1.0;
      final pony = Path()
        ..moveTo(c.dx + side * r * 0.72, c.dy - r * 0.63)
        ..quadraticBezierTo(
          c.dx + side * r * 1.35,
          c.dy - r * 0.15,
          c.dx + side * r * 1.05,
          c.dy + r * (0.45 + variant * 0.08),
        )
        ..quadraticBezierTo(
          c.dx + side * r * 0.72,
          c.dy + r * 0.05,
          c.dx + side * r * 0.72,
          c.dy - r * 0.63,
        )
        ..close();
      canvas.drawPath(pony, paint);
      if (variant == 4) {
        canvas.drawCircle(c - Offset(0, r * 1.12), r * 0.32, paint);
      }
    }
  }
}
