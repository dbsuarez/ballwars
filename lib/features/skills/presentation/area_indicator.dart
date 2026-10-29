import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/skill_library.dart';

void paintAreaIndicator(
  Canvas canvas,
  Offset center,
  double radius,
  AreaGuideStyle style,
  Color color, {
  double opacity = .65,
  double width = 1.5,
}) {
  if (style == AreaGuideStyle.hidden || radius <= 0) return;
  final pen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = color.withValues(alpha: opacity.clamp(0, 1));
  if (style == AreaGuideStyle.solid) {
    canvas.drawCircle(center, radius, pen);
    return;
  }
  final rect = Rect.fromCircle(center: center, radius: radius);
  final segments = math.max(12, (radius * .8).round());
  final step = math.pi * 2 / segments;
  for (var i = 0; i < segments; i++) {
    canvas.drawArc(rect, i * step, step * .48, false, pen);
    canvas.drawCircle(
      center + Offset.fromDirection((i + .78) * step, radius),
      width * .45,
      Paint()..color = pen.color,
    );
  }
}
