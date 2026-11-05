import 'package:ballwars/features/arena_simulation/domain/attack_emitter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saved placement mirrors horizontally without flipping vertical offset',
    () {
      const emitter = AttackEmitter(forward: 2, sideways: -0.5);
      expect(
        emitter.resolve(Offset.zero, 10, const Offset(1, 0)),
        const Offset(20, -5),
      );
      expect(
        emitter.resolve(Offset.zero, 10, const Offset(-1, 0)),
        const Offset(-20, -5),
      );
      expect(
        emitter.resolve(const Offset(3, 7), 20, const Offset(1, 0)),
        const Offset(43, -3),
      );
    },
  );

  test('automatic placement lets each attack preserve its original origin', () {
    const emitter = AttackEmitter();
    expect(emitter.resolve(Offset.zero, 10, Offset.zero), Offset.zero);
    expect(
      emitter.resolve(Offset.zero, 10, Offset.zero, automaticForward: 1),
      const Offset(10, 0),
    );
    expect(
      emitter.resolve(
        Offset.zero,
        10,
        const Offset(0, 1),
        automaticForward: 1.75,
      ),
      const Offset(0, 17.5),
    );
  });

  test('full-rotation legacy frame remains available', () {
    const emitter = AttackEmitter(forward: 2, sideways: -0.5, mirror: false);
    expect(
      emitter.resolve(Offset.zero, 10, const Offset(-1, 0)),
      const Offset(-20, 5),
    );
  });
}
