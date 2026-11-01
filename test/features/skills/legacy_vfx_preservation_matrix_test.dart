import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dangling Explosion binding keeps legacy Impact fallback and preflight agrees', () {
    const original = SkillLibrary(custom: [SkillDefinition(
      id: 'custom.dangling-explosion',
      name: 'Dangling explosion',
      baseKind: PowerUpKind.pistol,
      custom: true,
      impactSpriteId: 'safe-impact.png',
      visualBindings: {
        SkillVisualRole.explosion: SkillVisualBinding(effectId: 'missing'),
      },
    )]);
    final plan = original.planLegacyArtworkMigration();
    expect(plan.blockedSlots, 1);
    expect(plan.newEffects, 0);
    expect(plan.hasChanges, isFalse);
    final converted = original.migrateAllLegacyArtwork();
    expect(converted.effects, isEmpty);
    expect(converted.custom.single.impactSpriteId, 'safe-impact.png');
    expect(converted.resolveVisual(converted.custom.single,
        SkillVisualRole.explosion)?.spriteId, 'safe-impact.png');
    expect(converted.resolveVisual(converted.custom.single,
        SkillVisualRole.impact)?.spriteId, 'safe-impact.png');
  });

  test('valid explicit Impact plus dangling Explosion preserves fallback', () {
    const library = SkillLibrary(
      effects: {
        'new-impact': EffectDefinition(
          id: 'new-impact', name: 'New impact', spriteId: 'new.png'),
      },
      custom: [SkillDefinition(
        id: 'custom.partial', name: 'Partial', baseKind: PowerUpKind.pistol,
        custom: true, impactSpriteId: 'legacy.png',
        visualBindings: {
          SkillVisualRole.impact: SkillVisualBinding(effectId: 'new-impact'),
          SkillVisualRole.explosion: SkillVisualBinding(effectId: 'missing'),
        },
      )],
    );
    final plan = library.planLegacyArtworkMigration();
    expect(plan.blockedSlots, 1);
    expect(plan.newEffects, 0);
    final result = library.migrateAllLegacyArtwork();
    expect(result.custom.single.impactSpriteId, 'legacy.png');
    expect(result.resolveVisual(result.custom.single,
        SkillVisualRole.impact)?.spriteId, 'new.png');
    expect(result.resolveVisual(result.custom.single,
        SkillVisualRole.explosion)?.spriteId, 'legacy.png');
  });

  test('mixed library preserves every visible VFX across conversion and JSON', () {
    const library = SkillLibrary(
      effects: {
        'impact.explicit': EffectDefinition(
          id: 'impact.explicit', name: 'Explicit', spriteId: 'new.png'),
      },
      overrides: {
        'builtin.pistol': SkillDefinition(
          id: 'builtin.pistol', name: 'Pistol', baseKind: PowerUpKind.pistol,
          castingSpriteId: 'cast.png', impactSpriteId: 'blast.png',
        ),
      },
      custom: [
        SkillDefinition(
          id: 'custom.mixed', name: 'Mixed', baseKind: PowerUpKind.pistol,
          custom: true, impactSpriteId: 'old.png',
          visualBindings: {
            SkillVisualRole.impact: SkillVisualBinding(effectId: 'impact.explicit'),
          },
        ),
        SkillDefinition(
          id: 'custom.dangling', name: 'Dangling',
          baseKind: PowerUpKind.pistol, custom: true,
          impactSpriteId: 'fallback.png',
          visualBindings: {
            SkillVisualRole.explosion: SkillVisualBinding(effectId: 'missing'),
          },
        ),
      ],
    );
    final migrated = library.migrateAllLegacyArtwork();
    final restored = SkillLibrary.fromJson(
        jsonDecode(jsonEncode(migrated.toJson())));
    final originals = [...library.overrides.values, ...library.custom];
    final results = [...restored.overrides.values, ...restored.custom];
    for (var i = 0; i < originals.length; i++) {
      for (final role in [
        SkillVisualRole.casting, SkillVisualRole.impact,
        SkillVisualRole.explosion,
      ]) {
        expect(restored.resolveVisual(results[i], role)?.spriteId,
            library.resolveVisual(originals[i], role)?.spriteId,
            reason: '${originals[i].id}: ${role.name}');
      }
    }
    expect(restored.migrateAllLegacyArtwork().effects.length,
        migrated.effects.length);
  });

  test('ID collision uses a suffix and preflight predicts effect count', () {
    const library = SkillLibrary(
      effects: {
        'legacy.custom.collision.casting': EffectDefinition(
          id: 'legacy.custom.collision.casting',
          name: 'Different', spriteId: 'unrelated.png'),
      },
      custom: [SkillDefinition(
        id: 'custom.collision', name: 'Collision',
        baseKind: PowerUpKind.pistol, custom: true,
        castingSpriteId: 'wanted.png',
      )],
    );
    final plan = library.planLegacyArtworkMigration();
    expect(plan.newEffects, 1);
    final migrated = library.migrateAllLegacyArtwork();
    expect(migrated.effects['legacy.custom.collision.casting']?.spriteId,
        'unrelated.png');
    expect(migrated.effects['legacy.custom.collision.casting.1']?.spriteId,
        'wanted.png');
    expect(migrated.effects.length - library.effects.length, plan.newEffects);
  });
}
