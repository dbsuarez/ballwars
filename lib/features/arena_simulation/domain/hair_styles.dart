import 'package:flutter/painting.dart';

import '../../ball_management/domain/custom_ball.dart';

/// Which hairstyle a ball wears. BallHairPainter draws style `s` as family
/// `s ~/ 5`, variant `s % 5`.
///
/// Styles 0-19 are the original random styles (spikes, rounded cuts, swept
/// and mohawk, long cuts with a ponytail); 20-44 are long straight,
/// ponytail, two pigtails, bob and top bun. Balls without a gender keep the
/// old behavior: with "Random hairstyles" on, the shuffled style 0-19.
abstract final class HairStyles {
  /// Styles a "Random hairstyles" shuffle hands out (0-19).
  static const int legacyCount = 20;

  /// Every style the painter knows.
  static const int count = 45;

  /// Short cuts: spikes, rounded cuts, swept and mohawk.
  static const List<int> male = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, //
  ];

  /// The old long-cut-and-ponytail family (15-19) plus the five female
  /// families (20-44).
  static const List<int> female = [
    15, 16, 17, 18, 19, //
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29, //
    30, 31, 32, 33, 34, 35, 36, 37, 38, 39, //
    40, 41, 42, 43, 44, //
  ];

  static List<int>? poolOf(BallGender gender) => switch (gender) {
    BallGender.none => null,
    BallGender.male => male,
    BallGender.female => female,
  };

  /// A stable hash of [id] that is the same on every platform (no RNG, and
  /// small enough to stay exact on the web).
  static int hashOf(String id) {
    var h = 17;
    for (final unit in id.codeUnits) {
      h = (h * 31 + unit) & 0x7FFFFFFF;
    }
    return h;
  }

  /// The style of a ball of [gender] with id [id]. [shuffled] is the
  /// match's shuffled style (0-19) when "Random hairstyles" is on, else
  /// null. Returns null for no hair.
  ///
  /// The shuffled style is shifted by the match [seed] (the same shift for
  /// every ball), so the whole pool shows up across matches even though the
  /// shuffle only covers 0-19, and balls of one gender still never share a
  /// style while the pool is larger than 20.
  static int? styleFor(
    BallGender gender,
    String id,
    int? shuffled, {
    int seed = 0,
  }) {
    final pool = poolOf(gender);
    if (pool == null) return shuffled;
    if (shuffled == null) return pool[hashOf(id) % pool.length];
    return pool[(shuffled + seed % pool.length) % pool.length];
  }

  /// A hair color for a gendered ball when "Random hairstyles" is off:
  /// picked from [palette] by the id's hash, skipping colors too close to
  /// the ball's own [body] color (as the random assignment does).
  static Color colorFor(
    String id,
    Color body,
    List<Color> palette,
    double Function(Color, Color) distance,
  ) {
    final start = hashOf(id) % palette.length;
    for (var k = 0; k < palette.length; k++) {
      final color = palette[(start + k) % palette.length];
      if (distance(color, body) > 90) return color;
    }
    return palette[start];
  }
}
