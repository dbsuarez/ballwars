import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_advanced_compatibility.dart';
import 'package:ballwars/features/skills/domain/skill_behavior_presets.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = SkillDefinition(
    id: 'advanced.custom', name: 'Advanced', baseKind: PowerUpKind.pistol,
    custom: true, category: SkillCategory.weapon,
    effectType: SkillEffectType.damage,
  );

  test('hybrid presets create valid ranged and melee configuration', () {
    for (final preset in [SkillBehaviorPreset.hybridBladeShot,
                          SkillBehaviorPreset.hybridReturningBlade]) {
      final skill = SkillBehaviorPresets.apply(original, preset);
      expect(skill.effectiveWeaponClass, SkillWeaponClass.hybrid);
      expect(skill.meleeReach, greaterThan(0));
      expect(skill.delivery, SkillDelivery.projectile);
      expect(SkillAdvancedCompatibility.issues(skill), isEmpty);
    }
  });

  test('clone volley is composed but not the native cinematic', () {
    final skill = SkillBehaviorPresets.apply(
      const SkillDefinition(id: 'clone', name: 'Clone', baseKind: PowerUpKind.shadowClone, custom: true, effectType: SkillEffectType.damage),
      SkillBehaviorPreset.shadowCloneVolley,
    );
    expect(skill.isComposed, isTrue);
    expect(skill.projectileCount, 3);
    expect(skill.homing, isTrue);
    expect(SkillAdvancedCompatibility.usesNativeAdvancedRuntime(skill), isFalse);
    expect(SkillAdvancedCompatibility.issues(skill).single, contains('not the native'));
  });

  test('omega sweep uses pickup and all opponents', () {
    final skill = SkillBehaviorPresets.apply(
      const SkillDefinition(id: 'tendrils', name: 'Tendrils', baseKind: PowerUpKind.omegaTendrils, custom: true, effectType: SkillEffectType.damage),
      SkillBehaviorPreset.omegaTendrilSweep,
    );
    expect(skill.trigger, SkillTrigger.pickup);
    expect(skill.targeting, SkillTargeting.allOpponents);
    expect(skill.areaRadiusRatio, closeTo(.25, .00001));
    expect(SkillAdvancedCompatibility.issues(skill).single, contains('not the native'));
  });

  test('legacy advanced skill stays on native path', () {
    for (final kind in [PowerUpKind.shadowClone, PowerUpKind.omegaTendrils]) {
      final skill = SkillDefinition(id: 'legacy', name: 'Legacy', baseKind: kind);
      expect(SkillAdvancedCompatibility.usesNativeAdvancedRuntime(skill), isTrue);
    }
  });

  test('invalid hybrid and returning configurations report diagnostics', () {
    final skill = original.copyWith(
      weaponClass: SkillWeaponClass.hybrid,
      meleeReach: 0,
      delivery: SkillDelivery.instant,
      returnsToOrigin: true,
    );
    expect(SkillAdvancedCompatibility.issues(skill).length, 2);
  });

  test('presets preserve identity, effect and authoring flags', () {
    for (final preset in [SkillBehaviorPreset.hybridBladeShot,
      SkillBehaviorPreset.hybridReturningBlade,
      SkillBehaviorPreset.shadowCloneVolley,
      SkillBehaviorPreset.omegaTendrilSweep]) {
      final skill = SkillBehaviorPresets.apply(original, preset);
      expect(skill.id, original.id);
      expect(skill.effectType, original.effectType);
      expect(skill.custom, isTrue);
    }
  });
}
