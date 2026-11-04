import 'dart:math' as math;

import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recoil kicks backward then returns to resting grip', () {
    final begin = PowerUpPainter.heldAttackPose(0, 1, HeldAttackAnimation.recoil);
    final kick = PowerUpPainter.heldAttackPose(.5, 1, HeldAttackAnimation.recoil);
    final end = PowerUpPainter.heldAttackPose(1, 1, HeldAttackAnimation.recoil);
    expect(kick.forward, lessThan(begin.forward));
    expect(end.forward, closeTo(begin.forward, 0.00001));
    expect(kick.rotation.abs(), greaterThan(0));
  });

  test('throw arc advances outward and mirrors orientation', () {
    final start = PowerUpPainter.heldAttackPose(0, 1, HeldAttackAnimation.throwArc);
    final mid = PowerUpPainter.heldAttackPose(.5, 1, HeldAttackAnimation.throwArc);
    final end = PowerUpPainter.heldAttackPose(1, 1, HeldAttackAnimation.throwArc);
    expect(mid.forward, greaterThan(start.forward));
    expect(end.forward, greaterThan(mid.forward));
    expect(PowerUpPainter.heldAttackSwingRotation(math.pi, mid.rotation, 0),
        closeTo(-PowerUpPainter.heldAttackSwingRotation(0, mid.rotation, 0), .00001));
  });

  test('new visual modes serialize and leave damage delivery unchanged', () {
    final sword = SkillLibrary.defaults.builtIn(PowerUpKind.sword, PowerUpConfig.defaults);
    final gun = sword.copyWith(heldAttackAnimation: HeldAttackAnimation.recoil);
    final thrower = sword.copyWith(heldAttackAnimation: HeldAttackAnimation.throwArc);
    expect(SkillDefinition.fromJson(gun.toJson())!.heldAttackAnimation,
        HeldAttackAnimation.recoil);
    expect(SkillDefinition.fromJson(thrower.toJson())!.heldAttackAnimation,
        HeldAttackAnimation.throwArc);
    expect(gun.effectiveAttackDelivery, sword.effectiveAttackDelivery);
    expect(thrower.effectiveAttackDelivery, sword.effectiveAttackDelivery);
  });
}
