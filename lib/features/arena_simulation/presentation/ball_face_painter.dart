import 'dart:math' as math;
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

  static final Map<String, TextPainter> _initials = {};

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
      // The image fills the circle through an image shader: no clip (a clip
      // per ball per frame is costly on phone GPUs). Non-square images
      // (photos) are scaled to cover the ball and centered, not stretched.
      final scale = math.max(rect.width / image.width, rect.height / image.height);
      final fit = Matrix4.identity()
        ..translateByDouble(center.dx - image.width * scale / 2, center.dy - image.height * scale / 2, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      canvas.drawCircle(center, radius, Paint()..color = ball.primaryColor);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..shader = ImageShader(image, TileMode.clamp, TileMode.clamp, fit.storage),
      );
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
      final letter = ball.name.isNotEmpty ? ball.name.substring(0, 1).toUpperCase() : '?';
      // Laid out once per letter and size, not every frame.
      final initial = _initials['$letter|${radius.toStringAsFixed(1)}'] ??= TextPainter(
        text: TextSpan(
          text: letter,
          style: TextStyle(color: Colors.white, fontSize: radius, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (_initials.length > 200) _initials.remove(_initials.keys.first);
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
