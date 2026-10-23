import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';

void main() {
  test('every kind has a label and the guns are flagged', () {
    const guns = {PowerUpKind.pistol, PowerUpKind.shotgun, PowerUpKind.gatling, PowerUpKind.freeze, PowerUpKind.grenade, PowerUpKind.hook};
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
      expect(PowerUpTuning.arenaDamage.containsKey(kind), isTrue, reason: kind.name);
      expect(PowerUpTuning.allOutThreads.containsKey(kind), isTrue, reason: kind.name);
    }
    expect(PowerUpTuning.aimSteps, 60);
  });
}
