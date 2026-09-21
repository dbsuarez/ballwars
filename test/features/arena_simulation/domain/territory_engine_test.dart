import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/utils/seeded_random.dart';
import 'package:ballwars/features/arena_simulation/domain/territory_engine.dart';

/// A ball's owned sectors should always form a single contiguous circular
/// arc (or own none/all of them) — never split into disconnected chunks.
bool isSingleContiguousArc(List<String> owners, String id) {
  final total = owners.length;
  var transitions = 0;
  for (var i = 0; i < total; i++) {
    final current = owners[i] == id;
    final next = owners[(i + 1) % total] == id;
    if (current != next) transitions++;
  }
  return transitions <= 2;
}

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

    test('repeated steals with alternating winners keep each side contiguous', () {
      final engine = TerritoryEngine(2, SeededRandom(11));
      engine.initializeSplit(['a', 'b']);

      engine.resolveSteal(winnerId: 'a', loserId: 'b');
      engine.resolveSteal(winnerId: 'b', loserId: 'a');
      engine.resolveSteal(winnerId: 'a', loserId: 'b');
      engine.resolveSteal(winnerId: 'b', loserId: 'a');
      engine.resolveSteal(winnerId: 'a', loserId: 'b');

      expect(isSingleContiguousArc(engine.sectorOwners, 'a'), isTrue);
      expect(isSingleContiguousArc(engine.sectorOwners, 'b'), isTrue);
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
