import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _arenaRadius = 260.0;

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
];

/// Two still balls: Arsenal at (-100, 0) and (100, 0); All-Out ball 0 at (100, 0), ball 1 at (-100, 0).
MatchSimulationController _match({MatchMode mode = MatchMode.arsenal}) {
  final c = MatchSimulationController(_balls,
      arenaRadius: _arenaRadius, seed: 1, layoutRotation: 0, mode: mode, lookAhead: false);
  final side = mode == MatchMode.arsenal ? -1.0 : 1.0;
  final [a, b] = c.state.balls;
  a
    ..velocity = Offset.zero
    ..position = Offset(100 * side, 0);
  b
    ..velocity = Offset.zero
    ..position = Offset(-100 * side, 0);
  return c;
}

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.tick(1 / 60);
  }
}

Iterable<String> _texts(MatchSimulationController c) => c.state.floatingTexts.items.map((t) => t.text);

void _give(MatchSimulationController c, SimulationBall ball, PowerUpKind kind) {
  c.powerUps!.field.add(FieldPowerUp(kind: kind, position: ball.position, spawnStep: 0));
  _run(c, 1);
}

void _settle(MatchSimulationController c) {
  for (var i = 0; i < 60 && c.powerUps!.projectiles.isNotEmpty; i++) {
    _run(c, 1);
  }
}

void main() {
  test('playback speeds up for each full minute of game time, up to the max', () {
    final c = MatchSimulationController(_balls, arenaRadius: _arenaRadius, seed: 4, lookAhead: false);
    expect(c.playbackSpeedUp, 1);
    // Hold the balls still so the match runs past the minute.
    for (var i = 0; i < 3600; i++) {
      for (final b in c.state.balls) {
        b.velocity = Offset.zero;
      }
      c.tick(MatchSimulationController.fixedTimestep);
      if (c.stepCount == 3599) expect(c.playbackSpeedUp, 1);
    }
    expect(c.stepCount, 3600);
    expect(c.playbackSpeedUp, 1 + MatchSimulationController.speedUpPerMinute);
    // One real frame now runs more steps.
    final before = c.stepCount;
    for (var i = 0; i < 40; i++) {
      c.tick(MatchSimulationController.fixedTimestep);
    }
    expect(c.stepCount - before, inInclusiveRange(49, 50));
  });

  test('playback speed never changes the match: any frame rate plays the same steps', () {
    MatchSimulationController play(double frame) {
      final c = MatchSimulationController(_balls, arenaRadius: _arenaRadius, seed: 11, lookAhead: false);
      while (c.state.status != MatchStatus.finished && c.stepCount < 60 * 60 * 6) {
        c.tick(frame);
      }
      return c;
    }

    final a = play(1 / 60);
    final b = play(1 / 30);
    expect(b.stepCount, a.stepCount);
    expect(b.state.winnerId, a.state.winnerId);
  });

  test('hits show the damage taken; a volley adds up in one label', () {
    final c = _match();
    final [a, b] = c.state.balls;
    b.held = PowerUpKind.pistol;
    _run(c, PowerUpTuning.aimSteps);
    expect(_texts(c), contains('BANG!'));
    _settle(c);
    expect(_texts(c), contains('-${PowerUpTuning.arenaDamage[PowerUpKind.pistol]!.round()}'));
    expect(a.life, PowerUpTuning.arenaLife - PowerUpTuning.arenaDamage[PowerUpKind.pistol]!);

    // A shotgun blast at close range: one label for all the pellets that hit.
    final d = _match();
    final [x, y] = d.state.balls;
    x.position = const Offset(-60, 0);
    y
      ..held = PowerUpKind.shotgun
      ..position = const Offset(10, 0);
    _run(d, PowerUpTuning.aimSteps);
    _settle(d);
    final lost = PowerUpTuning.arenaLife - x.life;
    expect(lost, greaterThan(PowerUpTuning.arenaDamage[PowerUpKind.shotgun]!));
    expect(_texts(d).where((t) => t.startsWith('-')).toList(), ['-${lost.round()}']);
  });

  test('All-Out hits show the lines lost', () {
    final c = _match(mode: MatchMode.allOut);
    final [a, b] = c.state.balls;
    final before = b.fanLines.length;
    a.held = PowerUpKind.pistol;
    _run(c, PowerUpTuning.aimSteps);
    _settle(c);
    expect(b.fanLines.length, lessThan(before));
    expect(_texts(c).where((t) => t.startsWith('-') && t.endsWith('LINES')), isNotEmpty);
  });

  test('balls yell what they do', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a
      ..held = PowerUpKind.shield
      ..position = Offset(b.position.dx - a.radius - b.radius - 2, 0)
      ..velocity = const Offset(120, 0);
    for (var i = 0; i < 30 && a.held != null; i++) {
      _run(c, 1);
    }
    expect(_texts(c), contains('SHIELD BASH!'));

    final d = _match();
    final x = d.state.balls.first;
    _give(d, x, PowerUpKind.apple);
    _give(d, x, PowerUpKind.speed);
    _give(d, x, PowerUpKind.ghost);
    expect(_texts(d), containsAll(['YUM!', 'ZOOM!', 'BOO!']));
  });

  test('picking up anything else cancels a waiting magnet', () {
    final c = _match();
    final a = c.state.balls.first;
    _give(c, a, PowerUpKind.magnet);
    expect(a.magnetPending, isTrue);
    _give(c, a, PowerUpKind.speed);
    expect(a.magnetPending, isFalse);
  });

  test('a frozen ball that gets knocked leaves the way it was knocked, at its old speed', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.velocity = const Offset(0, 90);
    c.powerUps!.projectiles.add(Projectile(
      owner: b,
      kind: PowerUpKind.freeze,
      position: a.position + Offset(a.radius + 5, 0),
      velocity: const Offset(-_arenaRadius * PowerUpTuning.bulletSpeedRatio, 0),
    ));
    _run(c, 1);
    expect(a.frozenLeft, greaterThan(0));
    // A knock while frozen (what a bump leaves behind).
    a.velocity = const Offset(-30, 0);
    _run(c, 1);
    expect(a.velocity, Offset.zero);
    _run(c, a.frozenLeft);
    expect(a.frozenLeft, 0);
    expect(a.velocity.dx, closeTo(-90, 1e-6));
    expect(a.velocity.dy, closeTo(0, 1e-6));
  });

  test('gatling rounds are counted for their own sound', () {
    final c = _match();
    final b = c.state.balls[1];
    b.held = PowerUpKind.gatling;
    _run(c, PowerUpTuning.aimSteps + PowerUpTuning.gatlingIntervalSteps * (PowerUpTuning.gatlingRounds - 1));
    expect(c.powerUps!.gatlingShots, PowerUpTuning.gatlingRounds);
    expect(c.powerUps!.shots, PowerUpTuning.gatlingRounds);
    expect(_texts(c), contains('RATATAT!'));
  });

  test('a grenade is aimed, thrown at where the target was, and blows up there, sparing the thrower', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.grenade;
    _run(c, PowerUpTuning.aimSteps);
    expect(a.held, isNull);
    final grenade = c.powerUps!.projectiles.single;
    expect(grenade.kind, PowerUpKind.grenade);
    expect(grenade.landAt, b.position);
    expect(_texts(c), contains('FIRE IN THE HOLE!'));
    for (var i = 0; i < 120 && c.powerUps!.blasts == 0; i++) {
      _run(c, 1);
    }
    expect(c.powerUps!.blasts, 1);
    expect(c.powerUps!.projectiles, isEmpty);
    expect(b.life, PowerUpTuning.arenaLife - PowerUpTuning.arenaDamage[PowerUpKind.grenade]!);
    expect(a.life, PowerUpTuning.arenaLife);
  });

  test('a grenade lands where the target was even if it moved away, and hits only who is near', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.grenade;
    _run(c, PowerUpTuning.aimSteps);
    final landAt = c.powerUps!.projectiles.single.landAt!;
    b.position = const Offset(0, 200); // Ran off, far from the landing spot.
    for (var i = 0; i < 120 && c.powerUps!.blasts == 0; i++) {
      _run(c, 1);
    }
    expect(c.powerUps!.explosions.single.position, landAt);
    expect(b.life, PowerUpTuning.arenaLife);
  });

  test('a sword strikes like a knife at double the damage and is used up', () {
    expect(PowerUpTuning.arenaDamage[PowerUpKind.sword], 2 * PowerUpTuning.arenaDamage[PowerUpKind.knife]!);
    expect(PowerUpTuning.allOutThreads[PowerUpKind.sword], 2 * PowerUpTuning.allOutThreads[PowerUpKind.knife]!);
    final c = _match();
    final [a, b] = c.state.balls;
    a
      ..held = PowerUpKind.sword
      ..position = Offset(b.position.dx - a.radius - b.radius - 2, 0)
      ..velocity = const Offset(120, 0);
    for (var i = 0; i < 30 && a.held != null; i++) {
      _run(c, 1);
    }
    expect(a.held, isNull);
    expect(b.life, PowerUpTuning.arenaLife - PowerUpTuning.arenaDamage[PowerUpKind.sword]!);
    expect(_texts(c), contains('HIYAA!'));
    expect(c.powerUps!.slashMarks, isNotEmpty);
  });
}
