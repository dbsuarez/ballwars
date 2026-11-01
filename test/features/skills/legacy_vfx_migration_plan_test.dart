import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const skill = SkillDefinition(
    id: 'custom.preview',
    name: 'Preview',
    baseKind: PowerUpKind.pistol,
    custom: true,
    castingSpriteId: 'cast.png',
    impactSpriteId: 'impact.png',
  );

  test('dry-run predicts both effects without changing original', () {
    const library = SkillLibrary(custom: [skill]);
    final plan = library.planLegacyArtworkMigration();
    expect(plan.affectedSkills, 1);
    expect(plan.newEffects, 2);
    expect(plan.availableEffectSlots, 256);
    expect(plan.fitsCapacity, isTrue);
    expect(library.effects, isEmpty);
    final converted = library.migrateAllLegacyArtwork();
    expect(converted.effects.length, plan.newEffects);
    expect(converted.planLegacyArtworkMigration().hasChanges, isFalse);
  });

  test('existing matching effect is counted as reuse', () {
    final effect = EffectDefinition(
      id: 'legacy.custom.preview.casting',
      name: 'Already converted',
      spriteId: 'cast.png',
    );
    final library = SkillLibrary(
      custom: const [skill], effects: {effect.id: effect},
    );
    final plan = library.planLegacyArtworkMigration();
    expect(plan.newEffects, 1);
    expect(plan.reusedEffects, 1);
    expect(library.migrateAllLegacyArtwork().effects.length, 2);
  });

  test('missing bound effect remains blocked and artwork is retained', () {
    const library = SkillLibrary(custom: [SkillDefinition(
      id: 'custom.blocked', name: 'Blocked',
      baseKind: PowerUpKind.pistol, custom: true,
      castingSpriteId: 'fallback.png',
      visualBindings: {
        SkillVisualRole.casting: SkillVisualBinding(effectId: 'missing'),
      },
    )]);
    final plan = library.planLegacyArtworkMigration();
    expect(plan.blockedSlots, 1);
    expect(plan.hasChanges, isFalse);
    expect(library.migrateAllLegacyArtwork().custom.single.castingSpriteId,
        'fallback.png');
  });

  test('capacity warning prevents attempting a partial conversion', () {
    final effects = <String, EffectDefinition>{
      for (var i = 0; i < 255; i++)
        'other.$i': EffectDefinition(
          id: 'other.$i', name: 'Other', spriteId: 'other.png',
        ),
    };
    final library = SkillLibrary(effects: effects, custom: const [skill]);
    final plan = library.planLegacyArtworkMigration();
    expect(plan.newEffects, 2);
    expect(plan.availableEffectSlots, 1);
    expect(plan.fitsCapacity, isFalse);
    expect(() => library.migrateAllLegacyArtwork(), throwsFormatException);
    expect(library.effects.length, 255);
  });
}
