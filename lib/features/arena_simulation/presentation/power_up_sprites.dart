import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../domain/power_up.dart';
import 'power_up_pixel_art.dart';

/// The power-up icons ([pixelIcons], 16 x 16 pixel art) turned into small images once, so painting a frame
/// only blits them ([Canvas.drawImageRect] with nearest-neighbor scaling keeps the pixels crisp).
///
/// [load] runs once per app; until it finishes (and in tests that skip it) [of] returns null and the
/// painter draws its simple vector glyphs instead. [paintIcon] draws an icon straight from its pixels,
/// for widgets such as Match Setup's weapons list.
class PowerUpSprites {
  PowerUpSprites._();

  static final Map<PowerUpKind, ui.Image> _images = {};
  static Future<void>? _loading;

  /// [kind]'s image (16 x 16 px), or null before [load] has finished.
  static ui.Image? of(PowerUpKind kind) => _images[kind];

  /// Builds every icon image (once; later calls return the same future).
  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    // Only cache real pixel sprites. Kinds added after the original sprite set
    // deliberately stay uncached so the arena painter uses its vector glyph
    // instead of blitting a transparent image.
    for (final kind in pixelIcons.keys) {
      final recorder = ui.PictureRecorder();
      paintIcon(
        Canvas(recorder),
        kind,
        const Rect.fromLTWH(0, 0, pixelSize * 1.0, pixelSize * 1.0),
      );
      final picture = recorder.endRecording();
      _images[kind] = await picture.toImage(pixelSize, pixelSize);
      picture.dispose();
    }
  }

  /// Draws [kind]'s pixels filling [rect] (one rectangle per pixel; for small widgets, not every frame).
  static void paintIcon(Canvas canvas, PowerUpKind kind, Rect rect) {
    final rows = pixelIcons[kind];
    if (rows == null) {
      _paintFallbackIcon(canvas, kind, rect);
      return;
    }
    final cell = Size(rect.width / pixelSize, rect.height / pixelSize);
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final color = pixelPalette[row[x]];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + x * cell.width,
            rect.top + y * cell.height,
            cell.width,
            cell.height,
          ),
          paint,
        );
      }
    }
  }

  /// A compact, always-visible badge for newer kinds that do not yet have a
  /// hand-authored 16 x 16 sprite. The initials keep every item distinct.
  static void _paintFallbackIcon(Canvas canvas, PowerUpKind kind, Rect rect) {
    const colors = [
      Color(0xFF00C9A7),
      Color(0xFFFF6B35),
      Color(0xFF7C5CFF),
      Color(0xFFFF4FD8),
      Color(0xFF58A6FF),
      Color(0xFFFFD000),
    ];
    final color = colors[kind.index % colors.length];
    final center = rect.center;
    final radius = rect.shortestSide * 0.45;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF171722));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.shortestSide * 0.1
        ..color = color,
    );
    final words = kind.label.split(' ');
    final initials = words.length == 1
        ? words.first
              .substring(0, words.first.length >= 2 ? 2 : 1)
              .toUpperCase()
        : words.take(2).map((word) => word[0]).join();
    final text = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: color,
          fontSize: rect.shortestSide * (initials.length == 1 ? 0.58 : 0.43),
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }
}

/// A power-up's pixel-art icon as a widget.
class PowerUpIcon extends StatelessWidget {
  final PowerUpKind kind;
  final double size;

  const PowerUpIcon(this.kind, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _IconPainter(kind));
}

class _IconPainter extends CustomPainter {
  final PowerUpKind kind;

  _IconPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) =>
      PowerUpSprites.paintIcon(canvas, kind, Offset.zero & size);

  @override
  bool shouldRepaint(_IconPainter old) => old.kind != kind;
}
