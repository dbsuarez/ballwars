import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/sprites/application/skill_sprite_readiness.dart';

void main() {
  test('dependencies include payloads but exclude unrelated custom skills', () {
    final payload = SkillDefinition(
      id: 'custom.payload',
      name: 'Payload',
      custom: true,
      baseKind: PowerUpKind.boomerang,
      projectileSpriteId: 'custom.sheet.projectile',
      impactSpriteId: 'custom.sheet.hit',
    );
    final launcher = SkillDefinition(
      id: 'custom.launcher',
      name: 'Launcher',
      custom: true,
      baseKind: PowerUpKind.pistol,
      payloadSkillId: payload.id,
      castingSpriteId: 'custom.sheet.cast',
    );
    final unrelated = SkillDefinition(
      id: 'custom.other',
      name: 'Other',
      custom: true,
      baseKind: PowerUpKind.apple,
      iconSpriteId: 'custom.other.icon',
    );
    final library = SkillLibrary(custom: [launcher, payload, unrelated]);
    expect(
      SkillSpriteReadiness.dependencies(
        library: library,
        tuning: PowerUpConfig.defaults,
        kinds: {},
        customIds: {launcher.id},
      ),
      {'custom.sheet.projectile', 'custom.sheet.hit', 'custom.sheet.cast'},
    );
  });

  test('missing artwork is reported rather than silently accepted', () async {
    final previous = SkillSpriteReadiness.loader;
    SkillSpriteReadiness.loader = null;
    addTearDown(() => SkillSpriteReadiness.loader = previous);
    final library = SkillLibrary(
      custom: [
        const SkillDefinition(
          id: 'custom.a',
          name: 'A',
          custom: true,
          baseKind: PowerUpKind.knife,
          iconSpriteId: 'custom.missing.icon',
        ),
      ],
    );
    expect(
      await SkillSpriteReadiness.prepare(
        library: library,
        tuning: PowerUpConfig.defaults,
        kinds: {},
        customIds: {'custom.a'},
      ),
      {'custom.missing.icon'},
    );
  });
}
