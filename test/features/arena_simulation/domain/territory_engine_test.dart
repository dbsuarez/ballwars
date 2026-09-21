import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/territory_engine.dart';

void main() {
  group('initializeSplit', () {
    test('splits 360 sectors evenly among 2 balls', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b']);
      expect(engine.countSectors('a'), 180);
      expect(engine.countSectors('b'), 180);
      expect(engine.sectorOwners[0], 'a');
      expect(engine.sectorOwners[179], 'a');
      expect(engine.sectorOwners[180], 'b');
      expect(engine.sectorOwners[359], 'b');
    });

    test('splits 360 sectors evenly among 4 balls', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b', 'c', 'd']);
      expect(engine.countSectors('a'), 90);
      expect(engine.countSectors('b'), 90);
      expect(engine.countSectors('c'), 90);
      expect(engine.countSectors('d'), 90);
    });
  });

  group('claimSector', () {
    test('transfers ownership of a single sector to the claimant', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b']);

      final changed = engine.claimSector('a', 200);

      expect(changed, isTrue);
      expect(engine.sectorOwners[200], 'a');
      expect(engine.countSectors('a'), 181);
      expect(engine.countSectors('b'), 179);
    });

    test('returns false and does nothing when already owned by the claimant', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b']);

      final changed = engine.claimSector('a', 10);

      expect(changed, isFalse);
      expect(engine.countSectors('a'), 180);
    });

    test('can claim non-contiguous sectors independently', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b']);

      engine.claimSector('a', 200);
      engine.claimSector('a', 350);

      expect(engine.sectorOwners[200], 'a');
      expect(engine.sectorOwners[350], 'a');
      expect(engine.sectorOwners[201], 'b');
    });
  });

  group('win + slow motion detection', () {
    test('winnerId is null while match is contested', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b']);
      expect(engine.winnerId, isNull);
    });

    test('winnerId is set once a ball reaches 360 sectors', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b']);
      for (var i = 180; i < 360; i++) {
        engine.claimSector('a', i);
      }
      expect(engine.countSectors('a'), 360);
      expect(engine.winnerId, 'a');
    });

    test('isSlowMotion becomes true once a ball drops to 15 or fewer sectors', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b']);
      expect(engine.isSlowMotion(), isFalse);
      for (var i = 180; i < 345; i++) {
        engine.claimSector('a', i);
      }
      expect(engine.countSectors('b'), 15);
      expect(engine.isSlowMotion(), isTrue);
    });
  });
}
