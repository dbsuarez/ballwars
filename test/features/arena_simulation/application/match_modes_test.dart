import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/fan_line.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _arenaRadius = 260.0;

const _balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
  CustomBall(
    id: 'c',
    name: 'C',
    primaryColor: Colors.green,
    glowColor: Colors.lightGreen,
  ),
];

/// (ball count, seed, winnerId, wallHits, ballHits, stepCount) of a full run with `slowMotionLines: 0`,
/// recorded on the controller before match modes existed (commit 02cba21, identical to master).
const _threadsBaseline = [
  (2, 1, 'b', 10, 4, 421),
  (2, 2, 'b', 24, 6, 806),
  (2, 3, 'b', 115, 23, 3724),
  (2, 4, 'a', 32, 8, 1079),
  (2, 5, 'b', 6, 2, 289),
  (2, 6, 'a', 6, 2, 300),
  (2, 7, 'a', 6, 2, 327),
  (2, 8, 'a', 19, 6, 811),
  (2, 9, 'b', 5, 2, 220),
  (2, 10, 'a', 40, 12, 1429),
  (2, 11, 'a', 38, 11, 1415),
  (2, 12, 'a', 10, 4, 421),
  (2, 13, 'b', 24, 6, 948),
  (2, 14, 'b', 8, 1, 349),
  (2, 15, 'a', 8, 1, 414),
  (2, 16, 'a', 77, 28, 2808),
  (2, 17, 'a', 7, 1, 367),
  (2, 18, 'b', 25, 9, 913),
  (2, 19, 'b', 28, 10, 1128),
  (2, 20, 'a', 9, 3, 378),
  (3, 1, 'a', 50, 0, 2527),
  (3, 2, 'a', 9, 0, 426),
  (3, 3, 'c', 13, 0, 650),
  (3, 4, 'b', 12, 0, 640),
  (3, 5, 'b', 13, 0, 686),
  (3, 6, 'c', 20, 0, 1000),
  (3, 7, 'a', 28, 0, 1508),
  (3, 8, 'b', 24, 0, 1265),
  (3, 9, 'a', 15, 0, 713),
  (3, 10, 'b', 29, 0, 1453),
  (3, 11, 'b', 18, 0, 1002),
  (3, 12, 'b', 45, 0, 2093),
  (3, 13, 'c', 16, 0, 838),
  (3, 14, 'b', 70, 0, 3533),
  (3, 15, 'c', 16, 0, 932),
  (3, 16, 'a', 48, 0, 2498),
  (3, 17, 'a', 5, 0, 303),
  (3, 18, 'c', 6, 0, 257),
  (3, 19, 'c', 37, 0, 2025),
  (3, 20, 'a', 24, 0, 1259),
];

SimulationBall _ball(MatchSimulationController c, String id) =>
    c.state.balls.firstWhere((b) => b.config.id == id);

MatchSimulationController _arsenal({int count = 2, int seed = 1}) =>
    MatchSimulationController(
      _balls.take(count).toList(),
      arenaRadius: _arenaRadius,
      seed: seed,
      layoutRotation: 0,
      mode: MatchMode.arsenal,
      lookAhead: false,
    );

void main() {
  test('Mayhem ends after two minutes and chooses the knockout leader', () {
    final contestants = List.generate(
      6,
      (index) => CustomBall(
        id: 'mayhem-$index',
        name: 'Ball $index',
        primaryColor: Colors.primaries[index],
        glowColor: Colors.primaries[index],
      ),
    );
    final match = MatchSimulationController(
      contestants,
      arenaRadius: _arenaRadius,
      seed: 7,
      mode: MatchMode.arsenal,
      endlessBattle: true,
      mayhem: true,
      lookAhead: false,
    );
    match.eliminations[contestants[3].id] = 4;
    match.eliminations[contestants[1].id] = 2;

    match.tick(MatchSimulationController.mayhemDurationSeconds);

    expect(match.state.status, MatchStatus.finished);
    expect(match.state.winnerId, contestants[3].id);
    expect(match.winningMove, 'Knockout lead');
  });

  test('Threads mode plays exactly as before', () {
    for (final (count, seed, winner, wallHits, ballHits, steps)
        in _threadsBaseline) {
      final c = MatchSimulationController(
        _balls.take(count).toList(),
        arenaRadius: _arenaRadius,
        seed: seed,
        slowMotionLines: 0,
        mode: MatchMode.threads,
      );
      var guard = 0;
      while (c.state.status != MatchStatus.finished && guard++ < 60 * 60 * 10) {
        c.tick(1 / 60);
      }
      final reason = '$count balls, seed $seed';
      expect(c.mode, MatchMode.threads);
      expect(c.powerUps, isNull);
      expect(c.state.powerUps, isNull);
      expect(c.state.winnerId, winner, reason: reason);
      expect(c.wallHits, wallHits, reason: reason);
      expect(c.ballHits, ballHits, reason: reason);
      expect(c.stepCount, steps, reason: reason);
    }
  });

  test('Threads is the default mode', () {
    final c = MatchSimulationController(
      _balls.take(2).toList(),
      arenaRadius: _arenaRadius,
      seed: 1,
    );
    expect(c.mode, MatchMode.threads);
    expect(c.powerUps, isNull);
  });

  test('Arsenal balls start with 100 life and no threads', () {
    final c = _arsenal(count: 3);
    for (final ball in c.state.balls) {
      expect(ball.life, PowerUpTuning.arenaLife);
      expect(ball.life, 100);
      expect(ball.fanLines, isEmpty);
    }
    expect(c.freeSlotCount, kRimSlotCount);
    expect(c.state.allActiveFanLines, isEmpty);
    expect(c.powerUps, isNotNull);
    expect(c.state.powerUps, same(c.powerUps));
    expect(c.powerUps!.field, isEmpty);
    expect(c.powerUps!.projectiles, isEmpty);
    expect(c.powerUps!.mines, isEmpty);
  });

  test('Arsenal wall hits claim no slots', () {
    final c = _arsenal();
    for (var i = 0; i < 600; i++) {
      c.tick(1 / 60);
    }
    expect(c.wallHits, greaterThan(0));
    expect(c.freeSlotCount, kRimSlotCount);
    for (final ball in c.state.balls) {
      expect(ball.fanLines, isEmpty);
      expect(ball.isEliminated, isFalse);
    }
    expect(c.state.status, isNot(MatchStatus.finished));
    expect(c.state.status, isNot(MatchStatus.slowMotion));
  });

  test('in Arsenal a ball at 0 life is out and the other wins', () {
    final c = _arsenal();
    final ballA = _ball(c, 'a');
    final ballB = _ball(c, 'b');
    c.damage(ballB, 1000);
    expect(ballB.life, 0, reason: 'life never goes below 0');
    c.tick(1 / 60);
    expect(ballB.isEliminated, isTrue);
    expect(ballA.isEliminated, isFalse);
    expect(c.state.winnerId, ballA.config.id);
    expect(c.state.status, MatchStatus.finished);
  });

  test('damage takes life off in Arsenal', () {
    final c = _arsenal();
    final ballA = _ball(c, 'a');
    c.damage(ballA, PowerUpTuning.arenaDamage[PowerUpKind.pistol]!);
    expect(ballA.life, 100 - PowerUpTuning.arenaDamage[PowerUpKind.pistol]!);
  });

  test('Arsenal same-step knockout of everyone still leaves one winner', () {
    for (var seed = 1; seed <= 10; seed++) {
      final c = _arsenal(seed: seed);
      for (final ball in c.state.balls) {
        c.damage(ball, 1000);
      }
      c.tick(1 / 60);
      expect(c.state.status, MatchStatus.finished, reason: 'seed $seed');
      expect(c.state.winnerId, isNotNull, reason: 'seed $seed');
      expect(
        c.state.balls.where((b) => !b.isEliminated).length,
        1,
        reason: 'seed $seed',
      );
    }
  });

  test('Arsenal bumps deal 5 damage to both balls', () {
    final c = _arsenal();
    final ballA = _ball(c, 'a');
    final ballB = _ball(c, 'b');
    ballA.position = const Offset(-10, 0);
    ballB.position = const Offset(10, 0);
    ballA.velocity = const Offset(100, 0);
    ballB.velocity = const Offset(-100, 0);
    c.tick(1 / 60);
    expect(c.ballHits, greaterThan(0));
    expect(ballA.life, 100 - PowerUpTuning.arenaCollisionDamage);
    expect(ballB.life, 100 - PowerUpTuning.arenaCollisionDamage);
  });

  test(
    'All-Out starts with threads like Threads mode and has a power-up system',
    () {
      final c = MatchSimulationController(
        _balls.take(2).toList(),
        arenaRadius: _arenaRadius,
        seed: 1,
        layoutRotation: 0,
        mode: MatchMode.allOut,
        lookAhead: false,
      );
      expect(c.powerUps, isNotNull);
      expect(_ball(c, 'a').fanLines.length, kRimSlotCount ~/ 2);
      expect(_ball(c, 'b').fanLines.length, kRimSlotCount ~/ 2);
      expect(c.freeSlotCount, 0);
    },
  );

  test('cutThreads frees the slots nearest to the hit first', () {
    final c = MatchSimulationController(
      _balls.take(2).toList(),
      arenaRadius: _arenaRadius,
      seed: 1,
      layoutRotation: 0,
      mode: MatchMode.allOut,
      lookAhead: false,
    );
    final ballA = _ball(c, 'a');
    // Ball A owns the half facing angle 0, centered on slot 0.
    final near = const Offset(_arenaRadius, 0);
    final freed = c.cutThreads(ballA, 5, near: near);
    expect(freed, 5);
    expect(ballA.fanLines.length, kRimSlotCount ~/ 2 - 5);
    expect(c.freeSlotCount, 5);
    final remaining = ballA.fanLines.map((l) => l.slotIndex).toSet();
    for (final slot in const [0, 1, kRimSlotCount - 1, 2, kRimSlotCount - 2]) {
      expect(
        remaining,
        isNot(contains(slot)),
        reason: 'slot $slot is among the nearest',
      );
    }
  });

  test('cutThreads frees at most what the ball owns, then it is out', () {
    final c = MatchSimulationController(
      _balls.take(2).toList(),
      arenaRadius: _arenaRadius,
      seed: 1,
      layoutRotation: 0,
      mode: MatchMode.allOut,
      lookAhead: false,
    );
    final ballA = _ball(c, 'a');
    final ballB = _ball(c, 'b');
    expect(c.cutThreads(ballB, 1000), kRimSlotCount ~/ 2);
    expect(ballB.fanLines, isEmpty);
    expect(c.freeSlotCount, kRimSlotCount ~/ 2);
    c.tick(1 / 60);
    expect(ballB.isEliminated, isTrue);
    expect(c.state.winnerId, ballA.config.id);
  });

  /// Plays a match to the end (10 minutes of game time at most) and returns the steps it took, plus the
  /// steps on which it was in slow motion.
  (int, List<int>) playOut(MatchSimulationController c) {
    final slow = <int>[];
    while (c.state.status != MatchStatus.finished &&
        c.stepCount < 60 * 60 * 10) {
      // One step per tick, also once playback speeds up after a minute.
      c.tick(
        MatchSimulationController.fixedTimestep / c.playbackSpeedUp * 1.0000001,
      );
      if (c.state.status == MatchStatus.slowMotion) slow.add(c.stepCount);
    }
    return (c.stepCount, slow);
  }

  test('the look-ahead predicts the real finish in Arsenal and All-Out', () {
    for (final mode in [MatchMode.arsenal, MatchMode.allOut]) {
      for (var seed = 1; seed <= 10; seed++) {
        final c = MatchSimulationController(
          _balls.take(2).toList(),
          arenaRadius: _arenaRadius,
          seed: seed,
          mode: mode,
        );
        final predicted = c.predictedFinishStep;
        final (steps, _) = playOut(c);
        expect(
          c.state.status,
          MatchStatus.finished,
          reason: '$mode seed $seed did not finish',
        );
        expect(predicted, steps, reason: '$mode seed $seed');
      }
    }
  });

  test('Arsenal slow motion uses seconds before the win', () {
    for (var seed = 1; seed <= 5; seed++) {
      // Lines setting (admin default) with no seconds: Arsenal falls back to 1.5 s before the win.
      final c = MatchSimulationController(
        _balls.take(2).toList(),
        arenaRadius: _arenaRadius,
        seed: seed,
        mode: MatchMode.arsenal,
      );
      final finish = c.predictedFinishStep!;
      final (_, slow) = playOut(c);
      expect(slow.first, finish - 90, reason: 'seed $seed');

      // Slow motion off (no lines, no seconds): never slows.
      final off = MatchSimulationController(
        _balls.take(2).toList(),
        arenaRadius: _arenaRadius,
        seed: seed,
        mode: MatchMode.arsenal,
        slowMotionLines: 0,
      );
      expect(playOut(off).$2, isEmpty, reason: 'seed $seed');
    }
  });

  test(
    'crowded Arsenal matches hit harder: damage scales with the number of balls',
    () {
      final four = [
        ..._balls.take(2),
        const CustomBall(
          id: 'c',
          name: 'C',
          primaryColor: Colors.green,
          glowColor: Colors.lime,
        ),
        const CustomBall(
          id: 'd',
          name: 'D',
          primaryColor: Colors.orange,
          glowColor: Colors.amber,
        ),
      ];
      final two = MatchSimulationController(
        _balls.take(2).toList(),
        arenaRadius: _arenaRadius,
        seed: 3,
        mode: MatchMode.arsenal,
        lookAhead: false,
      );
      final crowd = MatchSimulationController(
        four,
        arenaRadius: _arenaRadius,
        seed: 3,
        mode: MatchMode.arsenal,
        lookAhead: false,
      );
      two.damage(two.state.balls[0], 10);
      crowd.damage(crowd.state.balls[0], 10);
      expect(PowerUpTuning.arenaLife - two.state.balls[0].life, 10);
      expect(PowerUpTuning.arenaLife - crowd.state.balls[0].life, 40);
    },
  );
}
