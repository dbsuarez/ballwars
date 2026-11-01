import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/application/skill_demo_controller.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

void main() {
  test('demo arena and obstacle selection rebuild isolated simulation', () {
    final library = SkillLibrary.defaults;
    final skill = library.all(PowerUpConfig.defaults).first;
    final demo = SkillDemoController(
      skill: skill,
      library: library,
      tuning: PowerUpConfig.defaults,
    );
    expect(demo.match.arenaShape, ArenaShape.circle);
    expect(demo.match.centerObstacle, CenterObstacle.none);
    demo.arenaShape = ArenaShape.square;
    demo.centerObstacle = CenterObstacle.circle;
    demo.reset();
    expect(demo.match.arenaShape, ArenaShape.square);
    expect(demo.match.centerObstacle, CenterObstacle.circle);
    expect(demo.started, isFalse);
    expect(demo.playing, isFalse);
  });
}
