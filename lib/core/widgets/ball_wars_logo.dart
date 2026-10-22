import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The Ball Wars mark: the arena rim with two balls, each holding a fan of
/// lines to the rim. Used for the loading screen, and rendered into the app
/// icon and splash images by `tool/brand/render_brand_test.dart`.
class BallWarsLogoPainter extends CustomPainter {
  /// Colour behind the logo; the balls get a ring of it so they stand off
  /// the lines.
  final Color background;
  final Color rim;

  /// 0..1: how much of each fan is drawn (the loading screen grows it).
  final double fan;

  static const Color teal = Color(0xFF4FD1C5);
  static const Color coral = Color(0xFFFF7A59);
  static const Color midnight = Color(0xFF0B0B0D);

  const BallWarsLogoPainter({this.background = midnight, this.rim = Colors.white, this.fan = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final stroke = r * 0.07;
    final rimR = r - stroke / 2;
    final lineWidth = r * 0.042;

    void fanOf(Offset ball, Color color, double fromDeg, double toDeg) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round;
      const lines = 7;
      final shown = (lines * fan).ceil();
      for (var i = 0; i < shown; i++) {
        final a = (fromDeg + (toDeg - fromDeg) * i / (lines - 1)) * math.pi / 180;
        canvas.drawLine(center + Offset(math.cos(a), math.sin(a)) * (rimR - stroke / 2), ball, paint);
      }
    }

    void ball(Offset at, Color color) {
      canvas.drawCircle(at, r * 0.22, Paint()..color = background);
      canvas.drawCircle(at, r * 0.17, Paint()..color = color);
    }

    final a = center + Offset(r * 0.26, -r * 0.3);
    final b = center + Offset(-r * 0.3, r * 0.27);
    fanOf(a, teal, 195, 335);
    fanOf(b, coral, 15, 155);
    canvas.drawCircle(
      center,
      rimR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = rim,
    );
    ball(a, teal);
    ball(b, coral);
  }

  @override
  bool shouldRepaint(BallWarsLogoPainter old) => old.background != background || old.rim != rim || old.fan != fan;
}
