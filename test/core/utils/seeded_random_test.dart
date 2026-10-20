import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';

void main() {
  test('same seed produces identical sequence', () {
    final a = SeededRandom(42);
    final b = SeededRandom(42);
    final seqA = List.generate(10, (_) => a.nextDouble());
    final seqB = List.generate(10, (_) => b.nextDouble());
    expect(seqA, equals(seqB));
  });

  test('nextDoubleRange stays within bounds', () {
    final r = SeededRandom(7);
    for (var i = 0; i < 100; i++) {
      final v = r.nextDoubleRange(10, 20);
      expect(v, inInclusiveRange(10, 20));
    }
  });

  test('nextInt respects max exclusive bound', () {
    final r = SeededRandom(1);
    for (var i = 0; i < 100; i++) {
      final v = r.nextInt(5);
      expect(v, greaterThanOrEqualTo(0));
      expect(v, lessThan(5));
    }
  });
}
