import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pistol = SkillDefinition(
    id: 'test.pistol', name: 'Pistol', baseKind: PowerUpKind.pistol,
  );
  const boomerang = SkillDefinition(
    id: 'test.boomerang', name: 'Boomerang', baseKind: PowerUpKind.boomerang,
  );

  test('legacy skills infer presentation without modifying their JSON', () {
    expect(pistol.weaponClass, isNull);
    expect(pistol.attackDelivery, isNull);
    expect(pistol.effectiveWeaponClass, SkillWeaponClass.ranged);
    expect(pistol.effectiveAttackDelivery, SkillAttackDelivery.fireProjectile);
    expect(boomerang.effectiveAttackDelivery, SkillAttackDelivery.throwWeapon);
    expect(boomerang.hidesHeldDuringFlight, isTrue);
    expect(pistol.toJson().containsKey('weapon_class'), isFalse);
    expect(pistol.toJson().containsKey('attack_delivery'), isFalse);
  });

  test('all authoring classifications persist without changing mechanical delivery', () {
    for (final weaponClass in SkillWeaponClass.values) {
      for (final attack in SkillAttackDelivery.values) {
        final edited = pistol.copyWith(
          weaponClass: weaponClass,
          attackDelivery: attack,
        );
        final restored = SkillDefinition.fromJson(edited.toJson())!;
        expect(restored.weaponClass, weaponClass);
        expect(restored.attackDelivery, attack);
        expect(restored.delivery, pistol.delivery);
        expect(restored.hidesHeldDuringFlight, isFalse);
      }
    }
  });

  test('optional metadata can be cleared and old records still load', () {
    final edited = boomerang.copyWith(
      weaponClass: SkillWeaponClass.hybrid,
      attackDelivery: SkillAttackDelivery.thrust,
      hideHeldWhileThrown: false,
    );
    final reset = edited.copyWith(weaponClass: null, attackDelivery: null);
    expect(reset.weaponClass, isNull);
    expect(reset.attackDelivery, isNull);
    expect(reset.hidesHeldDuringFlight, isFalse);
    expect(SkillDefinition.fromJson(boomerang.toJson())!.hidesHeldDuringFlight, isTrue);
  });
}
