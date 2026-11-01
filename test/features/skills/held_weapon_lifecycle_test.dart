import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/held_weapon_visibility.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SimulationBall ball(String id) => SimulationBall(
  config: CustomBall(id: id, name: id, primaryColor: Colors.blue,
      glowColor: Colors.white),
  position: Offset.zero, velocity: Offset.zero, radius: 12, lineCount: 1,
);

Projectile shot(SimulationBall owner, PowerUpKind kind) => Projectile(
  owner: owner, kind: kind, position: Offset.zero, velocity: Offset.zero,
);

void main() {
  const boomerang = SkillDefinition(
    id: 'weapon.boomerang', name: 'Boomerang', baseKind: PowerUpKind.boomerang,
  );
  const pistol = SkillDefinition(
    id: 'weapon.pistol', name: 'Pistol', baseKind: PowerUpKind.pistol,
  );

  test('thrown artwork lifecycle: launch, return/spend, and rethrow', () {
    final owner = ball('owner');
    final projectile = shot(owner, PowerUpKind.boomerang);
    bool hidden() => shouldHideHeldWeapon(skill: boomerang, owner: owner,
      kind: PowerUpKind.boomerang, projectiles: [projectile]);
    expect(hidden(), isTrue);
    projectile.returning = true;
    expect(hidden(), isTrue); // Still in flight on the return path.
    projectile.spent = true;
    expect(hidden(), isFalse);
    final next = shot(owner, PowerUpKind.boomerang);
    expect(shouldHideHeldWeapon(skill: boomerang, owner: owner,
      kind: PowerUpKind.boomerang, projectiles: [projectile, next]), isTrue);
    expect(shouldHideHeldWeapon(skill: boomerang, owner: owner,
      kind: PowerUpKind.boomerang, projectiles: []), isFalse);
  });

  test('owner and weapon identity isolate the visibility rule', () {
    final owner = ball('owner');
    final other = ball('other');
    final wrongOwner = shot(other, PowerUpKind.boomerang);
    final wrongKind = shot(owner, PowerUpKind.pistol);
    expect(shouldHideHeldWeapon(skill: boomerang, owner: owner,
      kind: PowerUpKind.boomerang, projectiles: [wrongOwner, wrongKind]), isFalse);
    expect(shouldHideHeldWeapon(skill: pistol, owner: owner,
      kind: PowerUpKind.pistol, projectiles: [wrongKind]), isFalse);
    expect(shouldHideHeldWeapon(skill: pistol.copyWith(hideHeldWhileThrown: true),
      owner: owner, kind: PowerUpKind.pistol, projectiles: [wrongKind]), isTrue);
    expect(shouldHideHeldWeapon(skill: boomerang.copyWith(hideHeldWhileThrown: false),
      owner: owner, kind: PowerUpKind.boomerang,
      projectiles: [shot(owner, PowerUpKind.boomerang)]), isFalse);
  });
}
