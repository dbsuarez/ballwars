import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';

void main() {
  test('every kind has a label and the guns are flagged', () {
    const guns = {
      PowerUpKind.pistol,
      PowerUpKind.shotgun,
      PowerUpKind.gatling,
      PowerUpKind.freeze,
      PowerUpKind.grenade,
      PowerUpKind.hook,
      PowerUpKind.ricochetDisc,
      PowerUpKind.threadHarpoon,
      PowerUpKind.prismLaser,
      PowerUpKind.swapCannon,
      PowerUpKind.bow,
      PowerUpKind.molotov,
      PowerUpKind.rocketLauncher,
    };
    for (final kind in PowerUpKind.values) {
      expect(kind.label, isNotEmpty);
      expect(kind.isGun, guns.contains(kind), reason: kind.name);
    }
    const damaging = [
      PowerUpKind.pistol,
      PowerUpKind.shotgun,
      PowerUpKind.gatling,
      PowerUpKind.knife,
      PowerUpKind.mine,
      PowerUpKind.grenade,
      PowerUpKind.sword,
      PowerUpKind.hook,
    ];
    for (final kind in damaging) {
      expect(
        PowerUpTuning.arenaDamage.containsKey(kind),
        isTrue,
        reason: kind.name,
      );
      expect(
        PowerUpTuning.allOutThreads.containsKey(kind),
        isTrue,
        reason: kind.name,
      );
    }
    expect(PowerUpTuning.aimSteps, 60);
  });

  test('pickups are categorized as weapons, power-ups or traps', () {
    expect(
      PowerUpKind.values.where((kind) => kind.isWeapon),
      containsAll([
        PowerUpKind.pistol,
        PowerUpKind.shield,
        PowerUpKind.freeze,
        PowerUpKind.sword,
      ]),
    );
    expect(
      PowerUpKind.values.where((kind) => kind.isPowerUp),
      containsAll([
        PowerUpKind.apple,
        PowerUpKind.speed,
        PowerUpKind.magnet,
        PowerUpKind.ghost,
      ]),
    );
    expect(
      PowerUpKind.values.where((kind) => kind.isTrap),
      containsAll([
        PowerUpKind.mine,
        PowerUpKind.phaseMine,
        PowerUpKind.portal,
        PowerUpKind.spikeWall,
        PowerUpKind.stickyGoo,
      ]),
    );
    expect(
      PowerUpKind.values.every(
        (kind) =>
            [
              kind.isWeapon,
              kind.isPowerUp,
              kind.isTrap,
            ].where((v) => v).length ==
            1,
      ),
      isTrue,
    );
  });

  test(
    'only items that directly deal configured damage qualify for finishers',
    () {
      final damaging = PowerUpKind.values
          .where((kind) => kind.dealsDamage(PowerUpConfig.defaults))
          .toSet();
      expect(damaging, containsAll(PowerUpConfig.damageKinds));
      expect(damaging, contains(PowerUpKind.shield));
      for (final utility in const [
        PowerUpKind.apple,
        PowerUpKind.speed,
        PowerUpKind.freeze,
        PowerUpKind.portal,
        PowerUpKind.stickyGoo,
        PowerUpKind.goldenArmor,
      ]) {
        expect(damaging, isNot(contains(utility)), reason: utility.name);
      }
    },
  );
}
