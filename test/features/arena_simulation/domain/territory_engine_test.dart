import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/territory_engine.dart';

void main() {
  test('all sectors start unowned', () {
    final engine = TerritoryEngine();
    expect(engine.sectorOwners.every((o) => o.isEmpty), isTrue);
    expect(engine.countSectors('a'), 0);
  });

  group('claimSector', () {
    test('transfers ownership of a single sector to the claimant', () {
      final engine = TerritoryEngine();

      final changed = engine.claimSector('a', 200);

      expect(changed, isTrue);
      expect(engine.sectorOwners[200], 'a');
      expect(engine.countSectors('a'), 1);
    });

    test('returns false and does nothing when already owned by the claimant', () {
      final engine = TerritoryEngine();
      engine.claimSector('a', 10);

      final changed = engine.claimSector('a', 10);

      expect(changed, isFalse);
      expect(engine.countSectors('a'), 1);
    });

    test('can be reclaimed by a different ball', () {
      final engine = TerritoryEngine();
      engine.claimSector('a', 10);

      final changed = engine.claimSector('b', 10);

      expect(changed, isTrue);
      expect(engine.sectorOwners[10], 'b');
    });
  });

  group('evaluateWinCondition', () {
    test('does not declare a winner when nobody has claimed anything yet', () {
      final engine = TerritoryEngine();
      engine.evaluateWinCondition(['a', 'b'], allContestantsStarted: false);
      expect(engine.winnerId, isNull);
    });

    test('does not declare an elimination winner before all contestants have started', () {
      final engine = TerritoryEngine();
      // Only 'a' has claimed anything so far; 'b' hasn't touched the rim yet.
      for (var i = 0; i < 10; i++) {
        engine.claimSector('a', i);
      }

      engine.evaluateWinCondition(['a', 'b'], allContestantsStarted: false);

      expect(engine.winnerId, isNull);
    });

    test('declares an elimination winner once all contestants have started and only one holds territory', () {
      final engine = TerritoryEngine();
      for (var i = 0; i < 10; i++) {
        engine.claimSector('a', i);
      }

      engine.evaluateWinCondition(['a', 'b'], allContestantsStarted: true);

      expect(engine.winnerId, 'a');
    });

    test('declares a domination winner once a ball reaches all 360 sectors regardless of start state', () {
      final engine = TerritoryEngine();
      for (var i = 0; i < 360; i++) {
        engine.claimSector('a', i);
      }

      engine.evaluateWinCondition(['a', 'b'], allContestantsStarted: false);

      expect(engine.winnerId, 'a');
    });
  });

  group('isSlowMotion', () {
    test('is false while no ball has claimed any territory', () {
      final engine = TerritoryEngine();
      expect(engine.isSlowMotion(), isFalse);
    });

    test('a small starting seed alone does not trigger slow motion', () {
      final engine = TerritoryEngine();
      // A brand new match: both balls just touched the rim for the first
      // time and only own their tiny starting seed (e.g. 7 sectors).
      for (var i = 0; i < 7; i++) {
        engine.claimSector('a', i);
      }
      engine.updatePeaks(['a', 'b']);

      expect(engine.isSlowMotion(), isFalse);
    });

    test('becomes true once a ball drops to 15 or fewer sectors after having exceeded that', () {
      final engine = TerritoryEngine();
      for (var i = 0; i < 20; i++) {
        engine.claimSector('a', i);
      }
      engine.updatePeaks(['a', 'b']);
      expect(engine.isSlowMotion(), isFalse);

      for (var i = 0; i < 6; i++) {
        engine.claimSector('b', i);
      }
      engine.updatePeaks(['a', 'b']);

      expect(engine.countSectors('a'), 14);
      expect(engine.isSlowMotion(), isTrue);
    });
  });
}
