import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import '../../skills/domain/skill_library.dart';

/// Rendering-only lifecycle rule. An equipped weapon is hidden only while
/// its owner has an unspent matching projectile in flight. A returned,
/// collected, or spent projectile restores the held artwork automatically.
bool shouldHideHeldWeapon({
  required SkillDefinition skill,
  required SimulationBall owner,
  required PowerUpKind kind,
  required Iterable<Projectile> projectiles,
}) {
  if (!skill.hidesHeldDuringFlight) return false;
  return projectiles.any((projectile) =>
      identical(projectile.owner, owner) &&
      projectile.kind == kind &&
      !projectile.spent);
}
