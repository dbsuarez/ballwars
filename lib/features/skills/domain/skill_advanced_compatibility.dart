import '../../arena_simulation/domain/power_up.dart';
import 'skill_library.dart';

/// Read-only compatibility checks for advanced weapons. Never silently
/// rewrite saved skill definitions or replace their legacy behavior.
class SkillAdvancedCompatibility {
  const SkillAdvancedCompatibility._();

  static bool get isNativeAdvancedSupported => true;

  static bool usesNativeAdvancedRuntime(SkillDefinition skill) =>
      !skill.isComposed &&
      (skill.baseKind == PowerUpKind.shadowClone ||
          skill.baseKind == PowerUpKind.omegaTendrils);

  static List<String> issues(SkillDefinition skill) {
    final issues = <String>[];
    if (skill.effectiveWeaponClass == SkillWeaponClass.hybrid) {
      if (skill.meleeReach <= 0) {
        issues.add('Hybrid weapons need a melee reach greater than zero.');
      }
      if (skill.delivery != SkillDelivery.projectile &&
          skill.delivery != SkillDelivery.beam &&
          !skill.baseKind.isGun) {
        issues.add('Hybrid weapons need a ranged delivery or a gun base kind.');
      }
    }
    // Legacy built-in weapons have no composed delivery field. Their native
    // runtime already handles returning throws and homing projectiles.
    // Only reject a composed skill or an explicit incompatible delivery.
    final requiresComposedProjectile =
        skill.isComposed || skill.delivery != null;
    if (skill.returnsToOrigin &&
        requiresComposedProjectile &&
        skill.delivery != SkillDelivery.projectile) {
      issues.add('Returning weapons require projectile delivery.');
    }
    if (skill.homing &&
        requiresComposedProjectile &&
        skill.delivery != SkillDelivery.projectile) {
      issues.add('Homing requires projectile delivery.');
    }
    if (skill.isComposed && skill.baseKind == PowerUpKind.shadowClone) {
      issues.add('Composed Shadow Clone uses composed effects, not the native cinematic clone sequence.');
    }
    if (skill.isComposed && skill.baseKind == PowerUpKind.omegaTendrils) {
      issues.add('Composed Omega Tendrils uses composed effects, not the native grab-and-throw sequence.');
    }
    return List.unmodifiable(issues);
  }
}
