import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/territory_engine.dart';

void main() {
  group('initializeSplit', () {
    test('splits 360 sectors evenly among 2 balls and records their starting origin', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b'], [const Offset(1, 1), const Offset(2, 2)]);
      expect(engine.countSectors('a'), 180);
      expect(engine.countSectors('b'), 180);
      expect(engine.sectorOwners[0], 'a');
      expect(engine.sectorOwners[179], 'a');
      expect(engine.sectorOwners[180], 'b');
      expect(engine.sectorOwners[359], 'b');
      expect(engine.sectorClaimOrigin[0], const Offset(1, 1));
      expect(engine.sectorClaimOrigin[180], const Offset(2, 2));
    });

    test('splits 360 sectors evenly among 4 balls', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(
        ['a', 'b', 'c', 'd'],
        [Offset.zero, Offset.zero, Offset.zero, Offset.zero],
      );
      expect(engine.countSectors('a'), 90);
      expect(engine.countSectors('b'), 90);
      expect(engine.countSectors('c'), 90);
      expect(engine.countSectors('d'), 90);
    });
  });

  group('claimSector', () {
    test('transfers ownership and freezes the claim origin at the given position', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b'], [Offset.zero, Offset.zero]);

      final changed = engine.claimSector('a', 200, const Offset(50, 60));

      expect(changed, isTrue);
      expect(engine.sectorOwners[200], 'a');
      expect(engine.sectorClaimOrigin[200], const Offset(50, 60));
      expect(engine.countSectors('a'), 181);
      expect(engine.countSectors('b'), 179);
    });

    test('returns false and does nothing when already owned by the claimant', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b'], [Offset.zero, Offset.zero]);

      final changed = engine.claimSector('a', 10, const Offset(99, 99));

      expect(changed, isFalse);
      expect(engine.countSectors('a'), 180);
      expect(engine.sectorClaimOrigin[10], Offset.zero);
    });

    test('a later claim by the same ball moves the frozen origin again', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b'], [Offset.zero, Offset.zero]);

      engine.claimSector('a', 200, const Offset(10, 10));
      engine.claimSector('b', 200, const Offset(20, 20));
      engine.claimSector('a', 200, const Offset(30, 30));

      expect(engine.sectorOwners[200], 'a');
      expect(engine.sectorClaimOrigin[200], const Offset(30, 30));
    });

    test('can claim non-contiguous sectors independently', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b'], [Offset.zero, Offset.zero]);

      engine.claimSector('a', 200, const Offset(1, 1));
      engine.claimSector('a', 350, const Offset(2, 2));

      expect(engine.sectorOwners[200], 'a');
      expect(engine.sectorOwners[350], 'a');
      expect(engine.sectorOwners[201], 'b');
    });
  });

  group('win + slow motion detection', () {
    test('winnerId is null while match is contested', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b'], [Offset.zero, Offset.zero]);
      expect(engine.winnerId, isNull);
    });

    test('winnerId is set once a ball reaches 360 sectors', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b'], [Offset.zero, Offset.zero]);
      for (var i = 180; i < 360; i++) {
        engine.claimSector('a', i, Offset.zero);
      }
      expect(engine.countSectors('a'), 360);
      expect(engine.winnerId, 'a');
    });

    test('isSlowMotion becomes true once a ball drops to 15 or fewer sectors', () {
      final engine = TerritoryEngine();
      engine.initializeSplit(['a', 'b'], [Offset.zero, Offset.zero]);
      expect(engine.isSlowMotion(), isFalse);
      for (var i = 180; i < 345; i++) {
        engine.claimSector('a', i, Offset.zero);
      }
      expect(engine.countSectors('b'), 15);
      expect(engine.isSlowMotion(), isTrue);
    });
  });
}
