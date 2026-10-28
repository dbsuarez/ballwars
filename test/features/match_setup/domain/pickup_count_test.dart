import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/match_setup/domain/pickup_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pickups = PowerUpKind.values.where((kind) => !kind.isTrap).length;

  test('everything on counts every non-trap kind', () {
    expect(pickupCount(PowerUpKind.values, 0, 0), (pickups, pickups));
  });

  test('traps are never counted, on or off', () {
    final traps = PowerUpKind.values.where((kind) => kind.isTrap);
    expect(traps, isNotEmpty);
    expect(pickupCount(traps, 0, 0), (0, pickups));
  });

  test('custom skills add to both numbers', () {
    expect(pickupCount(PowerUpKind.values, 2, 5), (pickups + 2, pickups + 5));
    expect(pickupCount(const [], 0, 3), (0, pickups + 3));
  });

  test('a partial selection counts only the chosen kinds, once each', () {
    final some = [PowerUpKind.knife, PowerUpKind.knife, PowerUpKind.pistol];
    expect(pickupCount(some, 1, 1), (3, pickups + 1));
  });
}
