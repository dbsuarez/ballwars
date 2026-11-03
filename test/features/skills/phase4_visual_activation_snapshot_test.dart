import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

import 'casting_artwork_test.dart' show setup;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrated Casting snapshots the resolved visual at activation', () {
    final match = setup(PowerUpKind.speed, migrated: true,
        eventDuration: 0.75);
    final casts = match.powerUps!.castingArtwork;
    expect(casts, hasLength(1));
    final cast = casts.single;
    expect(cast.resolvedVisual, isNotNull);
    expect(cast.resolvedVisual!.spriteId, isNotEmpty);
    expect(cast.hasExplicitDuration, isTrue);
    expect(cast.steps, 45);
  });

  test('unbound hit and explosion snapshots are absent', () {
    final powerUps = setup(PowerUpKind.pistol).powerUps!;
    final hit = WeaponImpact(position: const Offset(0, 0), strength: 1);
    final explosion = Explosion(position: const Offset(0, 0), radius: 12);
    expect(powerUps.impactVisual(hit), isNull);
    expect(powerUps.explosionVisual(explosion), isNull);
  });
  test('legacy artwork resolves consistently for both hit roles', () {
    final library = SkillLibrary.defaults;
    final skill = library.builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
        .copyWith(impactSpriteId: 'legacy-hit.png', spriteTint: 0xFF12ABCD);
    final configured = library.withDefinition(skill, PowerUpConfig.defaults);
    final hit = configured.resolveVisual(skill, SkillVisualRole.impact);
    final blast = configured.resolveVisual(skill, SkillVisualRole.explosion);
    expect(hit?.spriteId, 'legacy-hit.png');
    expect(blast?.spriteId, 'legacy-hit.png');
    expect(hit?.tint, 0xFF12ABCD);
    expect(blast?.tint, 0xFF12ABCD);
    expect(hit?.scale, blast?.scale);
    expect(skill.visualBindings.containsKey(SkillVisualRole.impact), isFalse);
    expect(skill.visualBindings.containsKey(SkillVisualRole.explosion), isFalse);
  });

}

