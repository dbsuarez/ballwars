import 'skill_library.dart';

/// Editor-only guidance. Never changes skill data or runtime behavior.
enum SkillAdviceCategory { delivery, timing, targeting, trap, effects, projectile, presentation }

class SkillBehaviorAdvice {
  const SkillBehaviorAdvice(this.category, this.message, this.suggestion);
  final SkillAdviceCategory category;
  final String message;
  final String suggestion;
}

class SkillBehaviorAdvisor {
  const SkillBehaviorAdvisor._();

  static List<SkillBehaviorAdvice> review(SkillDefinition skill) {
    final notes = <SkillBehaviorAdvice>[];
    void add(SkillAdviceCategory category, String message, String suggestion) {
      notes.add(SkillBehaviorAdvice(category, message, suggestion));
    }

    if (skill.repeatCount > 1 && skill.repeatIntervalSeconds <= 0) {
      add(SkillAdviceCategory.timing, 'Repeated activations have no positive interval.',
          'Set Repeat interval above zero, or use one activation.');
    }
    if (skill.startDelaySeconds < 0 || skill.cooldownSeconds < 0 ||
        skill.triggerIntervalSeconds < 0 || skill.tickIntervalSeconds <= 0) {
      add(SkillAdviceCategory.timing, 'One or more timing settings are outside the recommended range.',
          'Use non-negative delays and cooldowns, and a positive tick interval.');
    }
    if (skill.effectSteps.isNotEmpty &&
        (skill.effectType != null || skill.secondaryEffectType != null)) {
      add(SkillAdviceCategory.effects, 'Effect steps override the legacy effect fields.',
          'Edit the ordered effect steps to change what this skill applies.');
    }
    final projectile = skill.delivery == SkillDelivery.projectile ||
        skill.effectiveAttackDelivery == SkillAttackDelivery.fireProjectile ||
        skill.effectiveAttackDelivery == SkillAttackDelivery.throwWeapon;
    if (skill.homing && !projectile) {
      add(SkillAdviceCategory.delivery, 'Homing may be ignored for this delivery.',
          'Choose projectile or a projectile-based attack delivery.');
    }
    if (skill.returnsToOrigin && !projectile) {
      add(SkillAdviceCategory.delivery, 'Return-to-origin may be ignored for this delivery.',
          'Choose projectile or thrown-weapon delivery.');
    }
    if (skill.projectileCount != null && skill.projectileCount! > 1 && !projectile) {
      add(SkillAdviceCategory.delivery, 'Multiple projectiles may be ignored for this delivery.',
          'Use a projectile-based delivery, or set projectile count to one.');
    }
    final area = skill.delivery == SkillDelivery.area ||
        skill.delivery == SkillDelivery.aura ||
        skill.delivery == SkillDelivery.boundaryHazard;
    if (skill.areaRadiusRatio != null && !area) {
      add(SkillAdviceCategory.delivery, 'Area radius may be ignored for this delivery.',
          'Choose area, aura, or boundary hazard delivery.');
    }
    if (skill.resolvedCategory == SkillCategory.arenaTrap &&
        skill.delivery != null && skill.delivery != SkillDelivery.boundaryHazard &&
        skill.delivery != SkillDelivery.area) {
      add(SkillAdviceCategory.trap, 'Arena trap uses a non-area delivery.',
          'Check whether area or boundary hazard delivery better matches the intended trap.');
    }
    if (skill.resolvedCategory == SkillCategory.trap && skill.homing) {
      add(SkillAdviceCategory.trap, 'Homing is enabled on a trap.',
          'Confirm that this trap actually launches a projectile before relying on homing.');
    }
    if (skill.targeting == SkillTargeting.self &&
        skill.mechanicalEffects.contains(SkillEffectType.damage)) {
      add(SkillAdviceCategory.targeting, 'Damage is configured with self targeting.',
          'Confirm self damage is intended, or choose an opponent target.');
    }
    if (skill.projectileCount != null && skill.projectileCount! <= 0) {
      add(SkillAdviceCategory.projectile, 'Projectile count is not positive.',
          'Use at least one projectile when configuring a projectile attack.');
    }
    if (skill.projectileSpeed != null && skill.projectileSpeed! <= 0 && projectile) {
      add(SkillAdviceCategory.projectile, 'Projectile speed is not positive.',
          'Set a positive projectile speed for a moving projectile.');
    }
    if (skill.projectileSize <= 0 || skill.projectileHitRadius <= 0) {
      add(SkillAdviceCategory.projectile, 'Projectile size or hit radius is not positive.',
          'Set positive projectile size and hit radius values.');
    }
    if (skill.maxBounces != null && skill.maxBounces! < 0) {
      add(SkillAdviceCategory.projectile, 'Maximum bounces is negative.',
          'Set maximum bounces to zero or greater.');
    }
    if (skill.areaRadiusRatio != null && skill.areaRadiusRatio! <= 0 && area) {
      add(SkillAdviceCategory.trap, 'Area radius is not positive.',
          'Set a positive radius for an area or trap effect.');
    }
    if (skill.areaGuideOpacity < 0 || skill.areaGuideOpacity > 1) {
      add(SkillAdviceCategory.presentation, 'Area guide opacity is outside 0 to 1.',
          'Use an opacity between 0 (invisible) and 1 (opaque).');
    }
    if (skill.weaponDisplayScale <= 0 || skill.pickupDisplayScale <= 0 ||
        skill.effectDisplayScale <= 0) {
      add(SkillAdviceCategory.presentation, 'One or more display scales are not positive.',
          'Use positive weapon, pickup, and effect display scales.');
    }
    return List.unmodifiable(notes);
  }
}
