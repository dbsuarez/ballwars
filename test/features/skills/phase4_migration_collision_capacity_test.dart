import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

SkillDefinition _skill(String id, {String? casting, String? impact}) =>
    SkillDefinition(
      id: id,
      name: id,
      custom: true,
      baseKind: PowerUpKind.energyWave,
      castingSpriteId: casting,
      impactSpriteId: impact,
    );

void main() {
  group('Phase 4 collision and capacity safety', () {
    test('non-neutral generated ID must not be reused', () {
      final library = SkillLibrary(custom: [
        _skill('custom.collision', casting: 'cast-original'),
      ], effects: const {
        'legacy.custom.collision.casting': EffectDefinition(
          id: 'legacy.custom.collision.casting',
          name: 'Authored event',
          spriteId: 'cast-original',
          opacity: .5,
        ),
      });
      final plan = library.planLegacyArtworkMigration();
      expect(plan.newEffects, 1);
      expect(plan.reusedEffects, 0);
      final migrated = library.migrateAllLegacyArtwork();
      expect(migrated.custom.single.visualBindings[SkillVisualRole.casting]!
          .effectId, 'legacy.custom.collision.casting.1');
      expect(migrated.effects['legacy.custom.collision.casting']!.opacity, .5);
      expect(migrated.resolveVisual(migrated.custom.single,
          SkillVisualRole.casting)?.spriteId, 'cast-original');
      expect(migrated.migrateAllLegacyArtwork().toJson(), migrated.toJson());
    });

    test('capacity preflight refuses atomic bulk conversion', () {
      final effects = <String, EffectDefinition>{
        for (var i = 0; i < 256; i++)
          'authored.$i': EffectDefinition(
            id: 'authored.$i', name: 'Authored $i', spriteId: 'sprite-$i'),
      };
      final original = SkillLibrary(
        custom: [_skill('custom.capacity', casting: 'cast-new')],
        effects: effects,
      );
      final before = jsonEncode(original.toJson());
      final plan = original.planLegacyArtworkMigration();
      expect(plan.newEffects, 1);
      expect(plan.fitsCapacity, isFalse);
      expect(() => original.migrateAllLegacyArtwork(), throwsFormatException);
      expect(jsonEncode(original.toJson()), before);
    });

    test('two legacy roles migrate together and remain stable on reload', () {
      final original = SkillLibrary(custom: [
        _skill('custom.dual', casting: 'cast-original', impact: 'hit-original'),
      ]);
      final plan = original.planLegacyArtworkMigration();
      expect(plan.newEffects, 2);
      final converted = original.migrateAllLegacyArtwork();
      final reloaded = SkillLibrary.fromJson(
          jsonDecode(jsonEncode(converted.toJson())));
      final skill = reloaded.custom.single;
      expect(skill.castingSpriteId, isNull);
      expect(skill.impactSpriteId, isNull);
      expect(reloaded.resolveVisual(skill, SkillVisualRole.casting)?.spriteId,
          'cast-original');
      expect(reloaded.resolveVisual(skill, SkillVisualRole.impact)?.spriteId,
          'hit-original');
      expect(reloaded.resolveVisual(skill, SkillVisualRole.explosion)?.spriteId,
          'hit-original');
      expect(reloaded.migrateAllLegacyArtwork().toJson(), reloaded.toJson());
    });
  });
}
