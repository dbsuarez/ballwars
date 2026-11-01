import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const roles = [
    SkillVisualRole.casting,
    SkillVisualRole.impact,
    SkillVisualRole.explosion,
  ];

  test('bulk migration preserves resolved artwork across a mixed library', () {
    final library = SkillLibrary(
      effects: const {
        'authored.impact': EffectDefinition(
          id: 'authored.impact', name: 'Authored impact',
          spriteId: 'authored.png', scale: 1.4,
        ),
      },
      overrides: const {
        'builtin.pistol': SkillDefinition(
          id: 'builtin.pistol', name: 'Pistol',
          baseKind: PowerUpKind.pistol,
          castingSpriteId: 'pistol-cast.png',
          impactSpriteId: 'pistol-hit.png',
        ),
      },
      custom: const [
        SkillDefinition(
          id: 'custom.authored', name: 'Authored',
          baseKind: PowerUpKind.pistol, custom: true,
          castingSpriteId: 'custom-cast.png',
          impactSpriteId: 'legacy-explosion.png',
          visualBindings: {
            SkillVisualRole.impact:
                SkillVisualBinding(effectId: 'authored.impact'),
          },
        ),
        SkillDefinition(
          id: 'custom.blocked', name: 'Blocked',
          baseKind: PowerUpKind.pistol, custom: true,
          castingSpriteId: 'still-playable.png',
          visualBindings: {
            SkillVisualRole.casting:
                SkillVisualBinding(effectId: 'external.missing'),
          },
        ),
      ],
    );
    final originals = [
      ...library.overrides.values,
      ...library.custom,
    ];
    final before = {
      for (final skill in originals)
        skill.id: {for (final role in roles) role: library.resolveVisual(skill, role)},
    };
    final preview = library.planLegacyArtworkMigration();
    expect(preview.blockedSlots, 1);
    expect(preview.fitsCapacity, isTrue);
    final migrated = library.migrateAllLegacyArtwork();
    expect(migrated.effects.length - library.effects.length, preview.newEffects);
    for (final skill in [...migrated.overrides.values, ...migrated.custom]) {
      for (final role in roles) {
        final old = before[skill.id]![role];
        final current = migrated.resolveVisual(skill, role);
        expect(current?.spriteId, old?.spriteId, reason: '${skill.id} ${role.name} sprite');
        expect(current?.scale, old?.scale, reason: '${skill.id} ${role.name} scale');
        expect(current?.opacity, old?.opacity, reason: '${skill.id} ${role.name} opacity');
        expect(current?.playback, old?.playback, reason: '${skill.id} ${role.name} playback');
      }
    }
    expect(migrated.custom.last.castingSpriteId, 'still-playable.png');
    expect(library.effects.length, 1, reason: 'Original must remain immutable');
    final second = migrated.migrateAllLegacyArtwork();
    expect(second.toJson(), migrated.toJson(), reason: 'Migration must be idempotent');
    final restored = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    // Loading applies current defaults (for example, the optional yell field).
    // Verify that migration itself remains stable after hydration.
    expect(restored.migrateAllLegacyArtwork().toJson(), restored.toJson(),
        reason: 'Loaded migration must remain idempotent');
    for (final skill in [...restored.overrides.values, ...restored.custom]) {
      final previous = [...migrated.overrides.values, ...migrated.custom]
          .firstWhere((item) => item.id == skill.id);
      for (final role in roles) {
        expect(restored.resolveVisual(skill, role)?.spriteId,
            migrated.resolveVisual(previous, role)?.spriteId,
            reason: 'Save/load must preserve ${skill.id} ${role.name} artwork');
      }
    }
  });

  test('preflight and conversion agree when existing generated ID is non-neutral', () {
    const skill = SkillDefinition(
      id: 'custom.collision', name: 'Collision',
      baseKind: PowerUpKind.pistol, custom: true,
      castingSpriteId: 'same.png', impactSpriteId: 'impact.png',
    );
    const library = SkillLibrary(
      custom: [skill],
      effects: {
        'legacy.custom.collision.casting': EffectDefinition(
          id: 'legacy.custom.collision.casting',
          name: 'Custom animation', spriteId: 'same.png', opacity: 0.4,
        ),
      },
    );
    final plan = library.planLegacyArtworkMigration();
    expect(plan.newEffects, 2);
    expect(plan.reusedEffects, 0);
    final migrated = library.migrateAllLegacyArtwork();
    expect(migrated.effects.length - library.effects.length, plan.newEffects);
    expect(migrated.custom.single.visualBindings[SkillVisualRole.casting]?.effectId,
        'legacy.custom.collision.casting.1');
    expect(migrated.effects['legacy.custom.collision.casting']?.opacity, 0.4);
  });
}
