import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/power_up.dart';
import 'power_up_painter.dart';

/// The power-up icons (game-icons.net SVGs in `assets/powerups`, CC BY 3.0) turned into images once, each
/// tinted in its power-up's color, so painting a frame only blits them ([Canvas.drawImageRect]): no SVG
/// parsing or path filling per frame.
///
/// [load] runs once per app; until it finishes (and in tests that skip it) [of] returns null and the
/// painter draws its simple vector glyphs instead.
class PowerUpSprites {
  PowerUpSprites._();

  /// Width and height of each image in pixels (sharp up to about 64 logical px on a 2x screen).
  static const int size = 128;

  static final Map<PowerUpKind, ui.Image> _images = {};
  static Future<void>? _loading;

  /// The asset path of [kind]'s icon (also used by Match Setup's weapons list).
  static String assetOf(PowerUpKind kind) => 'assets/powerups/${kind.name}.svg';

  /// [kind]'s image, or null before [load] has finished.
  static ui.Image? of(PowerUpKind kind) => _images[kind];

  /// Loads every icon (once; later calls return the same future). Failures leave that icon out.
  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    for (final kind in PowerUpKind.values) {
      try {
        final svg = await rootBundle.loadString(assetOf(kind));
        final info = await vg.loadPicture(SvgStringLoader(svg), null);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final scale = size / info.size.longestSide;
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
          Paint()..colorFilter = ColorFilter.mode(PowerUpPainter.colorOf(kind), BlendMode.srcIn),
        );
        canvas.scale(scale, scale);
        canvas.drawPicture(info.picture);
        canvas.restore();
        info.picture.dispose();
        final picture = recorder.endRecording();
        _images[kind] = await picture.toImage(size, size);
        picture.dispose();
      } catch (_) {
        // Keeps the vector glyph for this one.
      }
    }
  }
}
