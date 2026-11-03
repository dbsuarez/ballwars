import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
