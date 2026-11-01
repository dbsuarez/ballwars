import 'skill_library.dart';

/// Advisory diagnostics for the phone skill editor. These are intentionally
/// non-blocking: old saves and experimental combinations remain loadable.
class SkillBehaviorDiagnostics {
  const SkillBehaviorDiagnostics._();

  static List<String> warnings(SkillDefinition skill) {
    final warnings = <String>[];
    if (skill.repeatCount > 1 && skill.repeatIntervalSeconds <= 0) {
      warnings.add('Repeated activations need a positive repeat interval.');
    }
    if (skill.effectSteps.isNotEmpty &&
        (skill.effectType != null || skill.secondaryEffectType != null)) {
      warnings.add('Effect steps take precedence over the legacy effect fields.');
    }
    if (skill.returnsToOrigin &&
        skill.delivery != SkillDelivery.projectile &&
        (skill.delivery != null ||
            skill.effectiveAttackDelivery != SkillAttackDelivery.throwWeapon)) {
      warnings.add('Return-to-origin requires a projectile or thrown weapon to have an effect.');
    }
    if (skill.homing && skill.delivery != SkillDelivery.projectile &&
        (skill.delivery != null ||
            skill.effectiveAttackDelivery != SkillAttackDelivery.fireProjectile)) {
      warnings.add('Homing has no effect without projectile delivery.');
    }
    if (skill.areaRadiusRatio != null &&
        skill.delivery != SkillDelivery.area &&
        skill.delivery != SkillDelivery.aura &&
        skill.delivery != SkillDelivery.boundaryHazard) {
      warnings.add('Area radius is configured but the selected delivery is not area-based.');
    }
    if (skill.projectileCount != null && skill.projectileCount! > 1 &&
        skill.delivery != SkillDelivery.projectile &&
        (skill.delivery != null ||
            skill.effectiveAttackDelivery != SkillAttackDelivery.fireProjectile)) {
      warnings.add('Projectile count may be ignored by this delivery mode.');
    }
    return List.unmodifiable(warnings);
  }
}
