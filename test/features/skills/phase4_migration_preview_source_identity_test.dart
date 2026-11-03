import 'dart:convert';

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

SkillDefinition _skill(String sprite) => SkillDefinition(
      id: 'custom.preview',
      name: 'Preview',
      custom: true,
      baseKind: PowerUpKind.energyWave,
      castingSpriteId: sprite,
    );

void main() {
  test('different artwork can produce identical migration counts', () {
    final before = SkillLibrary(custom: [_skill('first.png')]);
    final after = SkillLibrary(custom: [_skill('second.png')]);
    final oldPlan = before.planLegacyArtworkMigration();
    final newPlan = after.planLegacyArtworkMigration();
    expect(oldPlan.newEffects, newPlan.newEffects);
    expect(oldPlan.affectedSkills, newPlan.affectedSkills);
    expect(oldPlan.blockedSlots, newPlan.blockedSlots);
    // The confirmation guard must check source identity, not just counts.
    expect(jsonEncode(before.toJson()), isNot(jsonEncode(after.toJson())));
  });

  test('editor draft changes with identical preview counts are detectable', () {
    const library = SkillLibrary();
    final before = _skill('first.png');
    final after = _skill('second.png');
    final oldPlan = library.planLegacyArtworkMigrationForSkill(before);
    final newPlan = library.planLegacyArtworkMigrationForSkill(after);
    expect(oldPlan.newEffects, newPlan.newEffects);
    expect(oldPlan.reusedEffects, newPlan.reusedEffects);
    expect(jsonEncode(before.toJson()), isNot(jsonEncode(after.toJson())));
  });

  test('effect definition changes are detectable even with identical capacity', () {
    final before = SkillLibrary(effects: const {
      'event': EffectDefinition(id: 'event', name: 'Old', spriteId: 'first.png'),
    });
    final after = SkillLibrary(effects: const {
      'event': EffectDefinition(id: 'event', name: 'New', spriteId: 'second.png'),
    });
    expect(before.effects.length, after.effects.length);
    expect(jsonEncode(before.toJson()), isNot(jsonEncode(after.toJson())));
  });
}
