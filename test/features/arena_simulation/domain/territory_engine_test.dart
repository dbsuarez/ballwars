import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/domain/territory_engine.dart';

void main() {
  group('initializeSplit', () {
    test('splits 360 sectors evenly among 2 balls', () {
      final engine = TerritoryEngine(2, SeededRandom(1));
      engine.initializeSplit(['a', 'b']);
      expect(engine.countSectors('a'), 180);
      expect(engine.countSectors('b'), 180);
      expect(engine.sectorOwners[0], 'a');
      expect(engine.sectorOwners[179], 'a');
      expect(engine.sectorOwners[180], 'b');
      expect(engine.sectorOwners[359], 'b');
    });

    test('splits 360 sectors evenly among 4 balls', () {
      final engine = TerritoryEngine(4, SeededRandom(1));
      engine.initializeSplit(['a', 'b', 'c', 'd']);
      expect(engine.countSectors('a'), 90);
      expect(engine.countSectors('b'), 90);
      expect(engine.countSectors('c'), 90);
      expect(engine.countSectors('d'), 90);
    });
  });

  group('resolveSteal', () {
    test('reassigns a clamped amount of sectors from loser to winner', () {
      final engine = TerritoryEngine(2, SeededRandom(5));
      engine.initializeSplit(['a', 'b']);
      final before = engine.countSectors('b');

      final result = engine.resolveSteal(winnerId: 'a', loserId: 'b');

      expect(result.stolenCount, inInclusiveRange(10, 75));
      expect(engine.countSectors('b'), before - result.stolenCount);
      expect(engine.countSectors('a'), 180 + result.stolenCount);
    });

    test('cannot steal more sectors than the loser owns', () {
      final engine = TerritoryEngine(2, SeededRandom(2));
      engine.initializeSplit(['a', 'b']);
      // Drain b down to 5 sectors via repeated steals.
      while (engine.countSectors('b') > 5) {
        engine.resolveSteal(winnerId: 'a', loserId: 'b');
      }
      final remaining = engine.countSectors('b');
      final result = engine.resolveSteal(winnerId: 'a', loserId: 'b');
      expect(result.stolenCount, remaining);
      expect(engine.countSectors('b'), 0);
    });
  });

  group('win + slow motion detection', () {
    test('winnerId is null while match is contested', () {
      final engine = TerritoryEngine(2, SeededRandom(1));
      engine.initializeSplit(['a', 'b']);
      expect(engine.winnerId, isNull);
    });

    test('winnerId is set once a ball reaches 360 sectors', () {
      final engine = TerritoryEngine(2, SeededRandom(3));
      engine.initializeSplit(['a', 'b']);
      while (engine.countSectors('b') > 0) {
        engine.resolveSteal(winnerId: 'a', loserId: 'b');
      }
      expect(engine.countSectors('a'), 360);
      expect(engine.winnerId, 'a');
    });

    test('isSlowMotion becomes true once a ball drops to 15 or fewer sectors', () {
      final engine = TerritoryEngine(2, SeededRandom(4));
      engine.initializeSplit(['a', 'b']);
      expect(engine.isSlowMotion(), isFalse);
      while (engine.countSectors('b') > 15) {
        engine.resolveSteal(winnerId: 'a', loserId: 'b');
      }
      expect(engine.isSlowMotion(), isTrue);
    });
  });
}
