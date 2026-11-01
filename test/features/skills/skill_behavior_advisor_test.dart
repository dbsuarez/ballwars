import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_behavior_advisor.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = SkillDefinition(
    id: 'custom.advisor', name: 'Advisor', baseKind: PowerUpKind.pistol,
    custom: true,
  );

  test('default configuration has no advisory messages', () {
    expect(SkillBehaviorAdvisor.review(base), isEmpty);
  });

  test('timing advice is actionable and non-mutating', () {
    final skill = base.copyWith(repeatCount: 2, repeatIntervalSeconds: 0);
    final advice = SkillBehaviorAdvisor.review(skill);
    expect(advice.any((item) => item.category == SkillAdviceCategory.timing), isTrue);
    expect(advice.first.suggestion, contains('Repeat interval'));
    expect(skill.repeatIntervalSeconds, 0);
  });

  test('projectile delivery permits homing, return and multiple shots', () {
    final skill = base.copyWith(delivery: SkillDelivery.projectile,
        homing: true, returnsToOrigin: true, projectileCount: 4);
    expect(SkillBehaviorAdvisor.review(skill), isEmpty);
  });

  test('non-projectile delivery explains incompatible projectile options', () {
    final skill = base.copyWith(delivery: SkillDelivery.instant,
        attackDelivery: SkillAttackDelivery.swing,
        homing: true, returnsToOrigin: true, projectileCount: 4);
    final advice = SkillBehaviorAdvisor.review(skill);
    expect(advice.where((item) => item.category == SkillAdviceCategory.delivery), hasLength(3));
  });

  test('arena traps get delivery guidance', () {
    final skill = base.copyWith(category: SkillCategory.arenaTrap,
        delivery: SkillDelivery.instant);
    expect(SkillBehaviorAdvisor.review(skill).any(
        (item) => item.category == SkillAdviceCategory.trap), isTrue);
  });

  test('self targeting with damage gets a warning', () {
    final skill = base.copyWith(targeting: SkillTargeting.self,
        effectType: SkillEffectType.damage);
    expect(SkillBehaviorAdvisor.review(skill).any(
        (item) => item.category == SkillAdviceCategory.targeting), isTrue);
  });
  test('invalid projectile count and speed are reported separately', () {
    final skill = base.copyWith(delivery: SkillDelivery.projectile,
        projectileCount: 0, projectileSpeed: 0);
    final advice = SkillBehaviorAdvisor.review(skill);
    expect(advice.where((item) => item.category == SkillAdviceCategory.projectile),
        hasLength(2));
  });

  test('invalid bounce and collision geometry have actionable suggestions', () {
    final skill = base.copyWith(maxBounces: -1, projectileSize: 0,
        projectileHitRadius: 0);
    final advice = SkillBehaviorAdvisor.review(skill);
    expect(advice.where((item) => item.category == SkillAdviceCategory.projectile),
        hasLength(2));
    expect(advice.every((item) => item.suggestion.isNotEmpty), isTrue);
  });

  test('trap radius must be positive when area delivery is selected', () {
    final skill = base.copyWith(category: SkillCategory.trap,
        delivery: SkillDelivery.area, areaRadiusRatio: 0);
    expect(SkillBehaviorAdvisor.review(skill).any((item) =>
        item.category == SkillAdviceCategory.trap &&
        item.message.contains('radius')), isTrue);
  });

  test('presentation warnings do not change persisted skill values', () {
    final skill = base.copyWith(areaGuideOpacity: 2,
        weaponDisplayScale: 0, pickupDisplayScale: -1);
    final advice = SkillBehaviorAdvisor.review(skill);
    expect(advice.where((item) => item.category == SkillAdviceCategory.presentation),
        hasLength(2));
    expect(skill.areaGuideOpacity, 2);
    expect(skill.pickupDisplayScale, -1);
  });

  test('valid projectile and area settings do not produce extra advice', () {
    final projectile = base.copyWith(delivery: SkillDelivery.projectile,
        projectileCount: 3, projectileSpeed: 4, maxBounces: 0);
    final area = base.copyWith(delivery: SkillDelivery.area, areaRadiusRatio: .5);
    expect(SkillBehaviorAdvisor.review(projectile), isEmpty);
    expect(SkillBehaviorAdvisor.review(area), isEmpty);
  });

}
