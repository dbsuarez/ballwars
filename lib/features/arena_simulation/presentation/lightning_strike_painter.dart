import 'dart:ui' as ui;

import 'arena_effect_library.dart';

/// Shared arena/finisher playback. All eight frames keep the same impact anchor.
class LightningStrikePainter {
  static bool paint(
    ui.Canvas canvas, {
    required ui.Offset impact,
    required double size,
    required int step,
  }) {
    final frame = ArenaEffectLibrary.frame(ArenaEffectKind.lightning, step);
    if (frame == null) return false;
    canvas.drawImageRect(
      frame,
      ui.Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
      ui.Rect.fromLTWH(
        impact.dx - size / 2,
        impact.dy - size * 0.88,
        size,
        size,
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
    return true;
  }
}
