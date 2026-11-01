import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration retains fallback when explicit event is missing', () {
    const library = SkillLibrary();
    const skill = SkillDefinition(
      id: 'custom.legacy-cleanup',
      name: 'Legacy cleanup',
      baseKind: PowerUpKind.pistol,
      custom: true,
      castingSpriteId: 'old-casting.png',
      impactSpriteId: 'old-impact.png',
      visualBindings: {
        SkillVisualRole.casting: SkillVisualBinding(effectId: 'existing-cast'),
        SkillVisualRole.impact: SkillVisualBinding(effectId: 'existing-impact'),
      },
    );
    final migrated = library.migrateLegacyArtwork(skill);
    expect(migrated.skill.castingSpriteId, 'old-casting.png');
    expect(migrated.skill.impactSpriteId, 'old-impact.png');
    expect(migrated.skill.visualBindings, skill.visualBindings);
    expect(migrated.library.effects, isEmpty);
    final again = migrated.library.migrateLegacyArtwork(migrated.skill);
    expect(again.skill.visualBindings, migrated.skill.visualBindings);
    expect(again.library.effects, isEmpty);
    expect(again.skill.castingSpriteId, 'old-casting.png');
    expect(again.skill.impactSpriteId, 'old-impact.png');
  });

  test('migration clears obsolete artwork when explicit event exists', () {
    final library = const SkillLibrary().withEffect(
      const EffectDefinition(id: 'cast', name: 'Cast', spriteId: 'cast.png'),
    );
    const skill = SkillDefinition(
      id: 'custom.preferred-event', name: 'Preferred event',
      baseKind: PowerUpKind.pistol, castingSpriteId: 'old.png',
      visualBindings: {
        SkillVisualRole.casting: SkillVisualBinding(effectId: 'cast'),
      },
    );
    final converted = library.migrateLegacyArtwork(skill);
    expect(converted.skill.castingSpriteId, isNull);
    expect(converted.library.effects.length, 1);
    expect(converted.library.resolveVisual(converted.skill, SkillVisualRole.casting)?.spriteId,
        'cast.png');
  });

  test('migration is atomic if effect capacity is exhausted', () {
    final effects = {
      for (var i = 0; i < 256; i++)
        'effect.$i': EffectDefinition(id: 'effect.$i', name: 'Effect $i', spriteId: 'asset.png'),
    };
    final library = SkillLibrary(effects: effects);
    const skill = SkillDefinition(
      id: 'custom.full-library', name: 'Full library',
      baseKind: PowerUpKind.pistol, castingSpriteId: 'cast.png',
    );
    expect(() => library.migrateLegacyArtwork(skill), throwsFormatException);
    expect(library.effects.length, 256);
    expect(skill.castingSpriteId, 'cast.png');
  });
}

// Batch migration and editor integration are exercised separately in
// legacy_vfx_batch_migration_test.dart.
