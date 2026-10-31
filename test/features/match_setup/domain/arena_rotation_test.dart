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

  test('timed match interval caps at half the match duration', () {
    const rotation = ArenaRotation(rotateShapes: true, intervalSeconds: 120);
    expect(rotation.intervalForMatch(matchDurationSeconds: 180), 90);
    expect(rotation.shapeAt(ArenaShape.circle, 90, matchDurationSeconds: 180), ArenaShape.square);
  });
}
