import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';

/// Draws a ball's face (shared by the arena and the exported video):
/// - logo balls: a white ball with the full-color logo fitted inside and a
///   ring in the ball's line color;
/// - image balls (photos, flags): the image filling the ball;
/// - no image: the ball's color with bands and its initial.
class BallFacePainter {
  BallFacePainter._();

  static void paint(
    Canvas canvas,
    Offset center,
    double radius,
    CustomBall ball,
    ui.Image? image, {
    double rimWidth = 1.5,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (image != null && ball.imageStyle == BallImageStyle.logo) {
      canvas.drawCircle(center, radius, Paint()..color = Colors.white);
      _drawImage(canvas, image, Rect.fromCircle(center: center, radius: radius * 0.66));
      canvas.drawCircle(
        center,
        radius - radius * 0.05,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.1
          ..color = ball.primaryColor,
      );
    } else if (image != null) {
      canvas.drawCircle(center, radius, Paint()..color = ball.primaryColor);
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      _drawImage(canvas, image, rect);
      canvas.restore();
    } else {
      canvas.drawCircle(center, radius, Paint()..color = ball.primaryColor);
      // White equator band and red core band
      canvas.drawCircle(
        center,
        radius * 0.92,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.15
          ..color = Colors.white.withValues(alpha: 0.8),
      );
      canvas.drawCircle(
        center,
        radius * 0.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.1
          ..color = Colors.red.withValues(alpha: 0.9),
      );
      final initial = TextPainter(
        text: TextSpan(
          text: ball.name.isNotEmpty ? ball.name.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(color: Colors.white, fontSize: radius, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      initial.paint(canvas, center - Offset(initial.width / 2, initial.height / 2));
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth
        ..color = Colors.white,
    );
  }

  static void _drawImage(Canvas canvas, ui.Image image, Rect dst) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}
