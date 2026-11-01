import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/domain/skill_behavior_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = SkillDefinition(
    id: 'custom.sample', name: 'Sample', baseKind: PowerUpKind.pistol,
    custom: true, category: SkillCategory.weapon,
    arsenalDamage: 17, effectType: SkillEffectType.freeze,
  );

  test('aimed shot sets directional projectile delivery', () {
    final skill = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.aimedProjectile);
    expect(skill.delivery, SkillDelivery.projectile);
    expect(skill.targeting, SkillTargeting.chosenDirection);
    expect(skill.homing, isFalse);
    expect(skill.returnsToOrigin, isFalse);
  });

  test('seeking shot enables homing with valid projectile delivery', () {
    final skill = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.seekingProjectile);
    expect(skill.homing, isTrue);
    expect(skill.targeting, SkillTargeting.nearestOpponent);
    expect(skill.attackDelivery, SkillAttackDelivery.fireProjectile);
  });

  test('returning throw selects thrown weapon delivery', () {
    final skill = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.returningThrow);
    expect(skill.returnsToOrigin, isTrue);
    expect(skill.attackDelivery, SkillAttackDelivery.throwWeapon);
    expect(skill.delivery, SkillDelivery.projectile);
  });

  test('area burst sets an explicit radius', () {
    final skill = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.areaBurst);
    expect(skill.delivery, SkillDelivery.area);
    expect(skill.areaRadiusRatio, closeTo(0.2, 0.00001));
  });

  test('all presets preserve identity, category, damage, effects and custom flag', () {
    for (final preset in SkillBehaviorPreset.values) {
      final skill = SkillBehaviorPresets.apply(original, preset);
      expect(skill.id, original.id);
      expect(skill.name, original.name);
      expect(skill.category, original.category);
      expect(skill.arsenalDamage, original.arsenalDamage);
      expect(skill.effectType, original.effectType);
      expect(skill.custom, isTrue);
    }
  });

  test('preset application leaves the source definition unchanged', () {
    SkillBehaviorPresets.apply(original, SkillBehaviorPreset.returningThrow);
    expect(original.delivery, isNull);
    expect(original.attackDelivery, isNull);
    expect(original.returnsToOrigin, isFalse);
  });
  test('reactive self effect uses a nonzero cooldown', () {
    final result = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.reactiveShield);
    expect(result.trigger, SkillTrigger.damageTaken);
    expect(result.targeting, SkillTargeting.self);
    expect(result.delivery, SkillDelivery.instant);
    expect(result.cooldownSeconds, 3);
  });

  test('elimination pulse activates an area effect', () {
    final result = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.eliminationPulse);
    expect(result.trigger, SkillTrigger.elimination);
    expect(result.delivery, SkillDelivery.area);
    expect(result.areaRadiusRatio, closeTo(0.2, 0.00001));
    expect(result.cooldownSeconds, 2);
  });

  test('periodic aura uses a positive timer interval', () {
    final result = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.periodicAura);
    expect(result.trigger, SkillTrigger.timer);
    expect(result.delivery, SkillDelivery.aura);
    expect(result.triggerIntervalSeconds, 4);
    expect(result.areaRadiusRatio, closeTo(0.15, 0.00001));
  });

  test('directional beam does not enable projectile homing', () {
    final result = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.piercingBeam);
    expect(result.delivery, SkillDelivery.beam);
    expect(result.attackDelivery, SkillAttackDelivery.beam);
    expect(result.homing, isFalse);
    expect(result.targeting, SkillTargeting.chosenDirection);
  });

  test('opponent sweep targets everyone without a projectile', () {
    final result = SkillBehaviorPresets.apply(original, SkillBehaviorPreset.opponentSweep);
    expect(result.targeting, SkillTargeting.allOpponents);
    expect(result.delivery, SkillDelivery.instant);
    expect(result.returnsToOrigin, isFalse);
  });

  test('new presets do not overwrite existing timing unless explicitly set', () {
    final source = original.copyWith(cooldownSeconds: 9, triggerIntervalSeconds: 7);
    final result = SkillBehaviorPresets.apply(source, SkillBehaviorPreset.piercingBeam);
    expect(result.cooldownSeconds, 9);
    expect(result.triggerIntervalSeconds, 7);
    expect(source.delivery, isNull);
  });

}
