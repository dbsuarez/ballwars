import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

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

void main() {
  test('the defaults are exactly PowerUpTuning', () {
    const d = PowerUpConfig.defaults;
    expect(d.isDefault, isTrue);
    expect(d.firstSpawnSteps, PowerUpTuning.firstSpawnSteps);
    expect(d.trapStartSteps, PowerUpTuning.trapStartSteps);
    for (final n in [2, 3, 4]) {
      expect(d.spawnInterval(n), PowerUpTuning.spawnInterval(n));
    }
    expect(d.fieldRadiusRatio, PowerUpTuning.fieldRadiusRatio);
    expect(d.aimSteps, PowerUpTuning.aimSteps);
    expect(d.bulletSpeedRatio, PowerUpTuning.bulletSpeedRatio);
    expect(d.grenadeSpeedRatio, PowerUpTuning.grenadeSpeedRatio);
    expect(d.shotgunPellets, PowerUpTuning.shotgunPellets);
    expect(d.gatlingRounds, PowerUpTuning.gatlingRounds);
    for (final kind in PowerUpConfig.damageKinds) {
      expect(
        d.arenaDamage(kind),
        PowerUpTuning.arenaDamage[kind] ?? 0,
        reason: kind.name,
      );
      expect(
        d.allOutThreads(kind),
        PowerUpTuning.allOutThreads[kind] ?? 0,
        reason: kind.name,
      );
    }
    expect(d.arenaDamage(PowerUpKind.apple), 0);
    expect(d.arenaShieldBash, PowerUpTuning.arenaShieldBash);
    expect(d.unarmedCollisionDamage, PowerUpTuning.arenaCollisionDamage);
    expect(d.shieldBlock, closeTo(PowerUpTuning.shieldBlock, 1e-9));
    expect(d.arenaAppleHeal, PowerUpTuning.arenaAppleHeal);
    expect(d.arenaMaxLife, PowerUpTuning.arenaMaxLife);
    expect(d.allOutShieldBash, PowerUpTuning.allOutShieldBash);
    expect(d.allOutShieldKeep, closeTo(PowerUpTuning.allOutShieldKeep, 1e-9));
    expect(d.allOutAppleSlots, PowerUpTuning.allOutAppleSlots);
    expect(d.speedSteps, PowerUpTuning.speedSteps);
    expect(d.freezeSteps, PowerUpTuning.freezeSteps);
    expect(d.ghostSteps, PowerUpTuning.ghostSteps);
    expect(d.blastRadiusRatio, PowerUpTuning.blastRadiusRatio);
  });

  test(
    'values are clamped and rounded; setting a default drops the override',
    () {
      var c = PowerUpConfig.defaults.withValue('dmg.pistol', 999);
      expect(
        c.arenaDamage(PowerUpKind.pistol),
        PowerUpConfig.field('dmg.pistol')!.max,
      );
      c = c.withValue('pellets', 7.6);
      expect(c.shotgunPellets, 8);
      c = c.withValue('aim', 2);
      expect(c.aimSteps, 120);
      c = c.withValue('block', 50);
      expect(c.shieldBlock, 0.5);
      expect(c.overrides.length, 4);
      c = c.withValue(
        'dmg.pistol',
        PowerUpTuning.arenaDamage[PowerUpKind.pistol]!,
      );
      expect(c.overrides.containsKey('dmg.pistol'), isFalse);
      expect(c.withValue('nope', 3), c);
    },
  );

  test('saved settings load leniently; links decode strictly', () {
    final saved = PowerUpConfig.fromJson({
      'dmg.knife': 33,
      'pellets': 500,
      'unknown': 1,
      'aim': 'x',
    });
    expect(saved.arenaDamage(PowerUpKind.knife), 33);
    expect(saved.shotgunPellets, PowerUpConfig.field('pellets')!.max);
    expect(saved.overrides.length, 2);
    expect(PowerUpConfig.fromJson(null), PowerUpConfig.defaults);

    final c = PowerUpConfig.defaults
        .withValue('dmg.knife', 33)
        .withValue('ghost', 4.5);
    final encoded = c.encode()!;
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(encoded), isTrue);
    expect(PowerUpConfig.decode(encoded), c);
    expect(
      PowerUpConfig.decode(PowerUpConfig.defaults.encode()!),
      PowerUpConfig.defaults,
    );

    String enc(String json) => Uri.encodeComponent(json); // not base64: garbage
    expect(PowerUpConfig.decode(enc('{"dmg.knife": 33}')), isNull);
    final outOfRange = PowerUpConfig(const {'dmg.knife': 1000}).encode()!;
    expect(PowerUpConfig.decode(outOfRange), isNull);
    final unknown = PowerUpConfig(const {'laser': 3}).encode()!;
    expect(PowerUpConfig.decode(unknown), isNull);
    final fractionalCount = PowerUpConfig(const {'pellets': 2.5}).encode()!;
    expect(PowerUpConfig.decode(fractionalCount), isNull);
  });

  test('a match plays with its config: damage and aim time follow it', () {
    final config = PowerUpConfig.defaults
        .withValue('dmg.pistol', 33)
        .withValue('aim', 0.5);
    final c = MatchSimulationController(
      _balls,
      arenaRadius: 260,
      seed: 1,
      layoutRotation: 0,
      mode: MatchMode.arsenal,
      lookAhead: false,
      tuning: config,
    );
    final [a, b] = c.state.balls;
    for (final ball in [a, b]) {
      ball.velocity = Offset.zero;
    }
    a.position = const Offset(-100, 0);
    b
      ..position = const Offset(100, 0)
      ..held = PowerUpKind.pistol;
    for (var i = 0; i < 30; i++) {
      c.tick(1 / 60);
    }
    expect(c.powerUps!.shots, 1);
    for (var i = 0; i < 60 && c.powerUps!.projectiles.isNotEmpty; i++) {
      c.tick(1 / 60);
    }
    expect(a.life, PowerUpTuning.arenaLife - 33);
  });

  test('a match with the default config plays exactly as before', () {
    MatchSimulationController play(PowerUpConfig? config) {
      final c = config == null
          ? MatchSimulationController(
              _balls,
              arenaRadius: 260,
              seed: 7,
              mode: MatchMode.arsenal,
              lookAhead: false,
            )
          : MatchSimulationController(
              _balls,
              arenaRadius: 260,
              seed: 7,
              mode: MatchMode.arsenal,
              lookAhead: false,
              tuning: config,
            );
      while (c.state.winnerId == null && c.stepCount < 60 * 60 * 5) {
        c.tick(1 / 60);
      }
      return c;
    }

    final a = play(null);
    final b = play(PowerUpConfig.fromJson(const {}));
    expect(b.stepCount, a.stepCount);
    expect(b.state.winnerId, a.state.winnerId);
  });

  test('weapon descriptions show the configured numbers', () {
    final config = PowerUpConfig.defaults.withValue('dmg.pistol', 33);
    expect(
      powerUpDescription(PowerUpKind.pistol, arsenal: true, config: config),
      contains('33 damage'),
    );
  });

  test('damage-over-time fields use the concise DoT label', () {
    final molotov = PowerUpConfig.fields.singleWhere(
      (field) => field.id == 'dmg.molotov',
    );
    expect(molotov.label, 'Molotov (DoT)');
    expect(molotov.label, isNot(contains('tick')));
  });
  test('unarmed collision tuning follows the attacking ball equipment', () {
    MatchSimulationController collide({
      required double damage,
      bool armedA = false,
    }) {
      final match = MatchSimulationController(
        _balls,
        arenaRadius: 200,
        seed: 42,
        lookAhead: false,
        slowMotionLines: 0,
        mode: MatchMode.arsenal,
        tuning: PowerUpConfig.defaults.withValue('unarmedCollision', damage),
      );
      match.powerUps!.automaticSpawning = false;
      final a = match.state.balls[0];
      final b = match.state.balls[1];
      a.position = Offset(-a.radius * 0.9, 0);
      b.position = Offset(b.radius * 0.9, 0);
      a.velocity = const Offset(100, 0);
      b.velocity = const Offset(-100, 0);
      if (armedA) a.held = PowerUpKind.pistol;
      match.tick(MatchSimulationController.fixedTimestep);
      return match;
    }

    final tuned = collide(damage: 12);
    expect(tuned.state.balls[0].life, PowerUpTuning.arenaLife - 12);
    expect(tuned.state.balls[1].life, PowerUpTuning.arenaLife - 12);
    final disabled = collide(damage: 0);
    expect(
      disabled.state.balls.every((b) => b.life == PowerUpTuning.arenaLife),
      isTrue,
    );
    final mixed = collide(damage: 0, armedA: true);
    expect(mixed.state.balls[0].life, PowerUpTuning.arenaLife);
    expect(
      mixed.state.balls[1].life,
      PowerUpTuning.arenaLife - PowerUpTuning.arenaCollisionDamage,
    );
  });

  test('unarmed collision damage round-trips in replay tuning', () {
    final config = PowerUpConfig.defaults.withValue('unarmedCollision', 12);
    expect(PowerUpConfig.decode(config.encode()!)!.unarmedCollisionDamage, 12);
  });

  test('frozen damage settings round-trip in replay tuning', () {
    final config = PowerUpConfig.defaults
        .withValue('frozenDamageMultiplier', 2)
        .withValue('frozenCollisionDamage', 8);
    final decoded = PowerUpConfig.decode(config.encode()!)!;
    expect(decoded.frozenDamageMultiplier, 2);
    expect(decoded.frozenCollisionDamage, 8);
  });
}
