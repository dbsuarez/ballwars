import 'package:flutter/material.dart';

enum CanvasActionGlyphType { close, play }

/// Font-independent action marks used where a missing icon font would leave
/// an important control blank.
class CanvasActionGlyph extends StatelessWidget {
  const CanvasActionGlyph(this.type, {super.key, this.size = 22});

  final CanvasActionGlyphType type;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CanvasActionGlyphPainter(type, IconTheme.of(context).color),
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
    }
  }

  @override
  bool shouldRepaint(_CanvasActionGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
