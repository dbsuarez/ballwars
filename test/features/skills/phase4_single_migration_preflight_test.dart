import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

SkillDefinition draft(String id, {String? casting, String? impact,
    Map<SkillVisualRole, SkillVisualBinding> bindings = const {}}) =>
    SkillDefinition(id: id, name: id, custom: true,
      baseKind: PowerUpKind.energyWave, castingSpriteId: casting,
      impactSpriteId: impact, visualBindings: bindings);

void main() {
  test('draft preview ignores other skills but respects existing effect IDs', () {
    final other = draft('custom.other', casting: 'other.png');
    final edited = draft('custom.edited', casting: 'edited.png', impact: 'impact.png');
    final library = SkillLibrary(custom: [other, edited]);
    final all = library.planLegacyArtworkMigration();
    final single = library.planLegacyArtworkMigrationForSkill(edited);
    expect(all.newEffects, 3);
    expect(single.newEffects, 2);
    expect(single.affectedSkills, 1);
    expect(single.availableEffectSlots, 256);
    expect(library.effects, isEmpty);
    expect(library.custom[1].castingSpriteId, 'edited.png');
  });

  test('draft preview detects capacity exhaustion without mutation', () {
    final effects = <String, EffectDefinition>{
      for (var i = 0; i < 256; i++)
        'used.$i': EffectDefinition(id: 'used.$i', name: 'Used', spriteId: 'other.png'),
    };
    final library = SkillLibrary(effects: effects);
    final edited = draft('custom.full', casting: 'new.png');
    final preview = library.planLegacyArtworkMigrationForSkill(edited);
    expect(preview.newEffects, 1);
    expect(preview.availableEffectSlots, 0);
    expect(preview.fitsCapacity, isFalse);
    expect(() => library.migrateLegacyArtwork(edited), throwsFormatException);
    expect(library.effects.length, 256);
  });

  test('draft preview preserves blocked legacy fallback', () {
    final edited = draft('custom.dangling', casting: 'legacy.png',
      bindings: {SkillVisualRole.casting:
        const SkillVisualBinding(effectId: 'missing')});
    const library = SkillLibrary();
    final preview = library.planLegacyArtworkMigrationForSkill(edited);
    expect(preview.blockedSlots, 1);
    expect(preview.hasChanges, isFalse);
    final result = library.migrateLegacyArtwork(edited);
    expect(result.skill.castingSpriteId, 'legacy.png');
    expect(result.library.effects, isEmpty);
  });

  test('draft preview correctly reports reusable neutral event', () {
    final edited = draft('custom.reuse', casting: 'legacy.png');
    final library = SkillLibrary(effects: const {
      'legacy.custom.reuse.casting': EffectDefinition(
        id: 'legacy.custom.reuse.casting', name: 'Reusable', spriteId: 'legacy.png'),
    });
    final preview = library.planLegacyArtworkMigrationForSkill(edited);
    expect(preview.newEffects, 0);
    expect(preview.reusedEffects, 1);
    expect(preview.hasChanges, isTrue);
    final migrated = library.migrateLegacyArtwork(edited);
    expect(migrated.library.effects.length, 1);
    expect(migrated.skill.castingSpriteId, isNull);
  });
}
