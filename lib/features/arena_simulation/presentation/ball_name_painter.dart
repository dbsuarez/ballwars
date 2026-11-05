import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/simulation_ball.dart';

class BallNamePainter {
  /// World-space, with a minimum readable screen size and no collision effects.
  static Rect paint(
    Canvas canvas,
    SimulationBall ball,
    Size worldSize,
    double scale, {
    String? score,
  }) {
    final font = math.max(11 / scale, ball.radius * .44);
    final width = math.min(
      worldSize.width - 8 / scale,
      math.max(80 / scale, ball.radius * 3.8),
    );
    final padding = 4 / scale;
    final name = TextPainter(
      text: TextSpan(
        text: ball.config.name.replaceAll(RegExp(r'\s+'), ' ').trim(),
        style: TextStyle(
          color: Colors.white,
          fontSize: font,
          fontFamily: 'Manrope',
          height: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: width - padding * 2);
    final counter = score == null
        ? null
        : (TextPainter(
            text: TextSpan(
              text: score,
              style: TextStyle(
                color: Colors.white,
                fontSize: font * .9,
                height: 1.1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: width - padding * 2));
    final height = name.height + (counter?.height ?? 0) + padding * 2;
    final labelWidth = math.max(name.width, counter?.width ?? 0) + padding * 2;
    final left = (ball.position.dx - labelWidth / 2).clamp(
      -worldSize.width / 2 + 2 / scale,
      worldSize.width / 2 - labelWidth - 2 / scale,
    );
    final top = (ball.position.dy + ball.radius + 3 / scale).clamp(
      -worldSize.height / 2 + 2 / scale,
      worldSize.height / 2 - height - 2 / scale,
    );
    final rect = Rect.fromLTWH(left, top, labelWidth, height);
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(4 / scale));
    canvas.drawRRect(
      shape,
      Paint()..color = Colors.black.withValues(alpha: .8),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..color = ball.config.primaryColor.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale,
    );
    name.paint(
      canvas,
      Offset(rect.center.dx - name.width / 2, rect.top + padding),
    );
    counter?.paint(
      canvas,
      Offset(
        rect.center.dx - counter.width / 2,
        rect.top + padding + name.height,
      ),
    );
    name.dispose();
    counter?.dispose();
    return rect;
  }
}
