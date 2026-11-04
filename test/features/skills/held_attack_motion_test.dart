import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Slash wind-up, smooth forward arc and follow-through', () {
    final start = PowerUpPainter.heldAttackPose(0, 1, HeldAttackAnimation.slash);
    final windup = PowerUpPainter.heldAttackPose(.18, 1, HeldAttackAnimation.slash);
    final mid = PowerUpPainter.heldAttackPose(.49, 1, HeldAttackAnimation.slash);
    final finish = PowerUpPainter.heldAttackPose(1, 1, HeldAttackAnimation.slash);
    expect(windup.rotation, lessThan(start.rotation));
    expect(mid.rotation, greaterThan(windup.rotation));
    expect(finish.rotation, greaterThan(mid.rotation));
    expect(PowerUpPainter.heldAttackPose(.49, 1, HeldAttackAnimation.slash).sideways,
        greaterThan(0));
  });

  test('Thrust anticipates then extends forward without a second strike', () {
    final beginning = PowerUpPainter.heldAttackPose(0, 1, HeldAttackAnimation.thrust);
    final windup = PowerUpPainter.heldAttackPose(.18, 1, HeldAttackAnimation.thrust);
    final mid = PowerUpPainter.heldAttackPose(.50, 1, HeldAttackAnimation.thrust);
    final finish = PowerUpPainter.heldAttackPose(1, 1, HeldAttackAnimation.thrust);
    expect(windup.forward, lessThan(beginning.forward));
    expect(mid.forward, greaterThan(windup.forward));
    expect(finish.forward, greaterThan(mid.forward));
  });

  test('one attack has one forward sweep and no return', () {
    final samples = [for (var i = 0; i <= 30; i++)
      PowerUpPainter.heldAttackCyclePhase(i / 30, 1)];
    expect(samples.first, 0);
    expect(samples.last, 1);
    for (var i = 1; i < samples.length; i++) {
      expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
    }
  });

  test('configured repeats produce precisely the requested cycles', () {
    for (var repeats = 2; repeats <= 5; repeats++) {
      var resets = 0;
      var previous = 0.0;
      for (var i = 1; i < 300; i++) {
        final next = PowerUpPainter.heldAttackCyclePhase(i / 300, repeats);
        if (next < previous) resets++;
        previous = next;
      }
      expect(resets, repeats - 1);
      expect(PowerUpPainter.heldAttackCyclePhase(1, repeats), 1);
    }
  });
}
