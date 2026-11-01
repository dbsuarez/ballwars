import 'skill_library.dart';

/// Gameplay contact admission for configured dual-mode weapons.
/// No legacy gun or non-composed skill is changed by this policy.
class SkillHybridContactPolicy {
  const SkillHybridContactPolicy._();

  static bool usesComposedContact(SkillDefinition skill) =>
      skill.isComposed &&
      (skill.trigger == SkillTrigger.collision ||
          (skill.trigger == SkillTrigger.aimedFire &&
              skill.effectiveWeaponClass == SkillWeaponClass.hybrid &&
              skill.meleeReach > 0));
}
