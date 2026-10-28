import 'dart:math' as math;

import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/application/power_up_system.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
];

const _tuning = PowerUpConfig.defaults;

SkillLibrary _with(
  List<SkillDefinition Function(SkillDefinition)> edits,
  List<PowerUpKind> kinds,
) {
  var library = SkillLibrary.defaults;
  for (final (i, kind) in kinds.indexed) {
    library = library.withDefinition(
      edits[i](SkillLibrary.defaults.builtIn(kind, _tuning)),
      _tuning,
    );
  }
  return library;
}

/// Two balls held still at (-100, 0) and (100, 0), nothing spawning.
MatchSimulationController _match({SkillLibrary? library}) {
  final c = MatchSimulationController(
    _balls,
    arenaRadius: 260,
    seed: 1,
    layoutRotation: 0,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: library ?? SkillLibrary.defaults,
  );
  final [a, b] = c.state.balls;
  a
    ..velocity = Offset.zero
    ..position = const Offset(-100, 0);
  b
    ..velocity = Offset.zero
    ..position = const Offset(100, 0);
  return c;
}

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.tick(1 / 60);
  }
}

/// Gives ball A [kind] and runs one aim, so it fires once.
List<ShellCasing> _fireOnce(PowerUpKind kind, {SkillLibrary? library}) {
  final c = _match(library: library);
  c.state.balls.first.held = kind;
  _run(c, PowerUpTuning.aimSteps);
  expect(
    c.powerUps!.shots + c.powerUps!.sniperFlashes.length,
    greaterThan(0),
    reason: kind.name,
  );
  return c.powerUps!.shellCasings;
}

void main() {
  test('the four default guns eject, another gun only when switched on', () {
    for (final kind in const [
      PowerUpKind.pistol,
      PowerUpKind.gatling,
      PowerUpKind.freeze,
    ]) {
      expect(_fireOnce(kind), hasLength(1), reason: kind.name);
      final off = _with([(s) => s.copyWith(shellEnabled: false)], [kind]);
      expect(_fireOnce(kind, library: off), isEmpty, reason: kind.name);
    }
    expect(_fireOnce(PowerUpKind.waterGun), isEmpty);
    final on = _with(
      [(s) => s.copyWith(shellEnabled: true)],
      [PowerUpKind.waterGun],
    );
    expect(_fireOnce(PowerUpKind.waterGun, library: on), hasLength(1));
    // Guns that don't fire plain shots also drop one when switched on.
    for (final kind in const [
      PowerUpKind.rocketLauncher,
      PowerUpKind.sniperRifle,
      PowerUpKind.grenade,
    ]) {
      expect(_fireOnce(kind), isEmpty, reason: kind.name);
      final enabled = _with([(s) => s.copyWith(shellEnabled: true)], [kind]);
      expect(
        _fireOnce(kind, library: enabled),
        hasLength(1),
        reason: kind.name,
      );
    }
  });

  test('a pistol casing starts exactly where and how it always did', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.pistol;
    _run(c, PowerUpTuning.aimSteps - 1);
    final from = a.position;
    final radius = a.radius;
    // Casings move before guns fire in a step, so a new one is exactly as ejected.
    _run(c, 1);
    final casing = c.powerUps!.shellCasings.single;
    final shot = b.position - from;
    final dir = shot / shot.distance;
    final side = Offset(-dir.dy, dir.dx);
    final velocity = side * radius * 1.8 - Offset(0, radius * 1.4);
    final position = from + side * radius * 0.55;
    expect(casing.velocity.dx, closeTo(velocity.dx, 1e-9));
    expect(casing.velocity.dy, closeTo(velocity.dy, 1e-9));
    expect(casing.position.dx, closeTo(position.dx, 1e-9));
    expect(casing.position.dy, closeTo(position.dy, 1e-9));
    expect(casing.angle, closeTo(math.atan2(side.dy, side.dx), 1e-9));
  });

  test('a shotgun or bow volley drops one casing, none when Off', () {
    for (final kind in const [PowerUpKind.shotgun, PowerUpKind.bow]) {
      final defaults = kind == PowerUpKind.shotgun ? 1 : 0;
      expect(_fireOnce(kind), hasLength(defaults), reason: kind.name);
      final on = _with([(s) => s.copyWith(shellEnabled: true)], [kind]);
      expect(_fireOnce(kind, library: on), hasLength(1), reason: kind.name);
      final off = _with([(s) => s.copyWith(shellEnabled: false)], [kind]);
      expect(_fireOnce(kind, library: off), isEmpty, reason: kind.name);
    }
  });

  test('a gatling burst still drops one casing per round', () {
    final c = _match();
    c.state.balls.first.held = PowerUpKind.gatling;
    _run(c, PowerUpTuning.aimSteps);
    _run(
      c,
      PowerUpTuning.gatlingIntervalSteps * (PowerUpTuning.gatlingRounds + 2),
    );
    expect(c.powerUps!.gatlingShots, PowerUpTuning.gatlingRounds);
    expect(c.powerUps!.shellCasings, hasLength(PowerUpTuning.gatlingRounds));
  });

  test('a capped composed volley that fires nothing drops no casing', () {
    var library = SkillLibrary.defaults;
    final spray = library
        .create('Spray', PowerUpKind.pistol)
        .copyWith(
          enabled: true,
          shellEnabled: true,
          projectileCount: 100,
          spreadDegrees: 360,
          projectileSpeed: 0.1,
        );
    library = library.withDefinition(spray, _tuning);
    final c = _match(library: library);
    final a = c.state.balls.first;
    void aimAndFire() {
      a
        ..held = PowerUpKind.pistol
        ..heldSkillId = spray.id;
      _run(c, PowerUpTuning.aimSteps);
    }

    aimAndFire();
    expect(c.powerUps!.shots, PowerUpSystem.maxComposedProjectiles);
    expect(c.powerUps!.shellCasings, hasLength(1));
    _run(c, PowerUpSystem.firedWeaponHoldSteps);
    aimAndFire();
    // Still capped: the slow shots are all in flight, so nothing fired and no casing dropped.
    expect(c.powerUps!.shots, PowerUpSystem.maxComposedProjectiles);
    expect(c.powerUps!.shellCasings, hasLength(1));
  });

  test(
    'a custom aimed projectile skill drops a shell only when switched on',
    () {
      var library = SkillLibrary.defaults;
      final pew = library
          .create('Pew', PowerUpKind.pistol)
          .copyWith(enabled: true);
      library = library.withDefinition(pew, _tuning);
      List<ShellCasing> fire(SkillLibrary lib) {
        final c = _match(library: lib);
        c.state.balls.first
          ..held = PowerUpKind.pistol
          ..heldSkillId = pew.id;
        _run(c, PowerUpTuning.aimSteps);
        expect(c.powerUps!.shots, greaterThan(0));
        return c.powerUps!.shellCasings;
      }

      expect(fire(library), isEmpty);
      final on = library.withDefinition(
        pew.copyWith(shellEnabled: true, shellSize: 2, shellSprite: 'custom.x'),
        _tuning,
      );
      final casing = fire(on).single;
      expect(casing.size, 2);
      expect(casing.spriteId, 'custom.x');
    },
  );

  test(
    'a casing carries the firing skill\'s sprite, size and rest settings',
    () {
      final library = _with(
        [
          (s) => s.copyWith(
            shellSprite: 'projectile.bullet',
            shellSize: 3,
            shellRandomRest: false,
          ),
        ],
        [PowerUpKind.pistol],
      );
      final casing = _fireOnce(PowerUpKind.pistol, library: library).single;
      expect(casing.spriteId, 'projectile.bullet');
      expect(casing.size, 3);
      expect(casing.randomRest, isFalse);

      final plain = _fireOnce(PowerUpKind.pistol).single;
      expect(plain.spriteId, isNull);
      expect(plain.size, 1);
      expect(plain.randomRest, isTrue);
    },
  );

  test('random rest: a pure hash of the casing number, not of the RNG', () {
    List<double> restAngles(SkillLibrary library) {
      final c = _match(library: library);
      final a = c.state.balls.first;
      final angles = <double>[];
      for (var shot = 0; shot < 4; shot++) {
        a.held = PowerUpKind.pistol;
        _run(c, PowerUpTuning.aimSteps + PowerUpSystem.firedWeaponHoldSteps);
      }
      _run(c, 240);
      for (final casing in c.powerUps!.shellCasings) {
        expect(casing.settled, isTrue);
        angles.add(casing.angle);
      }
      return angles;
    }

    final first = restAngles(SkillLibrary.defaults);
    expect(first, hasLength(4));
    expect(first.toSet(), hasLength(4));
    expect(restAngles(SkillLibrary.defaults), first);
    for (final (i, angle) in first.indexed) {
      expect(angle, PowerUpSystem.shellRestAngle(i));
    }
  });

  test('without random rest the casing keeps its spin angle at impact', () {
    final library = _with(
      [(s) => s.copyWith(shellRandomRest: false)],
      [PowerUpKind.pistol],
    );
    final c = _match(library: library);
    c.state.balls.first.held = PowerUpKind.pistol;
    _run(c, PowerUpTuning.aimSteps);
    final casing = c.powerUps!.shellCasings.single;
    var before = casing.angle;
    for (var i = 0; i < 400 && !casing.settled; i++) {
      before = casing.angle;
      _run(c, 1);
    }
    expect(casing.settled, isTrue);
    expect(casing.angle, before + 7.5 / 60);
  });

  test('shell settings never change the match or its RNG draws', () {
    ({String? winner, int steps, double nextDraw, int casings}) play(
      SkillLibrary library,
    ) {
      final c = MatchSimulationController(
        _balls,
        arenaRadius: 260,
        seed: 42,
        mode: MatchMode.arsenal,
        lookAhead: false,
        powerUpKinds: const {PowerUpKind.pistol, PowerUpKind.gatling},
        skillLibrary: library,
      );
      for (var i = 0; i < 60 * 240; i++) {
        c.tick(1 / 60);
        if (c.state.status == MatchStatus.finished) break;
      }
      return (
        winner: c.state.winnerId,
        steps: c.stepCount,
        nextDraw: c.powerUps!.rng.nextDouble(),
        casings: c.powerUps!.shellCasings.length,
      );
    }

    final plain = play(SkillLibrary.defaults);
    expect(plain.casings, greaterThan(0));
    final changed = play(
      _with(
        [
          (s) => s.copyWith(
            shellSprite: 'projectile.bullet',
            shellSize: 4,
            shellRandomRest: false,
          ),
          (s) => s.copyWith(shellEnabled: false),
        ],
        [PowerUpKind.pistol, PowerUpKind.gatling],
      ),
    );
    expect(changed.winner, plain.winner);
    expect(changed.steps, plain.steps);
    expect(changed.nextDraw, plain.nextDraw);
  });
}
