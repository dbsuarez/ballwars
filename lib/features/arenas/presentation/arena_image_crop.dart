import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../domain/arena_background_style.dart';

/// One crop contract for upload, saved-image adjustment and live rendering.
class ArenaImageCrop extends StatefulWidget {
  const ArenaImageCrop({
    super.key,
    required this.image,
    required this.style,
    required this.onChanged,
    this.enabled = true,
  });
  final ui.Image image;
  final ArenaBackgroundStyle style;
  final ValueChanged<ArenaBackgroundStyle> onChanged;
  final bool enabled;
  @override
  State<ArenaImageCrop> createState() => _ArenaImageCropState();
}

class _ArenaImageCropState extends State<ArenaImageCrop> {
  double startZoom = 1;
  int pointers = 0;
  Offset anchor = Offset.zero;
  Size get source =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, bounds) => MediaQuery(
        // Scale's pan threshold normally exceeds a parent ListView's drag
        // threshold. Let the image win deliberately; scroll outside the image.
        data: MediaQuery.of(
          context,
        ).copyWith(gestureSettings: const DeviceGestureSettings(touchSlop: 4)),
        child: Semantics(
          label:
              'Background crop. Drag to move; pinch to zoom. Sliders are available below.',
          child: GestureDetector(
            key: const ValueKey('arena-image-crop'),
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onScaleStart: !widget.enabled
                ? null
                : (details) {
                    final crop = widget.style.crop(source);
                    startZoom = widget.style.zoom;
                    pointers = details.pointerCount;
                    anchor =
                        crop.topLeft +
                        details.localFocalPoint *
                            (crop.width / bounds.maxWidth);
                  },
            onScaleUpdate: !widget.enabled
                ? null
                : (details) {
                    if (pointers != details.pointerCount) {
                      pointers = details.pointerCount;
                      startZoom = widget.style.zoom / details.scale;
                      final current = widget.style.crop(source);
                      anchor =
                          current.topLeft +
                          details.localFocalPoint *
                              (current.width / bounds.maxWidth);
                    }
                    final zoom = (startZoom * details.scale).clamp(1.0, 4.0);
                    final side = source.shortestSide / zoom;
                    final left =
                        anchor.dx -
                        details.localFocalPoint.dx * side / bounds.maxWidth;
                    final top =
                        anchor.dy -
                        details.localFocalPoint.dy * side / bounds.maxWidth;
                    widget.onChanged(
                      widget.style.copyWith(
                        zoom: zoom,
                        x: source.width == side
                            ? .5
                            : (left / (source.width - side)).clamp(0.0, 1.0),
                        y: source.height == side
                            ? .5
                            : (top / (source.height - side)).clamp(0.0, 1.0),
                      ),
                    );
                  },
            child: CustomPaint(
              painter: _CropPainter(widget.image, widget.style),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.style);
  final ui.Image image;
  final ArenaBackgroundStyle style;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff202020),
    );
    canvas.drawImageRect(
      image,
      style.crop(Size(image.width.toDouble(), image.height.toDouble())),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: style.dim.clamp(0, 1)),
    );
    canvas.drawRect(
      (Offset.zero & size).deflate(.5),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.image != image || old.style != style;
}
