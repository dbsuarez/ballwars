import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Frames a picture for a ball: the picture sits behind a fixed circle and
/// can be dragged and zoomed (pinch, or the mouse wheel on web). Reports the
/// framed square, in the image's own pixels, through [onChanged].
class CircleCropper extends StatefulWidget {
  final ui.Image image;
  final double size;
  final Color ringColor;
  final ValueChanged<Rect> onChanged;

  const CircleCropper({super.key, required this.image, required this.onChanged, this.size = 240, this.ringColor = Colors.white});

  @override
  State<CircleCropper> createState() => _CircleCropperState();
}

class _CircleCropperState extends State<CircleCropper> {
  static const double _maxZoom = 6;
  double _zoom = 1;
  Offset _offset = Offset.zero;
  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  double get _diameter => widget.size * 0.84;
  double get _w => widget.image.width.toDouble();
  double get _h => widget.image.height.toDouble();

  /// Pixels on screen per image pixel: at zoom 1 the circle just fits inside
  /// the picture's shorter side.
  double get _scale => _diameter / math.min(_w, _h) * _zoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(CircleCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _zoom = 1;
      _offset = Offset.zero;
      WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    }
  }

  /// Keeps the circle covered by the picture.
  Offset _clamp(Offset o) {
    final maxX = (_w * _scale - _diameter) / 2;
    final maxY = (_h * _scale - _diameter) / 2;
    return Offset(o.dx.clamp(-maxX, maxX), o.dy.clamp(-maxY, maxY));
  }

  Rect get _crop {
    final imageLeft = widget.size / 2 - _w * _scale / 2 + _offset.dx;
    final imageTop = widget.size / 2 - _h * _scale / 2 + _offset.dy;
    final circleLeft = (widget.size - _diameter) / 2;
    final side = _diameter / _scale;
    return Rect.fromLTWH((circleLeft - imageLeft) / _scale, (circleLeft - imageTop) / _scale, side, side);
  }

  void _report() {
    if (mounted) widget.onChanged(_crop);
  }

  void _update({double? zoom, Offset? offset}) {
    setState(() {
      _zoom = (zoom ?? _zoom).clamp(1.0, _maxZoom);
      _offset = _clamp(offset ?? _offset);
    });
    _report();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) _update(zoom: _zoom * (1 - event.scrollDelta.dy / 500));
      },
      child: GestureDetector(
        onScaleStart: (d) {
          _startZoom = _zoom;
          _startOffset = _offset;
          _startFocal = d.localFocalPoint;
        },
        onScaleUpdate: (d) =>
            _update(zoom: _startZoom * d.scale, offset: _startOffset + (d.localFocalPoint - _startFocal)),
        child: SizedBox.square(
          dimension: widget.size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              painter: _CropPainter(
                image: widget.image,
                scale: _scale,
                offset: _offset,
                diameter: _diameter,
                ringColor: widget.ringColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;
  final double diameter;
  final Color ringColor;

  _CropPainter({required this.image, required this.scale, required this.offset, required this.diameter, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width * scale, h = image.height * scale;
    final dst = Rect.fromCenter(center: size.center(Offset.zero) + offset, width: w, height: h);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final circle = Rect.fromCircle(center: size.center(Offset.zero), radius: diameter / 2);
    // Dim everything outside the circle; outline the circle.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(circle),
      Paint()..color = const Color(0xB3000000),
    );
    canvas.drawOval(
      circle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ringColor,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.scale != scale || old.offset != offset || old.ringColor != ringColor;
}
