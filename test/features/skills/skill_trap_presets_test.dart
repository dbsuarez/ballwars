import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/domain/skill_trap_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = SkillDefinition(
    id: 'custom.trap', name: 'My trap', baseKind: PowerUpKind.pistol,
    custom: true, category: SkillCategory.trap,
    arsenalDamage: 7, effectType: SkillEffectType.freeze,
  );

  test('each preset produces positive intervals and radius', () {
    for (final preset in SkillTrapPreset.values) {
      final result = SkillTrapPresets.apply(original, preset);
      expect(result.triggerIntervalSeconds, greaterThan(0));
      expect(result.tickIntervalSeconds, greaterThan(0));
      expect(result.areaRadiusRatio, greaterThan(0));
      expect(result.resolvedCategory, SkillCategory.trap);
    }
  });

  test('presets retain skill identity, damage and effects', () {
    for (final preset in SkillTrapPreset.values) {
      final result = SkillTrapPresets.apply(original, preset);
      expect(result.id, original.id);
      expect(result.name, original.name);
      expect(result.arsenalDamage, original.arsenalDamage);
      expect(result.effectType, original.effectType);
      expect(result.custom, isTrue);
    }
  });

  test('arena traps stay arena traps', () {
    final arena = original.copyWith(category: SkillCategory.arenaTrap);
    expect(SkillTrapPresets.apply(arena, SkillTrapPreset.timedPulse).resolvedCategory,
        SkillCategory.arenaTrap);
  });

  test('contact preset uses collision trigger', () {
    final result = SkillTrapPresets.apply(original, SkillTrapPreset.contactTrap);
    expect(result.trigger, SkillTrigger.collision);
    expect(result.delivery, SkillDelivery.area);
  });

  test('persistent preset uses boundary hazard delivery', () {
    final result = SkillTrapPresets.apply(original, SkillTrapPreset.persistentHazard);
    expect(result.delivery, SkillDelivery.boundaryHazard);
  });

  test('applying a preset does not mutate the original', () {
    SkillTrapPresets.apply(original, SkillTrapPreset.timedPulse);
    expect(original.delivery, isNull);
    expect(original.areaRadiusRatio, isNull);
  });
}
