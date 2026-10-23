import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';

void main() {
  test('every kind has a label and the guns are flagged', () {
    const guns = {
      PowerUpKind.pistol,
      PowerUpKind.shotgun,
      PowerUpKind.gatling,
      PowerUpKind.freeze,
      PowerUpKind.grenade,
      PowerUpKind.hook,
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

  test('pickups are categorized as either weapons or power-ups', () {
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
        PowerUpKind.mine,
        PowerUpKind.magnet,
        PowerUpKind.ghost,
      ]),
    );
    expect(
      PowerUpKind.values.every((kind) => kind.isWeapon != kind.isPowerUp),
      isTrue,
    );
  });
}
