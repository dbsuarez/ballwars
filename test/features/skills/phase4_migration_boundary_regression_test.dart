import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

SkillDefinition legacySkill(String id, {String? casting, String? impact,
    Map<SkillVisualRole, SkillVisualBinding> bindings = const {}}) =>
    SkillDefinition(id: id, name: id, custom: true,
      baseKind: PowerUpKind.energyWave, castingSpriteId: casting,
      impactSpriteId: impact, visualBindings: bindings);

void main() {
  test('neutral generated event is reused without consuming capacity', () {
    final skill = legacySkill('custom.reuse', casting: 'cast-art');
    final original = SkillLibrary(custom: [skill], effects: const {
      'legacy.custom.reuse.casting': EffectDefinition(
        id: 'legacy.custom.reuse.casting', name: 'Existing neutral',
        spriteId: 'cast-art'),
    });
    final plan = original.planLegacyArtworkMigration();
    expect(plan.newEffects, 0);
    expect(plan.reusedEffects, 1);
    final migrated = original.migrateAllLegacyArtwork();
    expect(migrated.effects.length, original.effects.length);
    expect(migrated.custom.single.visualBindings[SkillVisualRole.casting]?.effectId,
        'legacy.custom.reuse.casting');
    expect(migrated.migrateAllLegacyArtwork().toJson(), migrated.toJson());
  });

  test('explicit impact retains separate legacy explosion after roundtrip', () {
    final skill = legacySkill('custom.explosion', impact: 'old-explosion',
      bindings: {SkillVisualRole.impact:
        const SkillVisualBinding(effectId: 'new-impact')});
    final original = SkillLibrary(custom: [skill], effects: const {
      'new-impact': EffectDefinition(id: 'new-impact',
        name: 'New impact', spriteId: 'new-impact-art'),
    });
    final preview = original.planLegacyArtworkMigration();
    expect(preview.newEffects, 1);
    final converted = original.migrateAllLegacyArtwork();
    final loaded = SkillLibrary.fromJson(jsonDecode(jsonEncode(converted.toJson())));
    final result = loaded.custom.single;
    expect(result.impactSpriteId, isNull);
    expect(result.visualBindings[SkillVisualRole.impact]?.effectId, 'new-impact');
    expect(loaded.resolveVisual(result, SkillVisualRole.impact)?.spriteId,
        original.resolveVisual(skill, SkillVisualRole.impact)?.spriteId);
    expect(loaded.resolveVisual(result, SkillVisualRole.explosion)?.spriteId,
        original.resolveVisual(skill, SkillVisualRole.explosion)?.spriteId);
    expect(loaded.migrateAllLegacyArtwork().toJson(), loaded.toJson());
  });

  test('dangling explicit casting event never discards playable fallback', () {
    final skill = legacySkill('custom.missing-cast', casting: 'fallback-cast',
      bindings: {SkillVisualRole.casting:
        const SkillVisualBinding(effectId: 'missing')});
    final original = SkillLibrary(custom: [skill]);
    expect(original.planLegacyArtworkMigration().blockedSlots, 1);
    final migrated = original.migrateAllLegacyArtwork();
    expect(migrated.custom.single.castingSpriteId, 'fallback-cast');
    expect(migrated.custom.single.visualBindings[SkillVisualRole.casting]?.effectId,
        'missing');
    expect(migrated.effects, isEmpty);
  });
}
