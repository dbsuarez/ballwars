import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';

void main() {
  test('sweep only spans occupied bearings, including the wrap boundary', () {
    final targets = [350.0, 10.0, 30.0].map((degrees) =>
        Offset.fromDirection(degrees * math.pi / 180, 100)).toList();
    final (start, end) = EnergyWaveAttack.sweepBounds(Offset.zero, targets);
    expect(end - start, lessThan(math.pi));
    for (final target in targets) {
      final bearing = (target.direction - start) % (2 * math.pi);
      expect(bearing, inInclusiveRange(0.0, end - start));
    }
  });

  test('one opponent gets a short sweep rather than a complete rotation', () {
    final (start, end) = EnergyWaveAttack.sweepBounds(Offset.zero, [const Offset(100, 0)]);
    expect(end - start, closeTo(0.3, 0.00001));
  });
}
