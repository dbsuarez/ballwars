import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// Line colors for one match. Brand colors are often black or very dark
/// (invisible on the dark arena) and two contestants can share a color
/// (Nike vs Adidas), so each color is brightened if needed and, if it is
/// still too close to an earlier contestant's, swapped for the most distinct
/// color from [_fallbacks]. The logos themselves are never recolored.
class MatchColors {
  MatchColors._();

  // Relative luminance (0 black .. 1 white) a line color needs on the arena.
  static const double _minLuminance = 0.1;
  static const double _minDistance = 110;

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

  /// One visible, mutually distinct color per input, in the same order.
  static List<Color> resolve(List<Color> colors) {
    final used = <Color>[];
    for (final color in colors) {
      var c = visible(color);
      if (used.any((u) => distance(u, c) < _minDistance)) {
        c = _fallbacks.reduce((best, f) => _closestUsed(used, f) > _closestUsed(used, best) ? f : best);
      }
      used.add(c);
    }
    return used;
  }

  /// [color] brightened (hue kept) until it shows on the dark arena; grays
  /// become light gray. Judged by perceived brightness, so deep but vivid
  /// colors like Netflix red stay as they are.
  static Color visible(Color color) {
    if (color.computeLuminance() >= _minLuminance) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.15) return const Color(0xFFD0D4D8);
    var lightness = hsl.lightness;
    var c = color;
    while (c.computeLuminance() < _minLuminance && lightness < 0.9) {
      lightness += 0.04;
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
