import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/match_setup/domain/arena_rotation.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

void main() {
  test('rotations are disabled by default', () {
    const rotation = ArenaRotation();
    expect(rotation.themeAt(ArenaDecoration.space, 360), ArenaDecoration.space);
    expect(rotation.shapeAt(ArenaShape.square, 360), ArenaShape.square);
  });

  test('themes cycle deterministically without Chaotic', () {
    const rotation = ArenaRotation(rotateThemes: true);
    expect(rotation.themeAt(ArenaDecoration.defaultArena, 60), ArenaDecoration.neonGrid);
    expect(rotation.themeAt(ArenaDecoration.defaultArena, 120), ArenaDecoration.desert);
    expect(rotation.themeAt(ArenaDecoration.defaultArena, 180), ArenaDecoration.space);
    expect(rotation.themeAt(ArenaDecoration.defaultArena, 240), ArenaDecoration.wilderness);
    expect(rotation.themeAt(ArenaDecoration.defaultArena, 300), ArenaDecoration.defaultArena);
    expect(ArenaRotation.themes.contains(ArenaDecoration.chaotic), isFalse);
  });

  test('shape changes independently of theme', () {
    const rotation = ArenaRotation(rotateShapes: true);
    expect(rotation.shapeAt(ArenaShape.circle, 59), ArenaShape.circle);
    expect(rotation.shapeAt(ArenaShape.circle, 60), ArenaShape.square);
    expect(rotation.shapeAt(ArenaShape.circle, 120), ArenaShape.circle);
    expect(rotation.themeAt(ArenaDecoration.desert, 120), ArenaDecoration.desert);
  });

  test('short timed matches never rotate', () {
    const rotation = ArenaRotation(rotateThemes: true, rotateShapes: true);
    expect(rotation.transitionsAt(120, matchDurationSeconds: 45), 0);
    expect(rotation.shapeAt(ArenaShape.circle, 120,
        matchDurationSeconds: 45), ArenaShape.circle);
    expect(rotation.themeAt(ArenaDecoration.defaultArena, 120,
        matchDurationSeconds: 45), ArenaDecoration.defaultArena);
  });

  test('warning counts down before the transition and resets afterward', () {
    const rotation = ArenaRotation(rotateThemes: true);
    expect(rotation.secondsUntilNext(56), 4);
    expect(rotation.secondsUntilNext(57), 3);
    expect(rotation.secondsUntilNext(59.5), closeTo(0.5, 0.0001));
    expect(rotation.secondsUntilNext(60), 60);
    expect(rotation.transitionFlash(59.9), 0);
    expect(rotation.transitionFlash(60), 1);
    expect(rotation.transitionFlash(60.6), 0);
  });

  test('disabled and short timed matches have no warning or flash', () {
    const off = ArenaRotation();
    const on = ArenaRotation(rotateShapes: true);
    expect(off.secondsUntilNext(58), isNull);
    expect(on.secondsUntilNext(29, matchDurationSeconds: 30), isNull);
    expect(on.transitionFlash(60, matchDurationSeconds: 30), 0);
  });

  test('timed match interval caps at half the match duration', () {
    const rotation = ArenaRotation(rotateShapes: true, intervalSeconds: 120);
    expect(rotation.intervalForMatch(matchDurationSeconds: 180), 90);
    expect(rotation.shapeAt(ArenaShape.circle, 90, matchDurationSeconds: 180), ArenaShape.square);
  });

  test('manual Chaotic stays selected until the first automatic rotation', () {
    const rotation = ArenaRotation(rotateThemes: true);
    expect(rotation.themeAt(ArenaDecoration.chaotic, 0), ArenaDecoration.chaotic);
    expect(rotation.themeAt(ArenaDecoration.chaotic, 59.99), ArenaDecoration.chaotic);
    expect(rotation.themeAt(ArenaDecoration.chaotic, 60), ArenaDecoration.neonGrid);
    for (var step = 1; step <= 12; step++) {
      expect(rotation.themeAt(ArenaDecoration.chaotic, step * 60),
          isNot(ArenaDecoration.chaotic));
    }
  });

  test('all game modes use the same independent rotation rules', () {
    const rotation = ArenaRotation(rotateThemes: true, rotateShapes: true);
    for (final mode in MatchMode.values) {
      expect(rotation.themeAt(ArenaDecoration.defaultArena, 59),
          ArenaDecoration.defaultArena, reason: mode.name);
      expect(rotation.themeAt(ArenaDecoration.defaultArena, 60),
          ArenaDecoration.neonGrid, reason: mode.name);
      expect(rotation.shapeAt(ArenaShape.circle, 60),
          ArenaShape.square, reason: mode.name);
      expect(rotation.shapeAt(ArenaShape.circle, 120),
          ArenaShape.circle, reason: mode.name);
    }
  });

  test('timed interval and warning share the same schedule', () {
    const rotation = ArenaRotation(rotateThemes: true, rotateShapes: true,
        intervalSeconds: 300);
    expect(rotation.intervalForMatch(matchDurationSeconds: 180), 90);
    expect(rotation.secondsUntilNext(87, matchDurationSeconds: 180), 3);
    expect(rotation.themeAt(ArenaDecoration.defaultArena, 90,
        matchDurationSeconds: 180), ArenaDecoration.neonGrid);
    expect(rotation.shapeAt(ArenaShape.circle, 90,
        matchDurationSeconds: 180), ArenaShape.square);
    expect(rotation.secondsUntilNext(180, matchDurationSeconds: 180), isNull);
  });

}
