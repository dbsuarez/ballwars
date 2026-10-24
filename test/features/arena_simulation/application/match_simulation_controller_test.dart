import 'dart:math' as math;
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

List<CustomBall> _twoBalls() => const [
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
];

SimulationBall _ball(MatchSimulationController c, String id) =>
    c.state.balls.firstWhere((b) => b.config.id == id);

Set<int> _slots(SimulationBall ball) =>
    ball.fanLines.map((l) => l.slotIndex).toSet();

void _freeze(MatchSimulationController c) {
  for (final ball in c.state.balls) {
    ball.velocity = Offset.zero;
  }
}

/// Puts [ball] just inside the wall at [degrees], moving straight out.
void _aimAtWall(SimulationBall ball, double degrees) {
  final dir = Offset(
    math.cos(degrees * math.pi / 180),
    math.sin(degrees * math.pi / 180),
  );
  ball.position = dir * (_arenaRadius - ball.radius - 1);
  ball.velocity = dir * 300;
}

void main() {
  test('the final weapon is recorded as the winning move', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      seed: 1,
      layoutRotation: 0,
      mode: MatchMode.arsenal,
      lookAhead: false,
    );
    final a = _ball(controller, 'a');
    final b = _ball(controller, 'b');
    controller.damage(b, 100, attacker: a, move: PowerUpKind.pistol.label);
    controller.tick(1 / 60);
    expect(controller.state.winnerId, 'a');
    expect(controller.winningMove, 'Pistol');
  });

  test('Endless Battle respawns a destroyed ball and credits the attacker', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      seed: 1,
      layoutRotation: 0,
      mode: MatchMode.arsenal,
      endlessBattle: true,
      lookAhead: false,
    );
    final a = _ball(controller, 'a');
    final b = _ball(controller, 'b')
      ..held = PowerUpKind.pistol
      ..heldSecondary = PowerUpKind.sword
      ..speedLeft = 30
      ..goldenArmorHits = 2
      ..magnetPending = true;

    controller.damage(b, 100, attacker: a);
    controller.damage(b, 100, attacker: a);
    controller.damage(b, 100, attacker: a);
    controller.tick(1 / 60);

    expect(b.isEliminated, isFalse);
    expect(b.life, 100);
    expect(b.equippedWeapons, isEmpty);
    expect(b.speedLeft, 0);
    expect(b.goldenArmorHits, 0);
    expect(b.magnetPending, isFalse);
    expect(b.ghostLeft, controller.tuning.ghostSteps ~/ 2);
    expect(b.isGhost, isTrue);
    expect(controller.eliminations, {'a': 1});
    expect(controller.state.status, MatchStatus.running);
    expect(controller.state.winnerId, isNull);
  });

  test('two balls start owning one half of the rim each', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 1,
    );
    final a = _ball(controller, 'a');
    final b = _ball(controller, 'b');

    expect(a.lineCount, kRimSlotCount ~/ 2);
    expect(b.lineCount, kRimSlotCount ~/ 2);
    expect(_slots(a).intersection(_slots(b)), isEmpty);
    expect(_slots(a).union(_slots(b)).length, kRimSlotCount);
    // Ball A starts at angle 0, so it owns the slot facing it, B the opposite one.
    expect(_slots(a), contains(0));
    expect(_slots(b), contains(kRimSlotCount ~/ 2));
    expect(controller.state.allActiveFanLines.length, kRimSlotCount);
    expect(controller.state.status, MatchStatus.running);
  });

  test(
    'same seed and contestants produce identical state after N ticks (determinism)',
    () {
      final controllerA = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: 99,
      );
      final controllerB = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: 99,
      );

      for (var i = 0; i < 600; i++) {
        controllerA.tick(1 / 60);
        controllerB.tick(1 / 60);
      }

      final stateA = controllerA.state;
      final stateB = controllerB.state;
      for (var i = 0; i < stateA.balls.length; i++) {
        expect(stateA.balls[i].position, equals(stateB.balls[i].position));
        expect(stateA.balls[i].velocity, equals(stateB.balls[i].velocity));
        expect(
          stateA.balls[i].isEliminated,
          equals(stateB.balls[i].isEliminated),
        );
        expect(_slots(stateA.balls[i]), equals(_slots(stateB.balls[i])));
      }
    },
  );

  test(
    'tick accumulates partial real time into fixed steps without drifting immediately',
    () {
      final controller = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: 5,
      );
      final before = controller.state.balls.first.position;
      // Less than one fixed timestep (1/60 ~= 0.01667) should not advance physics yet.
      controller.tick(0.005);
      expect(controller.state.balls.first.position, before);
    },
  );

  test('accumulator cap prevents spiral of death', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 5,
    );
    controller.tick(0.5);
    for (final ball in controller.state.balls) {
      expect(ball.position.distance, lessThanOrEqualTo(_arenaRadius));
    }
  });

  test('lines stay anchored to their rim slot and follow the owner', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 1,
    );
    final a = _ball(controller, 'a');
    final anchors = {for (final l in a.fanLines) l.slotIndex: l.startPoint};

    for (var i = 0; i < 30; i++) {
      controller.tick(1 / 60);
    }

    for (final line in a.fanLines) {
      if (anchors.containsKey(line.slotIndex)) {
        expect(line.startPoint, anchors[line.slotIndex]);
      }
      expect(line.endPoint, a.position);
    }
  });

  test('an opponent body overlapping a line cuts it and frees the slot', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 1,
    );
    _freeze(controller);
    final a = _ball(controller, 'a');
    final b = _ball(controller, 'b');

    // A at the center; B sits on A's line to slot 0 (anchor at angle 0).
    a.position = Offset.zero;
    b.position = const Offset(150, 0);
    controller.tick(1 / 60);

    expect(_slots(a), isNot(contains(0)));
    // Lines far from B (slot 30, anchor at 60 degrees) survive.
    expect(_slots(a), contains(30));
    // B's line to the opposite rim (angle 180) passes through A, so it is cut too.
    expect(_slots(b), isNot(contains(kRimSlotCount ~/ 2)));
    // Cut lines are gone and nobody owns those slots now.
    expect(_slots(a).union(_slots(b)), isNot(contains(0)));
    expect(a.fanLines.every((l) => l.isActive), isTrue);
  });

  test(
    'wall hit claims the free run between the contact point and the ball\'s own lines',
    () {
      final controller = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: 1,
      );
      _freeze(controller);
      final a = _ball(controller, 'a');
      final b = _ball(controller, 'b');
      b.position = const Offset(-100, 0);

      // Free A's slots 0..20 (angles 0..40 degrees).
      for (final line in a.fanLines) {
        if (line.slotIndex <= 20) line.isActive = false;
      }
      controller.tick(1 / 60);
      expect(
        _slots(a).intersection({for (var s = 0; s <= 20; s++) s}),
        isEmpty,
      );
      final before = a.lineCount;

      // A hits the wall at 20 degrees (slot 10), inside its own free gap.
      _aimAtWall(a, 20);
      controller.tick(1 / 60);

      expect(a.lineCount, before + 21);
      expect(_slots(a), containsAll([for (var s = 0; s <= 20; s++) s]));
      expect(
        controller.state.floatingTexts.items.any((t) => t.text == '+21 LINES'),
        isTrue,
      );
    },
  );

  test(
    'wall hit claims nothing when the free run is bounded by opponent lines',
    () {
      final controller = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: 1,
      );
      _freeze(controller);
      final a = _ball(controller, 'a');
      final b = _ball(controller, 'b');
      a.position = Offset.zero;

      for (final line in a.fanLines) {
        if (line.slotIndex <= 20) line.isActive = false;
      }
      controller.tick(1 / 60);
      final before = b.lineCount;

      // B hits the wall inside A's gap: both ends of the gap belong to A.
      _aimAtWall(b, 20);
      controller.tick(1 / 60);

      expect(b.lineCount, lessThanOrEqualTo(before));
      expect(
        _slots(
          a,
        ).union(_slots(b)).intersection({for (var s = 0; s <= 20; s++) s}),
        isEmpty,
      );
      expect(
        controller.state.floatingTexts.items.any(
          (t) => t.text.contains('LINES'),
        ),
        isFalse,
      );
    },
  );

  test('wall hit at an owned slot claims nothing', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 1,
    );
    _freeze(controller);
    final a = _ball(controller, 'a');
    _ball(controller, 'b').position = const Offset(-100, 0);
    final before = a.lineCount;

    _aimAtWall(a, 20);
    controller.tick(1 / 60);

    expect(a.lineCount, before);
  });

  test('ball with every line cut is eliminated and the other ball wins', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 1,
    );
    final a = _ball(controller, 'a');
    for (final line in a.fanLines) {
      line.isActive = false;
    }

    controller.tick(1 / 60);

    expect(a.isEliminated, isTrue);
    expect(
      controller.state.floatingTexts.items.any((t) => t.text == 'ELIMINATED'),
      isTrue,
    );
    expect(controller.state.winnerId, 'b');
    expect(controller.state.status, MatchStatus.finished);
  });

  test('a lone ball owns the whole rim and keeps running', () {
    final controller = MatchSimulationController(
      const [
        CustomBall(
          id: 'a',
          name: 'A',
          primaryColor: Colors.red,
          glowColor: Colors.pink,
        ),
      ],
      arenaRadius: _arenaRadius,
      seed: 1,
    );

    for (var i = 0; i < 100; i++) {
      controller.tick(1 / 60);
    }

    expect(controller.state.balls.first.lineCount, kRimSlotCount);
    expect(controller.state.status, MatchStatus.running);
  });

  test('ball at center (d==0) does not produce NaN on wall collision', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 42,
    );
    controller.state.balls.first.position = Offset.zero;
    controller.state.balls.first.velocity = const Offset(100, 0);
    controller.tick(1 / 60);
    final pos = controller.state.balls.first.position;
    expect(pos.dx.isFinite, isTrue);
    expect(pos.dy.isFinite, isTrue);
  });

  test('collisions are elastic: total kinetic energy is conserved', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 3,
    );
    double energy() => controller.state.balls.fold(
      0.0,
      (sum, b) => sum + b.velocity.distanceSquared,
    );
    final start = energy();

    for (
      var i = 0;
      i < 60 * 5 && controller.state.status != MatchStatus.finished;
      i++
    ) {
      controller.tick(1 / 60);
    }

    expect(energy(), closeTo(start, start * 1e-9));
  });

  test(
    'a head-on hit hands only part of the moving ball\'s speed to the resting one',
    () {
      final controller = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: 1,
      );
      final a = _ball(controller, 'a');
      final b = _ball(controller, 'b');
      a.position = const Offset(-60, 0);
      a.velocity = const Offset(300, 0);
      b.position = Offset(-60 + 2 * a.radius + 1, 0);
      b.velocity = Offset.zero;

      controller.tick(1 / 60);

      // A keeps most of its speed and bounces back; B is pushed away gently.
      expect(a.velocity.dx, lessThan(0));
      expect(b.velocity.dx, greaterThan(0));
      expect(a.velocity.distance, greaterThan(b.velocity.distance * 2));
      expect(
        a.velocity.distanceSquared + b.velocity.distanceSquared,
        closeTo(300 * 300, 1e-6),
      );
    },
  );

  test('launch directions have no built-in clockwise bias', () {
    final senses = <bool>{};
    for (var seed = 1; seed <= 20; seed++) {
      final controller = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: seed,
      );
      for (final ball in controller.state.balls) {
        final p = ball.position;
        final v = ball.velocity;
        senses.add(p.dx * v.dy - p.dy * v.dx > 0); // true = clockwise on screen
      }
    }
    expect(senses, {true, false});
  });

  test(
    'without a look-ahead, slow motion starts at 10 lines or fewer and ends if the ball recovers',
    () {
      // Lines are cut by hand below, which no look-ahead could foresee.
      final controller = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: 1,
        lookAhead: false,
      );
      _freeze(controller);
      final a = _ball(controller, 'a');
      _ball(controller, 'b').position = const Offset(-100, 0);

      // Leave A with 5 lines (slots 21..25).
      for (final line in a.fanLines) {
        if (line.slotIndex < 21 || line.slotIndex > 25) line.isActive = false;
      }
      controller.tick(1 / 60);
      expect(a.lineCount, 5);
      expect(controller.state.status, MatchStatus.slowMotion);

      // A hits the wall at slot 10 and reclaims slots 10..20 back to its own.
      _aimAtWall(a, 20);
      for (var i = 0; i < 8 && a.lineCount == 5; i++) {
        controller.tick(1 / 60);
      }
      expect(a.lineCount, greaterThan(10));
      expect(controller.state.status, MatchStatus.running);
    },
  );

  test(
    'if the last two lose their final lines in the same step, one still wins',
    () {
      final controller = MatchSimulationController(
        _twoBalls(),
        arenaRadius: _arenaRadius,
        layoutRotation: 0,
        seed: 1,
      );
      for (final ball in controller.state.balls) {
        for (final line in ball.fanLines) {
          line.isActive = false;
        }
      }

      controller.tick(1 / 60);

      expect(controller.state.status, MatchStatus.finished);
      expect(controller.state.winnerId, isNotNull);
      expect(controller.state.balls.where((b) => !b.isEliminated).length, 1);
    },
  );

  test('a full match ends with a winner', () {
    final controller = MatchSimulationController(
      _twoBalls(),
      arenaRadius: _arenaRadius,
      layoutRotation: 0,
      seed: 7,
    );
    for (
      var i = 0;
      i < 60 * 600 && controller.state.status != MatchStatus.finished;
      i++
    ) {
      controller.tick(1 / 60);
    }
    expect(controller.state.status, MatchStatus.finished);
    expect(controller.state.winnerId, isNotNull);
  });

  test(
    'the slow-motion threshold changes only playback, never the outcome',
    () {
      (String?, int, bool) play(int lines) {
        final c = MatchSimulationController(
          _twoBalls(),
          arenaRadius: 300,
          seed: 42,
          slowMotionLines: lines,
        );
        var slowed = false;
        for (
          var i = 0;
          i < 60 * 60 * 10 && c.state.status != MatchStatus.finished;
          i++
        ) {
          c.tick(1 / 60);
          slowed |= c.state.status == MatchStatus.slowMotion;
        }
        return (c.state.winnerId, c.wallHits, slowed);
      }

      final standard = play(MatchSimulationController.slowMotionLineThreshold);
      final never = play(0);
      final early = play(40);
      expect(never.$3, isFalse);
      expect(early.$3, isTrue);
      expect(never.$1, standard.$1);
      expect(early.$1, standard.$1);
      expect(never.$2, standard.$2);
      expect(early.$2, standard.$2);
    },
  );

  test(
    'before-the-win slow motion starts the set time before the predicted winning cut',
    () {
      for (final seed in [3, 11, 42]) {
        final c = MatchSimulationController(
          _twoBalls(),
          arenaRadius: 300,
          seed: seed,
          slowMotionBeforeWinSeconds: 1.5,
        );
        final finish = c.predictedFinishStep!;
        int? slowFrom;
        var steps = 0;
        while (c.state.status != MatchStatus.finished) {
          c.tick(MatchSimulationController.fixedTimestep);
          steps++;
          if (c.state.status == MatchStatus.slowMotion) slowFrom ??= steps;
          if (slowFrom != null && c.state.status != MatchStatus.finished) {
            expect(
              c.state.status,
              MatchStatus.slowMotion,
              reason: 'no return to normal speed',
            );
          }
        }
        // Slow motion stretches real time 4x, but steps are steps.
        expect(c.state.winnerId, isNotNull);
        expect(slowFrom, finish - 90);
      }
    },
  );

  test('by-lines slow motion never starts for a ball that recovers', () {
    for (var seed = 1; seed <= 30; seed++) {
      final c = MatchSimulationController(
        _threeBalls(),
        arenaRadius: 300,
        seed: seed,
        slowMotionLines: 30,
      );
      var slowed = false;
      for (
        var i = 0;
        i < 60 * 60 * 10 && c.state.status != MatchStatus.finished;
        i++
      ) {
        c.tick(1 / 60);
        if (c.state.status == MatchStatus.slowMotion) slowed = true;
        if (slowed && c.state.status != MatchStatus.finished) {
          expect(
            c.state.status,
            MatchStatus.slowMotion,
            reason: 'seed $seed went back to normal speed',
          );
        }
      }
    }
  });

  test('ball size scales every ball and is deterministic', () {
    final big = MatchSimulationController(
      _twoBalls(),
      arenaRadius: 300,
      seed: 9,
      ballScale: 1.25,
    );
    final normal = MatchSimulationController(
      _twoBalls(),
      arenaRadius: 300,
      seed: 9,
    );
    expect(
      big.state.balls.first.radius,
      closeTo(normal.state.balls.first.radius * 1.25, 1e-9),
    );

    String? winner(double scale) {
      final c = MatchSimulationController(
        _twoBalls(),
        arenaRadius: 300,
        seed: 9,
        ballScale: scale,
      );
      for (
        var i = 0;
        i < 60 * 600 && c.state.status != MatchStatus.finished;
        i++
      ) {
        c.tick(1 / 60);
      }
      return '${c.state.winnerId}/${c.wallHits}';
    }

    expect(winner(0.6), winner(0.6));
    expect(winner(1.25), winner(1.25));
  });

  test(
    'shrinking arena contracts after its grace period and contains balls',
    () {
      final c = MatchSimulationController(
        _twoBalls(),
        arenaRadius: 300,
        seed: 9,
        shrinkingArena: true,
        lookAhead: false,
        mode: MatchMode.arsenal,
        endlessBattle: true,
      );
      for (
        var i = 0;
        i < MatchSimulationController.shrinkGraceSteps + 600;
        i++
      ) {
        c.tick(1 / 60);
      }
      expect(c.arenaRadius, lessThan(300));
      for (final ball in c.state.balls.where((ball) => !ball.isEliminated)) {
        expect(
          ball.position.distance + ball.radius,
          lessThanOrEqualTo(c.arenaRadius + 0.001),
        );
      }
    },
  );
}

List<CustomBall> _threeBalls() => const [
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
