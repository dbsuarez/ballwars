import 'package:flutter/material.dart';

/// Shared runtime filter: recolor luminance so cyan artwork can become gold,
/// preserving shading and transparency. White means original artwork.
class SkillArtworkTint {
  static ColorFilter filter(int tint) {
    final color = Color(tint);
    final r = color.r;
    final g = color.g;
    final b = color.b;
    return ColorFilter.matrix([
      .2126 * r,
      .7152 * r,
      .0722 * r,
      0,
      0,
      .2126 * g,
      .7152 * g,
      .0722 * g,
      0,
      0,
      .2126 * b,
      .7152 * b,
      .0722 * b,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  static Widget widget(int tint, Widget child) => tint == 0xFFFFFFFF
      ? child
      : ColorFiltered(colorFilter: filter(tint), child: child);

  static void begin(Canvas canvas, int tint) {
    if (tint == 0xFFFFFFFF) {
      canvas.save();
    } else {
      canvas.saveLayer(null, Paint()..colorFilter = filter(tint));
    }
  }

  static void end(Canvas canvas) => canvas.restore();
}
