import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

SkillDefinition _skill(String id, {String? casting, String? impact,
    Map<SkillVisualRole, SkillVisualBinding> bindings = const {}}) =>
    SkillDefinition(
      id: id, name: id, custom: true, baseKind: PowerUpKind.energyWave,
      castingSpriteId: casting, impactSpriteId: impact,
      castingDurationSeconds: 1.75, castingScale: 1.4,
      castingFollowsActive: true, visualBindings: bindings,
    );

void _expectSameVisuals(SkillLibrary beforeLibrary, SkillDefinition before,
    SkillLibrary afterLibrary, SkillDefinition after) {
  expect(after.castingDurationSeconds, before.castingDurationSeconds);
  expect(after.castingScale, before.castingScale);
  expect(after.castingFollowsActive, before.castingFollowsActive);
  for (final role in [SkillVisualRole.casting, SkillVisualRole.impact,
    SkillVisualRole.explosion]) {
    final a = beforeLibrary.resolveVisual(before, role);
    final b = afterLibrary.resolveVisual(after, role);
    expect(b?.spriteId, a?.spriteId, reason: '${before.id}/${role.name} sprite');
    expect(b?.scale, a?.scale, reason: '${before.id}/${role.name} scale');
    expect(b?.opacity, a?.opacity, reason: '${before.id}/${role.name} opacity');
    expect(b?.tint, a?.tint, reason: '${before.id}/${role.name} tint');
    expect(b?.attachment, a?.attachment, reason: '${before.id}/${role.name} attachment');
    expect(b?.facing, a?.facing, reason: '${before.id}/${role.name} facing');
    expect(b?.offsetX, a?.offsetX, reason: '${before.id}/${role.name} x');
    expect(b?.offsetY, a?.offsetY, reason: '${before.id}/${role.name} y');
    expect(b?.rotationDegrees, a?.rotationDegrees, reason: '${before.id}/${role.name} rotation');
    expect(b?.playback, a?.playback, reason: '${before.id}/${role.name} playback');
    expect(b?.durationSeconds, a?.durationSeconds, reason: '${before.id}/${role.name} duration');
  }
}

void main() {
  test('bulk migration preserves mixed explicit, missing and legacy roles across JSON reload', () {
    final skills = [
      _skill('custom.both', casting: 'cast-a', impact: 'hit-a'),
      _skill('custom.explicit', impact: 'legacy-hit', bindings: {
        SkillVisualRole.impact: const SkillVisualBinding(effectId: 'custom-impact'),
      }),
      _skill('custom.missing', impact: 'fallback', bindings: {
        SkillVisualRole.explosion: const SkillVisualBinding(effectId: 'missing-event'),
      }),
      _skill('custom.only-cast', casting: 'cast-b'),
    ];
    final original = SkillLibrary(custom: skills, effects: const {
      'custom-impact': EffectDefinition(
        id: 'custom-impact', name: 'Explicit impact', spriteId: 'authored-hit',
      ),
    });
    final plan = original.planLegacyArtworkMigration();
    expect(plan.fitsCapacity, isTrue);
    expect(plan.blockedSlots, 1);
    final migrated = original.migrateAllLegacyArtwork();
    expect(migrated.effects.length - original.effects.length, plan.newEffects);
    final reloaded = SkillLibrary.fromJson(jsonDecode(jsonEncode(migrated.toJson())));
    for (var i = 0; i < skills.length; i++) {
      _expectSameVisuals(original, skills[i], reloaded, reloaded.custom[i]);
    }
    expect(reloaded.custom[2].impactSpriteId, 'fallback',
        reason: 'Missing Explosion event must retain its playable legacy fallback');
    final repeated = reloaded.migrateAllLegacyArtwork();
    expect(repeated.toJson(), reloaded.toJson(), reason: 'Conversion must be idempotent');
  });

  test('collision with authored non-neutral event preserves it and allocates a distinct event', () {
    final skill = _skill('custom.collision', casting: 'legacy-cast');
    final original = SkillLibrary(custom: [skill], effects: const {
      'legacy.custom.collision.casting': EffectDefinition(
        id: 'legacy.custom.collision.casting', name: 'Authored',
        spriteId: 'legacy-cast', scale: 2,
      ),
    });
    final migrated = original.migrateAllLegacyArtwork();
    expect(migrated.effects['legacy.custom.collision.casting']?.scale, 2);
    expect(migrated.custom.single.visualBindings[SkillVisualRole.casting]?.effectId,
        'legacy.custom.collision.casting.1');
    _expectSameVisuals(original, skill, migrated, migrated.custom.single);
  });

  test('capacity failure is atomic and preview warns before conversion', () {
    final existing = <String, EffectDefinition>{
      for (var i = 0; i < 256; i++)
        'occupied.$i': EffectDefinition(
          id: 'occupied.$i', name: 'Occupied $i', spriteId: 'sprite-$i',
        ),
    };
    final original = SkillLibrary(
      custom: [_skill('custom.capacity', casting: 'cast', impact: 'hit')],
      effects: existing,
    );
    final snapshot = jsonEncode(original.toJson());
    final plan = original.planLegacyArtworkMigration();
    expect(plan.newEffects, 2);
    expect(plan.availableEffectSlots, 0);
    expect(plan.fitsCapacity, isFalse);
    expect(() => original.migrateAllLegacyArtwork(), throwsFormatException);
    expect(jsonEncode(original.toJson()), snapshot,
        reason: 'Failed conversion cannot mutate the original library');
  });
}
