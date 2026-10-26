import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CanvasActionGlyphType { close, play, refresh, clearAll }

/// Font-independent action marks used where a missing icon font would leave
/// an important control blank.
class CanvasActionGlyph extends StatelessWidget {
  const CanvasActionGlyph(this.type, {super.key, this.size = 22, this.color});

  final CanvasActionGlyphType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CanvasActionGlyphPainter(
      type,
      color ?? IconTheme.of(context).color,
    ),
  );
}

class _CanvasActionGlyphPainter extends CustomPainter {
  const _CanvasActionGlyphPainter(this.type, this.color);

  final CanvasActionGlyphType type;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ?? Colors.white
      ..strokeWidth = size.shortestSide * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (type) {
      case CanvasActionGlyphType.close:
        canvas.drawLine(
          Offset(size.width * 0.23, size.height * 0.23),
          Offset(size.width * 0.77, size.height * 0.77),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.77, size.height * 0.23),
          Offset(size.width * 0.23, size.height * 0.77),
          paint,
        );
      case CanvasActionGlyphType.play:
        final path = Path()
          ..moveTo(size.width * 0.3, size.height * 0.18)
          ..lineTo(size.width * 0.78, size.height * 0.5)
          ..lineTo(size.width * 0.3, size.height * 0.82)
          ..close();
        canvas.drawPath(path, paint..style = PaintingStyle.fill);
      case CanvasActionGlyphType.refresh:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.11;
        final rect = Rect.fromLTWH(
          size.width * 0.2,
          size.height * 0.2,
          size.width * 0.6,
          size.height * 0.6,
        );
        canvas.drawArc(rect, -math.pi * 0.15, math.pi * 1.55, false, paint);
        final arrow = Path()
          ..moveTo(size.width * 0.77, size.height * 0.29)
          ..lineTo(size.width * 0.55, size.height * 0.27)
          ..lineTo(size.width * 0.71, size.height * 0.45)
          ..close();
        canvas.drawPath(arrow, paint..style = PaintingStyle.fill);
      case CanvasActionGlyphType.clearAll:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.1;
        for (final y in const [0.3, 0.5, 0.7]) {
          canvas.drawLine(
            Offset(size.width * 0.16, size.height * y),
            Offset(size.width * 0.62, size.height * y),
            paint,
          );
        }
        canvas.drawLine(
          Offset(size.width * 0.68, size.height * 0.36),
          Offset(size.width * 0.9, size.height * 0.64),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.9, size.height * 0.36),
          Offset(size.width * 0.68, size.height * 0.64),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_CanvasActionGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
