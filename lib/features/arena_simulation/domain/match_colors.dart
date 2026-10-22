import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// Line colors for one match. Brand colors can vanish against the arena
/// (black on a dark theme, yellow on a light one) and two contestants can
/// share a color (Nike vs Adidas), so each color is brightened or darkened
/// as needed and, if it is still too close to an earlier contestant's,
/// swapped for the most distinct of [_fallbacks]. Logos keep their colors.
class MatchColors {
  MatchColors._();

  // Relative luminance (0 black .. 1 white) a line color needs on a dark
  // arena, and may not exceed on a light one.
  static const double _minLuminance = 0.1;
  static const double _maxLuminance = 0.4;
  static const double _minDistance = 110;
  static const Color _darkArena = Color(0xFF0A0A0B);

  static const List<Color> _fallbacks = [
    Color(0xFFFF3B30), // red
    Color(0xFF0A84FF), // blue
    Color(0xFF34C759), // green
    Color(0xFFFFD60A), // yellow
    Color(0xFFBF5AF2), // purple
    Color(0xFFFF9F0A), // orange
    Color(0xFF64D2FF), // cyan
    Color(0xFFFF375F), // pink
    Color(0xFFE0E0E0), // light gray
  ];

  /// One visible, mutually distinct color per input, in the same order,
  /// for an arena drawn on [background].
  static List<Color> resolve(List<Color> colors, {Color background = _darkArena}) {
    final dark = background.computeLuminance() < 0.4;
    final used = <Color>[];
    for (final color in colors) {
      var c = visible(color, darkArena: dark);
      if (used.any((u) => distance(u, c) < _minDistance)) {
        c = visible(
          _fallbacks.reduce((best, f) => _closestUsed(used, f) > _closestUsed(used, best) ? f : best),
          darkArena: dark,
        );
      }
      used.add(c);
    }
    return used;
  }

  /// [color] adjusted (hue kept) until it shows on the arena: brightened on
  /// a dark one, darkened on a light one; grays become a light or dark gray.
  /// Judged by perceived brightness, so vivid colors like Netflix red stay.
  static Color visible(Color color, {bool darkArena = true}) {
    final lum = color.computeLuminance();
    if (darkArena ? lum >= _minLuminance : lum <= _maxLuminance) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.15) return darkArena ? const Color(0xFFD0D4D8) : const Color(0xFF3A3A3F);
    var lightness = hsl.lightness;
    var c = color;
    final step = darkArena ? 0.04 : -0.04;
    bool ok(Color c) => darkArena ? c.computeLuminance() >= _minLuminance : c.computeLuminance() <= _maxLuminance;
    while (!ok(c) && lightness > 0.1 && lightness < 0.9) {
      lightness += step;
      c = hsl.withLightness(lightness).toColor();
    }
    return c;
  }

  /// Perceptual-ish RGB distance ("redmean"), 0..~765.
  static double distance(Color a, Color b) {
    final r1 = a.r * 255, g1 = a.g * 255, b1 = a.b * 255;
    final r2 = b.r * 255, g2 = b.g * 255, b2 = b.b * 255;
    final rMean = (r1 + r2) / 2;
    final dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
    return math.sqrt((2 + rMean / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rMean) / 256) * db * db);
  }

  static double _closestUsed(List<Color> used, Color c) =>
      used.isEmpty ? double.infinity : used.map((u) => distance(u, c)).reduce(math.min);
}
