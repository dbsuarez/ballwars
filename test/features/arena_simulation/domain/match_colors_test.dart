import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/match_colors.dart';

void main() {
  test('colors that already show and differ are kept as they are', () {
    const colors = [Color(0xFFE50914), Color(0xFF1ED760), Color(0xFF0A84FF)];
    expect(MatchColors.resolve(colors), colors);
  });

  test('black and very dark brand colors become visible on the dark arena', () {
    final resolved = MatchColors.resolve(const [Color(0xFF000000), Color(0xFF01147B)]);
    for (final c in resolved) {
      expect(c.computeLuminance(), greaterThanOrEqualTo(0.1));
    }
    // Disney+ navy stays blue, just brighter.
    final hue = HSLColor.fromColor(resolved[1]).hue;
    expect(hue, closeTo(HSLColor.fromColor(const Color(0xFF01147B)).hue, 2));
  });

  test('two contestants with the same color get clearly different line colors', () {
    for (final pair in const [
      [Color(0xFF111111), Color(0xFF000000)], // Nike vs Adidas
      [Color(0xFFE50914), Color(0xFFFF0000)], // Netflix vs YouTube
    ]) {
      final resolved = MatchColors.resolve(pair);
      expect(MatchColors.distance(resolved[0], resolved[1]), greaterThan(110));
    }
  });

  test('four black brands all end up distinct', () {
    final resolved = MatchColors.resolve(List.filled(4, const Color(0xFF000000)));
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        expect(MatchColors.distance(resolved[i], resolved[j]), greaterThan(110));
      }
    }
  });
}
