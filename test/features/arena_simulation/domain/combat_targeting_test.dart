import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/combat_targeting.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

SimulationBall contestant(String id, Offset position) => SimulationBall(
  config: CustomBall(
    id: id,
    name: id,
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
  position: position,
  velocity: Offset.zero,
  radius: 10,
  lineCount: 0,
);

void main() {
  test(
    'historical rules preserve contestant order without retention or visibility preference',
    () {
      final first = contestant('z', const Offset(50, 0));
      final second = contestant('a', const Offset(-50, 0));
      expect(
        CombatTargeting.select(
          origin: Offset.zero,
          candidates: [first, second],
          legacyOrder: true,
        ),
        same(first),
      );
      expect(
        CombatTargeting.select(
          origin: Offset.zero,
          candidates: [first, second],
        ),
        same(second),
      );
      first.position = const Offset(110, 0);
      second.position = const Offset(100, 0);
      expect(
        CombatTargeting.select(
          origin: Offset.zero,
          candidates: [first, second],
          previous: first,
          legacyOrder: true,
        ),
        same(second),
      );
      expect(
        CombatTargeting.select(
          origin: Offset.zero,
          candidates: [first, second],
          previous: first,
        ),
        same(first),
      );
    },
  );

  group('combat target stability', () {
    test('nearest is selected independent of contestant list order', () {
      final a = contestant('a', const Offset(50, 0));
      final b = contestant('b', const Offset(-50, 0));
      expect(
        CombatTargeting.select(origin: Offset.zero, candidates: [b, a]),
        same(a),
      );
      expect(
        CombatTargeting.select(origin: Offset.zero, candidates: [a, b]),
        same(a),
      );
    });

    test('minor distance changes do not thrash an existing target', () {
      final old = contestant('old', const Offset(110, 0));
      final close = contestant('close', const Offset(100, 0));
      expect(
        CombatTargeting.select(
          origin: Offset.zero,
          candidates: [old, close],
          previous: old,
        ),
        same(old),
      );
      old.position = const Offset(130, 0);
      expect(
        CombatTargeting.select(
          origin: Offset.zero,
          candidates: [old, close],
          previous: old,
        ),
        same(close),
      );
    });

    test(
      'match-specific eligibility excludes contestants not yet marked eliminated',
      () {
        final exhausted = contestant('exhausted', const Offset(5, 0));
        final healthy = contestant('healthy', const Offset(40, 0));
        // Elimination is finalized after the combat step; a ball can be out
        // of life/threads before its isEliminated flag is updated.
        exhausted.life = 0.5;
        healthy.life = 100;
        expect(
          CombatTargeting.select(
            origin: Offset.zero,
            candidates: [exhausted, healthy],
            previous: exhausted,
            isEligible: (ball) => ball.life >= 1,
          ),
          same(healthy),
        );
        expect(
          CombatTargeting.select(
            origin: Offset.zero,
            candidates: [exhausted],
            isEligible: (ball) => ball.life >= 1,
          ),
          isNull,
        );
      },
    );

    test(
      'eliminated, ghost, owner, hit-history and invalid targets are skipped',
      () {
        final owner = contestant('owner', Offset.zero);
        final eliminated = contestant('dead', const Offset(1, 0))
          ..isEliminated = true;
        final ghost = contestant('ghost', const Offset(2, 0))..ghostLeft = 3;
        final invalid = contestant('invalid', const Offset(double.nan, 0));
        final hit = contestant('hit', const Offset(3, 0));
        final alive = contestant('alive', const Offset(15, 0));
        expect(
          CombatTargeting.select(
            origin: Offset.zero,
            candidates: [owner, eliminated, ghost, invalid, hit, alive],
            owner: owner,
            excluded: {hit},
            previous: eliminated,
          ),
          same(alive),
        );
        expect(
          CombatTargeting.select(
            origin: Offset.zero,
            candidates: [owner, eliminated, ghost],
            owner: owner,
          ),
          isNull,
        );
        expect(
          CombatTargeting.select(
            origin: const Offset(double.nan, 0),
            candidates: [alive],
          ),
          isNull,
        );
      },
    );
  });

  group('center obstacle line of sight', () {
    for (final obstacle in [CenterObstacle.circle, CenterObstacle.square]) {
      test('$obstacle blocks paths through its middle', () {
        expect(
          CombatTargeting.centerObstacleBlocks(
            const Offset(-60, 0),
            const Offset(60, 0),
            obstacle,
            20,
          ),
          isTrue,
        );
        expect(
          CombatTargeting.centerObstacleBlocks(
            const Offset(-60, 40),
            const Offset(60, 40),
            obstacle,
            20,
          ),
          isFalse,
        );
      });

      test('$obstacle prioritizes a clear opponent over blocked one', () {
        final blocked = contestant('blocked', const Offset(45, 0));
        final clear = contestant('clear', const Offset(-50, 35));
        expect(
          CombatTargeting.select(
            origin: const Offset(-50, 0),
            candidates: [blocked, clear],
            obstacle: obstacle,
            obstacleExtent: 20,
          ),
          same(clear),
        );
      });

      test('$obstacle falls back if every candidate is obstructed', () {
        final far = contestant('far', const Offset(80, 0));
        final near = contestant('near', const Offset(45, 0));
        expect(
          CombatTargeting.select(
            origin: const Offset(-60, 0),
            candidates: [far, near],
            obstacle: obstacle,
            obstacleExtent: 20,
          ),
          same(near),
        );
      });
    }

    test('no obstacle preserves ordinary distance priority', () {
      final near = contestant('near', const Offset(45, 0));
      final far = contestant('far', const Offset(-55, 25));
      expect(
        CombatTargeting.select(
          origin: const Offset(-60, 0),
          candidates: [near, far],
        ),
        same(far),
      );
    });

    test('grazing a square edge does not count as obstruction', () {
      expect(
        CombatTargeting.centerObstacleBlocks(
          const Offset(-50, 20),
          const Offset(50, 20),
          CenterObstacle.square,
          20,
        ),
        isFalse,
      );
    });

    test('missing or invalid geometry safely reports no obstruction', () {
      expect(
        CombatTargeting.centerObstacleBlocks(
          const Offset(-20, 0),
          const Offset(20, 0),
          CenterObstacle.none,
          10,
        ),
        isFalse,
      );
      expect(
        CombatTargeting.centerObstacleBlocks(
          const Offset(-20, 0),
          const Offset(20, 0),
          CenterObstacle.circle,
          double.nan,
        ),
        isFalse,
      );
    });
  });
}
