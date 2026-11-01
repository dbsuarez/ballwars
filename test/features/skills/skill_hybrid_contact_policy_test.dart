import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/domain/skill_hybrid_contact_policy.dart';

void main() {
  const base = SkillDefinition(
    id: 'hybrid', name: 'Hybrid', baseKind: PowerUpKind.sword,
    custom: true, trigger: SkillTrigger.aimedFire,
    targeting: SkillTargeting.nearestOpponent,
    delivery: SkillDelivery.projectile,
    effectType: SkillEffectType.damage,
    weaponClass: SkillWeaponClass.hybrid,
    meleeReach: 1,
  );
  test('hybrid aimed-fire can also activate on contact', () {
    expect(SkillHybridContactPolicy.usesComposedContact(base), isTrue);
  });
  test('zero-reach hybrid does not activate on contact', () {
    expect(SkillHybridContactPolicy.usesComposedContact(
      base.copyWith(meleeReach: 0)), isFalse);
  });
  test('ranged aimed-fire does not gain melee contact', () {
    expect(SkillHybridContactPolicy.usesComposedContact(
      base.copyWith(weaponClass: SkillWeaponClass.ranged)), isFalse);
  });
  test('collision composed skills retain contact activation', () {
    expect(SkillHybridContactPolicy.usesComposedContact(
      base.copyWith(trigger: SkillTrigger.collision)), isTrue);
  });
  test('non-composed legacy weapon is unchanged', () {
    const legacy = SkillDefinition(id: 'legacy', name: 'Legacy',
      baseKind: PowerUpKind.sword);
    expect(SkillHybridContactPolicy.usesComposedContact(legacy), isFalse);
  });
}
