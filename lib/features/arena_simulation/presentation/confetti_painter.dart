import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Falling confetti for the winner card (app and exported video). Fully
/// determined by [time] (seconds), so video frames render the same every
/// export; pieces wrap around and keep falling for as long as it's shown.
class ConfettiPainter extends CustomPainter {
  final double time;

  ConfettiPainter(this.time);

  static const List<Color> _colors = [
    Color(0xFFFF3B30),
    Color(0xFFFFD60A),
    Color(0xFF34C759),
    Color(0xFF0A84FF),
    Color(0xFFBF5AF2),
    Color(0xFFFF9F0A),
    Color(0xFF64D2FF),
    Color(0xFFFFFFFF),
  ];

  static final List<_Piece> _pieces = List.generate(110, (i) {
    final r = math.Random(i * 7919 + 13);
    return _Piece(
      x: r.nextDouble(),
      start: r.nextDouble(),
      fall: 0.10 + r.nextDouble() * 0.16, // screen heights per second
      sway: 0.01 + r.nextDouble() * 0.03,
      swaySpeed: 1.5 + r.nextDouble() * 2.5,
      spin: (r.nextDouble() - 0.5) * 10,
      phase: r.nextDouble() * math.pi * 2,
      size: 5 + r.nextDouble() * 6,
      color: _colors[i % _colors.length],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final scale = size.shortestSide / 400;
    for (final p in _pieces) {
      // Falls from just above the top to just below the bottom, then repeats.
      final y = ((p.start + time * p.fall) % 1.2 - 0.1) * size.height;
      final x = (p.x + math.sin(time * p.swaySpeed + p.phase) * p.sway) * size.width;
      final w = p.size * scale;
      // Flipping in 3D: the visible height pulses as the piece tumbles.
      final h = w * 0.55 * (0.3 + 0.7 * math.cos(time * p.spin * 0.7 + p.phase).abs());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(time * p.spin + p.phase);
      paint.color = p.color.withValues(alpha: 0.9);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => oldDelegate.time != time;
}

class _Piece {
  final double x, start, fall, sway, swaySpeed, spin, phase, size;
  final Color color;

  const _Piece({
    required this.x,
    required this.start,
    required this.fall,
    required this.sway,
    required this.swaySpeed,
    required this.spin,
    required this.phase,
    required this.size,
    required this.color,
  });
}
