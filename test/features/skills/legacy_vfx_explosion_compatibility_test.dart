import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk migration preserves Impact and Explosion fallback artwork', () {
    const original = SkillLibrary(custom: [SkillDefinition(
      id: 'custom.area', name: 'Area', baseKind: PowerUpKind.pistol,
      custom: true, impactSpriteId: 'blast.png',
    )]);
    final before = original.custom.single;
    expect(original.resolveVisual(before, SkillVisualRole.impact)?.spriteId,
        'blast.png');
    expect(original.resolveVisual(before, SkillVisualRole.explosion)?.spriteId,
        'blast.png');
    final plan = original.planLegacyArtworkMigration();
    expect(plan.newEffects, 1);
    final converted = original.migrateAllLegacyArtwork();
    final skill = converted.custom.single;
    expect(skill.impactSpriteId, isNull);
    expect(converted.resolveVisual(skill, SkillVisualRole.impact)?.spriteId,
        'blast.png');
    expect(converted.resolveVisual(skill, SkillVisualRole.explosion)?.spriteId,
        'blast.png');
    expect(skill.visualBindings[SkillVisualRole.impact]!.effectId,
        skill.visualBindings[SkillVisualRole.explosion]!.effectId);
    expect(converted.planLegacyArtworkMigration().hasChanges, isFalse);
    final restored = SkillLibrary.fromJson(converted.toJson());
    final restoredSkill = restored.custom.single;
    expect(restored.resolveVisual(restoredSkill,
        SkillVisualRole.explosion)?.spriteId, 'blast.png');
    expect(restored.migrateAllLegacyArtwork().effects.length,
        converted.effects.length);
  });

  test('explicit Explosion binding wins over migrated Impact fallback', () {
    const explosion = EffectDefinition(
      id: 'custom.explosion', name: 'Explosion', spriteId: 'explicit.png');
    const original = SkillLibrary(
      effects: {'custom.explosion': explosion},
      custom: [SkillDefinition(
        id: 'custom.mixed', name: 'Mixed', baseKind: PowerUpKind.pistol,
        custom: true, impactSpriteId: 'legacy.png',
        visualBindings: {
          SkillVisualRole.explosion:
              SkillVisualBinding(effectId: 'custom.explosion'),
        },
      )],
    );
    final converted = original.migrateAllLegacyArtwork();
    final skill = converted.custom.single;
    expect(converted.resolveVisual(skill, SkillVisualRole.impact)?.spriteId,
        'legacy.png');
    expect(converted.resolveVisual(skill, SkillVisualRole.explosion)?.spriteId,
        'explicit.png');
  });

  test('explicit Impact binding retains unbound Explosion legacy fallback', () {
    const impact = EffectDefinition(
      id: 'custom.impact', name: 'Impact', spriteId: 'new-impact.png');
    const original = SkillLibrary(
      effects: {'custom.impact': impact},
      custom: [SkillDefinition(
        id: 'custom.dual', name: 'Dual', baseKind: PowerUpKind.pistol,
        custom: true, impactSpriteId: 'old-explosion.png',
        visualBindings: {
          SkillVisualRole.impact:
              SkillVisualBinding(effectId: 'custom.impact'),
        },
      )],
    );
    final plan = original.planLegacyArtworkMigration();
    expect(plan.newEffects, 1);
    expect(plan.blockedSlots, 0);
    expect(plan.hasChanges, isTrue);
    final converted = original.migrateAllLegacyArtwork();
    final skill = converted.custom.single;
    expect(skill.impactSpriteId, isNull);
    expect(skill.visualBindings[SkillVisualRole.explosion], isNotNull);
    expect(converted.effects.length, 2);
    expect(converted.planLegacyArtworkMigration().hasChanges, isFalse);
    expect(converted.resolveVisual(skill, SkillVisualRole.impact)?.spriteId,
        'new-impact.png');
    expect(converted.resolveVisual(skill, SkillVisualRole.explosion)?.spriteId,
        'old-explosion.png');
  });

  test('repeated bulk conversion reuses an existing Explosion event', () {
    const impact = EffectDefinition(
      id: 'custom.impact', name: 'Impact', spriteId: 'new.png');
    const oldExplosion = EffectDefinition(
      id: 'legacy.custom.dual.explosion', name: 'Old explosion',
      spriteId: 'old.png');
    const library = SkillLibrary(
      effects: {
        'custom.impact': impact,
        'legacy.custom.dual.explosion': oldExplosion,
      },
      custom: [SkillDefinition(
        id: 'custom.dual', name: 'Dual', baseKind: PowerUpKind.pistol,
        custom: true, impactSpriteId: 'old.png',
        visualBindings: {
          SkillVisualRole.impact: SkillVisualBinding(effectId: 'custom.impact'),
        },
      )],
    );
    expect(library.planLegacyArtworkMigration().newEffects, 0);
    expect(library.planLegacyArtworkMigration().reusedEffects, 1);
    final converted = library.migrateAllLegacyArtwork();
    expect(converted.effects.length, 2);
    expect(converted.custom.single.visualBindings[SkillVisualRole.explosion]!
        .effectId, 'legacy.custom.dual.explosion');
    expect(converted.migrateAllLegacyArtwork().toJson(), converted.toJson());
  });

  test('Explosion migration collision uses a distinct effect ID', () {
    const original = SkillLibrary(
      effects: {
        'impact': EffectDefinition(
          id: 'impact', name: 'Impact', spriteId: 'new.png'),
        'legacy.custom.dual.explosion': EffectDefinition(
          id: 'legacy.custom.dual.explosion',
          name: 'Unrelated', spriteId: 'other.png'),
      },
      custom: [SkillDefinition(
        id: 'custom.dual', name: 'Dual', baseKind: PowerUpKind.pistol,
        custom: true, impactSpriteId: 'old.png',
        visualBindings: {
          SkillVisualRole.impact: SkillVisualBinding(effectId: 'impact'),
        },
      )],
    );
    final plan = original.planLegacyArtworkMigration();
    expect(plan.newEffects, 1);
    final converted = original.migrateAllLegacyArtwork();
    expect(converted.custom.single.visualBindings[SkillVisualRole.explosion]!
        .effectId, 'legacy.custom.dual.explosion.1');
    expect(converted.resolveVisual(converted.custom.single,
        SkillVisualRole.explosion)?.spriteId, 'old.png');
    expect(converted.effects['legacy.custom.dual.explosion']!.spriteId,
        'other.png');
  });

  test('Explosion migration capacity failure is atomic', () {
    final effects = <String, EffectDefinition>{
      for (var i = 0; i < 256; i++)
        'effect.$i': EffectDefinition(
          id: 'effect.$i', name: 'Effect', spriteId: 'sprite.png'),
    };
    final library = SkillLibrary(
      effects: effects,
      custom: const [SkillDefinition(
        id: 'custom.full', name: 'Full', baseKind: PowerUpKind.pistol,
        custom: true, impactSpriteId: 'old.png',
        visualBindings: {
          SkillVisualRole.impact: SkillVisualBinding(effectId: 'effect.0'),
        },
      )],
    );
    final before = library.toJson();
    expect(library.planLegacyArtworkMigration().fitsCapacity, isFalse);
    expect(() => library.migrateAllLegacyArtwork(), throwsFormatException);
    expect(library.toJson(), before);
  });

  test('missing Explosion event retains old artwork instead of discarding it', () {
    const impact = EffectDefinition(
      id: 'custom.impact', name: 'Impact', spriteId: 'new-impact.png');
    const original = SkillLibrary(
      effects: {'custom.impact': impact},
      custom: [SkillDefinition(
        id: 'custom.missing', name: 'Missing', baseKind: PowerUpKind.pistol,
        custom: true, impactSpriteId: 'fallback.png',
        visualBindings: {
          SkillVisualRole.impact:
              SkillVisualBinding(effectId: 'custom.impact'),
          SkillVisualRole.explosion:
              SkillVisualBinding(effectId: 'missing.explosion'),
        },
      )],
    );
    final converted = original.migrateAllLegacyArtwork();
    expect(converted.custom.single.impactSpriteId, 'fallback.png');
    expect(converted.resolveVisual(converted.custom.single,
        SkillVisualRole.explosion)?.spriteId, 'fallback.png');
  });
}

// These tests exercise the public bulk migration contract without a renderer.
