import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const variants = <EffectDefinition>[
    EffectDefinition(id: 'legacy.custom.modified.casting', name: 'Scaled',
        spriteId: 'legacy.png', scale: 2),
    EffectDefinition(id: 'legacy.custom.modified.casting', name: 'Faded',
        spriteId: 'legacy.png', opacity: .5),
    EffectDefinition(id: 'legacy.custom.modified.casting', name: 'Timed',
        spriteId: 'legacy.png', durationSeconds: .5),
    EffectDefinition(id: 'legacy.custom.modified.casting', name: 'Looping',
        spriteId: 'legacy.png', playback: EffectPlayback.loop),
  ];

  for (final variant in variants) {
    test('migration does not reuse modified ${variant.name} effect', () {
      final library = SkillLibrary(
        effects: {variant.id: variant},
        custom: const [SkillDefinition(
          id: 'custom.modified', name: 'Modified', custom: true,
          baseKind: PowerUpKind.pistol, castingSpriteId: 'legacy.png',
        )],
      );
      final plan = library.planLegacyArtworkMigration();
      expect(plan.newEffects, 1);
      expect(plan.reusedEffects, 0);
      final migrated = library.migrateAllLegacyArtwork();
      expect(migrated.effects[variant.id], same(variant));
      expect(migrated.effects['legacy.custom.modified.casting.1']?.spriteId,
          'legacy.png');
      expect(migrated.resolveVisual(migrated.custom.single,
          SkillVisualRole.casting)?.scale, 1);
    });
  }

  test('neutral event is reused without consuming capacity', () {
    const existing = EffectDefinition(
      id: 'legacy.custom.modified.casting', name: 'Neutral',
      spriteId: 'legacy.png',
    );
    const library = SkillLibrary(
      effects: {'legacy.custom.modified.casting': existing},
      custom: [SkillDefinition(
        id: 'custom.modified', name: 'Modified', custom: true,
        baseKind: PowerUpKind.pistol, castingSpriteId: 'legacy.png',
      )],
    );
    final plan = library.planLegacyArtworkMigration();
    expect(plan.newEffects, 0);
    expect(plan.reusedEffects, 1);
    final migrated = library.migrateAllLegacyArtwork();
    expect(migrated.effects.length, 1);
    expect(migrated.custom.single.castingSpriteId, isNull);
  });

  test('explicit Impact preserves Explosion with neutral replacement', () {
    const library = SkillLibrary(
      effects: {
        'impact': EffectDefinition(id: 'impact', name: 'Impact',
            spriteId: 'new.png'),
        'legacy.custom.explosion.explosion': EffectDefinition(
            id: 'legacy.custom.explosion.explosion', name: 'Modified',
            spriteId: 'old.png', opacity: .25),
      },
      custom: [SkillDefinition(
        id: 'custom.explosion', name: 'Explosion', custom: true,
        baseKind: PowerUpKind.pistol, impactSpriteId: 'old.png',
        visualBindings: {
          SkillVisualRole.impact: SkillVisualBinding(effectId: 'impact'),
        },
      )],
    );
    final plan = library.planLegacyArtworkMigration();
    expect(plan.newEffects, 1);
    final migrated = library.migrateAllLegacyArtwork();
    expect(migrated.effects['legacy.custom.explosion.explosion']?.opacity, .25);
    expect(migrated.effects['legacy.custom.explosion.explosion.1']?.opacity, 1);
    expect(migrated.resolveVisual(migrated.custom.single,
        SkillVisualRole.explosion)?.spriteId, 'old.png');
    expect(migrated.resolveVisual(migrated.custom.single,
        SkillVisualRole.explosion)?.opacity, 1);
    expect(migrated.resolveVisual(migrated.custom.single,
        SkillVisualRole.impact)?.spriteId, 'new.png');
  });

}

// An Impact event can already be authored while Explosion still relies on the
// old Impact sprite. The separate Explosion migration must also reject a
// visually modified event with the same artwork ID.
