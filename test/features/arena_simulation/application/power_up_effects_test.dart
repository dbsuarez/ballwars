import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/application/power_up_system.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

const _arenaRadius = 260.0;
const _life = PowerUpTuning.arenaLife;

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
    glowColor: Colors.lime,
  ),
];

/// A match with [count] balls held still. Arsenal: the first two at (-100, 0) and (100, 0). All-Out: on
/// their own side of the rim, ball 0 (owning the right half) at (100, 0) and ball 1 at (-100, 0). A third
/// ball sits at (0, 180).
MatchSimulationController _match({
  MatchMode mode = MatchMode.arsenal,
  int count = 2,
  int seed = 1,
  bool dualWield = false,
  PowerUpConfig tuning = PowerUpConfig.defaults,
  SkillLibrary skillLibrary = SkillLibrary.defaults,
  ArenaDecoration arenaDecoration = ArenaDecoration.defaultArena,
}) {
  final c = MatchSimulationController(
    _balls.take(count).toList(),
    arenaRadius: _arenaRadius,
    seed: seed,
    layoutRotation: 0,
    mode: mode,
    lookAhead: false,
    dualWield: dualWield,
    tuning: tuning,
    skillLibrary: skillLibrary,
    arenaDecoration: arenaDecoration,
  );
  final balls = c.state.balls;
  for (final b in balls) {
    b.velocity = Offset.zero;
  }
  final side = mode == MatchMode.arsenal ? -1.0 : 1.0;
  balls[0].position = Offset(100 * side, 0);
  balls[1].position = Offset(-100 * side, 0);
  if (count > 2) balls[2].position = const Offset(0, 180);
  return c;
}

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.tick(1 / 60);
  }
}

/// Puts a power-up of [kind] under [ball] and runs one step, so the ball picks it up.
void _give(MatchSimulationController c, SimulationBall ball, PowerUpKind kind) {
  c.powerUps!.field.add(
    FieldPowerUp(kind: kind, position: ball.position, spawnStep: 0),
  );
  _run(c, 1);
}

/// Sends [a] and [b] at each other from just apart, and runs until they bump (at most 30 steps).
void _bump(MatchSimulationController c, SimulationBall a, SimulationBall b) {
  final gap = a.radius + b.radius + 4;
  a
    ..position = Offset(-gap / 2, 0)
    ..velocity = const Offset(60, 0);
  b
    ..position = Offset(gap / 2, 0)
    ..velocity = const Offset(-60, 0);
  final before = c.ballHits;
  for (var i = 0; i < 30 && c.ballHits == before; i++) {
    _run(c, 1);
  }
  expect(c.ballHits, before + 1, reason: 'the balls never bumped');
}

/// A bullet from [owner] about to strike [target] from the left.
Projectile _bulletAt(
  SimulationBall owner,
  SimulationBall target, {
  PowerUpKind kind = PowerUpKind.pistol,
}) => Projectile(
  owner: owner,
  kind: kind,
  position: target.position - Offset(target.radius + 5, 0),
  velocity: const Offset(_arenaRadius * PowerUpTuning.bulletSpeedRatio, 0),
);

void main() {
  test('a composed pickup skill executes its new behavior', () {
    final draft = SkillLibrary.defaults
        .create('Apple Shockwave', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.allOpponents,
          delivery: SkillDelivery.area,
          effectType: SkillEffectType.damage,
          arsenalDamage: 17,
          yell: 'SHOCKWAVE!',
        );
    final library = SkillLibrary.defaults.withDefinition(
      draft,
      PowerUpConfig.defaults,
    );
    final c = _match(skillLibrary: library);
    final owner = c.state.balls.first;
    final target = c.state.balls.last;

    _give(c, owner, PowerUpKind.apple);

    expect(target.life, _life - 17);
    expect(c.powerUps!.skillSounds, isNotEmpty);
  });

  test('Speed deals its configured collision damage', () {
    final speed = SkillLibrary.defaults
        .builtIn(PowerUpKind.speed, PowerUpConfig.defaults)
        .copyWith(arsenalDamage: 9);
    final c = _match(
      skillLibrary: SkillLibrary.defaults.withDefinition(
        speed,
        PowerUpConfig.defaults,
      ),
    );
    final [owner, target] = c.state.balls;
    owner.speedLeft = 60;

    c.powerUps!.onContact(owner, target);

    expect(target.life, _life - 9);
  });

  test('composed projectile parameters launch the configured volley', () {
    final volley = SkillLibrary.defaults
        .create('Seeking Volley', PowerUpKind.pistol)
        .copyWith(
          enabled: true,
          projectileCount: 3,
          projectileSize: 1.8,
          projectileSpin: 360,
          spreadDegrees: 24,
          homing: true,
          returnsToOrigin: true,
          maxBounces: 2,
        );
    final c = _match(
      skillLibrary: SkillLibrary.defaults.withDefinition(
        volley,
        PowerUpConfig.defaults,
      ),
    );
    final owner = c.state.balls.first;
    _give(c, owner, PowerUpKind.pistol);
    owner.aimLeft = 1;

    _run(c, 1);

    expect(c.powerUps!.projectiles, hasLength(3));
    expect(c.powerUps!.projectiles.every((shot) => shot.homing), isTrue);
    expect(
      c.powerUps!.projectiles.every((shot) => shot.renderScale == 1.8),
      isTrue,
    );
    expect(
      c.powerUps!.projectiles.every((shot) => shot.spinDegreesPerSecond == 360),
      isTrue,
    );
  });

  test('a composed skill chains effects and repeats deterministically', () {
    final draft = SkillLibrary.defaults
        .create('Stunning Pulse', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.allOpponents,
          delivery: SkillDelivery.area,
          effectType: SkillEffectType.damage,
          secondaryEffectType: SkillEffectType.speed,
          arsenalDamage: 7,
          durationSeconds: 1,
          repeatCount: 3,
          repeatIntervalSeconds: 0.1,
        );
    final library = SkillLibrary.defaults.withDefinition(
      draft,
      PowerUpConfig.defaults,
    );
    final c = _match(skillLibrary: library);
    final owner = c.state.balls.first;
    final target = c.state.balls.last;

    _give(c, owner, PowerUpKind.apple);
    expect(target.life, _life - 7);
    expect(target.speedLeft, greaterThan(0));

    _run(c, 12);
    expect(target.life, _life - 21);
  });

  test('a DoT-only composed skill has no initial damage', () {
    final dot = SkillLibrary.defaults
        .create('Slow Burn', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.nearestOpponent,
          delivery: SkillDelivery.instant,
          effectType: SkillEffectType.damageOverTime,
          arsenalDamage: 0,
          dotArsenalDamage: 4,
          durationSeconds: 1,
          tickIntervalSeconds: 0.5,
        );
    final c = _match(
      skillLibrary: SkillLibrary.defaults.withDefinition(
        dot,
        PowerUpConfig.defaults,
      ),
    );
    final [owner, target] = c.state.balls;
    _give(c, owner, PowerUpKind.apple);
    expect(target.life, _life);
    _run(c, 30);
    expect(target.life, _life - 4);
  });

  test('composed start delay and cooldown use deterministic match steps', () {
    final draft = SkillLibrary.defaults
        .create('Delayed Pulse', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.allOpponents,
          delivery: SkillDelivery.area,
          effectType: SkillEffectType.damage,
          arsenalDamage: 8,
          startDelaySeconds: 0.1,
          cooldownSeconds: 1,
        );
    final c = _match(
      skillLibrary: SkillLibrary.defaults.withDefinition(
        draft,
        PowerUpConfig.defaults,
      ),
    );
    c.powerUps!.automaticSpawning = false;
    final owner = c.state.balls.first;
    final target = c.state.balls.last;

    _give(c, owner, PowerUpKind.apple);
    expect(target.life, _life);
    _run(c, 6);
    expect(target.life, _life - 8);

    _give(c, owner, PowerUpKind.apple);
    _run(c, 6);
    expect(target.life, _life - 8);

    _run(c, 48);
    _give(c, owner, PowerUpKind.apple);
    _run(c, 6);
    expect(target.life, _life - 16);
  });

  test('custom effect scheduling is capped under pickup spam', () {
    final delayed = SkillLibrary.defaults
        .create('Delayed Storm', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.allOpponents,
          delivery: SkillDelivery.area,
          effectType: SkillEffectType.damage,
          startDelaySeconds: 30,
          repeatCount: 10,
        );
    final c = _match(
      skillLibrary: SkillLibrary.defaults.withDefinition(
        delayed,
        PowerUpConfig.defaults,
      ),
    );
    c.powerUps!.automaticSpawning = false;
    for (var i = 0; i < 80; i++) {
      _give(c, c.state.balls.first, PowerUpKind.apple);
    }

    expect(
      c.powerUps!.activeCustomEffectCount,
      PowerUpSystem.maxScheduledCustomEffects,
    );
  });

  test('chosen-direction beam only strikes a ball in front of its owner', () {
    final beam = SkillLibrary.defaults
        .create('Directional Beam', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.chosenDirection,
          delivery: SkillDelivery.beam,
          effectType: SkillEffectType.damage,
          arsenalDamage: 9,
        );
    final c = _match(
      count: 3,
      skillLibrary: SkillLibrary.defaults.withDefinition(
        beam,
        PowerUpConfig.defaults,
      ),
    );
    final [owner, ahead, above] = c.state.balls;
    owner
      ..position = Offset.zero
      ..velocity = const Offset(100, 0);
    ahead.position = const Offset(120, 0);
    above.position = const Offset(0, 150);

    _give(c, owner, PowerUpKind.apple);

    expect(ahead.life, _life - 9 * 2.25);
    expect(above.life, _life);
  });

  test('arena-location boundary hazard selects an opponent at the rim', () {
    final hazard = SkillLibrary.defaults
        .create('Rim Burst', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.arenaLocation,
          delivery: SkillDelivery.boundaryHazard,
          effectType: SkillEffectType.damage,
          arsenalDamage: 11,
        );
    final c = _match(
      count: 3,
      skillLibrary: SkillLibrary.defaults.withDefinition(
        hazard,
        PowerUpConfig.defaults,
      ),
    );
    final [owner, atRim, center] = c.state.balls;
    owner
      ..position = Offset.zero
      ..velocity = const Offset(100, 0);
    atRim.position = const Offset(210, 0);
    center.position = const Offset(0, 40);

    _give(c, owner, PowerUpKind.apple);

    expect(atRim.life, _life - 11 * 2.25);
    expect(center.life, _life);
  });

  test('aura and orbit deliveries respect their ranges', () {
    SkillLibrary libraryFor(SkillDelivery delivery) {
      final skill = SkillLibrary.defaults
          .create('${delivery.name} pulse', PowerUpKind.apple)
          .copyWith(
            enabled: true,
            trigger: SkillTrigger.pickup,
            targeting: SkillTargeting.allOpponents,
            delivery: delivery,
            effectType: SkillEffectType.damage,
            arsenalDamage: 6,
          );
      return SkillLibrary.defaults.withDefinition(
        skill,
        PowerUpConfig.defaults,
      );
    }

    for (final delivery in [SkillDelivery.aura, SkillDelivery.orbit]) {
      final c = _match(count: 3, skillLibrary: libraryFor(delivery));
      final [owner, close, far] = c.state.balls;
      owner.position = Offset.zero;
      close.position = const Offset(130, 0);
      far.position = const Offset(230, 0);
      _give(c, owner, PowerUpKind.apple);
      expect(close.life, _life - 6 * 2.25, reason: delivery.name);
      expect(far.life, _life, reason: delivery.name);
    }
  });

  test('advanced composed effects execute in live simulation', () {
    SkillLibrary libraryFor(
      SkillEffectType effect, {
      PowerUpKind carrier = PowerUpKind.apple,
      SkillTargeting targeting = SkillTargeting.allOpponents,
    }) {
      final draft = SkillLibrary.defaults
          .create('Advanced Effect', carrier)
          .copyWith(
            enabled: true,
            trigger: SkillTrigger.pickup,
            targeting: targeting,
            delivery: SkillDelivery.instant,
            effectType: effect,
            arsenalDamage: 6,
            dotArsenalDamage: 6,
            durationSeconds: 1,
            projectileCount: 2,
            shieldHits: 2,
            knockback: 1,
          );
      return SkillLibrary.defaults.withDefinition(
        draft,
        PowerUpConfig.defaults,
      );
    }

    final dot = _match(
      skillLibrary: libraryFor(SkillEffectType.damageOverTime),
    );
    _give(dot, dot.state.balls.first, PowerUpKind.apple);
    _run(dot, 30);
    expect(dot.state.balls.last.life, _life - 6);

    final shield = _match(
      skillLibrary: libraryFor(
        SkillEffectType.shield,
        targeting: SkillTargeting.self,
      ),
    );
    _give(shield, shield.state.balls.first, PowerUpKind.apple);
    expect(shield.state.balls.first.goldenArmorHits, 2);

    final pull = _match(skillLibrary: libraryFor(SkillEffectType.pull));
    _give(pull, pull.state.balls.first, PowerUpKind.apple);
    expect(pull.state.balls.last.velocity.dx, lessThan(0));

    final teleport = _match(skillLibrary: libraryFor(SkillEffectType.teleport));
    final teleportTarget = teleport.state.balls.last;
    final beforeTeleport = teleportTarget.position;
    _give(teleport, teleport.state.balls.first, PowerUpKind.apple);
    expect(teleportTarget.position, isNot(beforeTeleport));

    final stun = _match(skillLibrary: libraryFor(SkillEffectType.stun));
    _give(stun, stun.state.balls.first, PowerUpKind.apple);
    expect(stun.state.balls.last.stunnedLeft, 59);
    expect(stun.state.balls.last.velocity, Offset.zero);

    final equip = _match(
      skillLibrary: libraryFor(
        SkillEffectType.equipCarrier,
        carrier: PowerUpKind.pistol,
        targeting: SkillTargeting.self,
      ),
    );
    _give(equip, equip.state.balls.first, PowerUpKind.pistol);
    expect(equip.state.balls.first.held, PowerUpKind.pistol);

    final disarm = _match(
      skillLibrary: libraryFor(
        SkillEffectType.disarm,
        targeting: SkillTargeting.self,
      ),
    );
    disarm.state.balls.first.held = PowerUpKind.shield;
    _give(disarm, disarm.state.balls.first, PowerUpKind.apple);
    expect(disarm.state.balls.first.equippedWeapons, isEmpty);
  });

  test('frozen targets take configured extra damage and collision damage', () {
    final tuning = PowerUpConfig.defaults
        .withValue('frozenDamageMultiplier', 1.5)
        .withValue('frozenCollisionDamage', 5);
    final c = _match(tuning: tuning);
    final [a, b] = c.state.balls;
    b.frozenLeft = 60;

    expect(c.damage(b, 10, attacker: a), 15);
    expect(b.hurtFlashLeft, MatchSimulationController.hurtFlashSteps);

    final before = b.life;
    _bump(c, a, b);
    expect(before - b.life, greaterThanOrEqualTo(5));
  });

  test('Gremlin reverses an entire shotgun volley', () {
    final c = _match();
    c.powerUps!.automaticSpawning = false;
    final [a, b] = c.state.balls;
    _give(c, a, PowerUpKind.gremlin);
    expect(b.gremlinShots, 1);
    b.held = PowerUpKind.shotgun;

    _run(c, c.tuning.aimSteps + 1);

    final pellets = c.powerUps!.projectiles
        .where((p) => p.kind == PowerUpKind.shotgun)
        .toList();
    expect(pellets, hasLength(c.tuning.shotgunPellets));
    expect(pellets.every((p) => p.velocity.dx > 0), isTrue);
    expect(b.gremlinShots, 0);
  });

  test('automatic spawning does not duplicate an unclaimed pickup', () {
    final c = MatchSimulationController(
      _balls.take(2).toList(),
      arenaRadius: _arenaRadius,
      seed: 7,
      mode: MatchMode.arsenal,
      lookAhead: false,
      powerUpKinds: const {PowerUpKind.pistol},
      tuning: PowerUpConfig.defaults
          .withValue('firstSpawn', 0)
          .withValue('spawnEvery', 0.5),
    );
    for (final ball in c.state.balls) {
      ball
        ..position = Offset.zero
        ..velocity = Offset.zero;
    }

    _run(c, 180);

    expect(
      c.powerUps!.field.where((p) => p.kind == PowerUpKind.pistol),
      hasLength(1),
    );
  });

  test('Omega Tendrils unavoidably grabs every opponent and slams lightly', () {
    final c = _match(count: 3);
    final [owner, shieldedGhost, armored] = c.state.balls;
    shieldedGhost
      ..held = PowerUpKind.shield
      ..ghostLeft = 120;
    armored.goldenArmorHits = 1;

    _give(c, owner, PowerUpKind.omegaTendrils);
    expect(c.powerUps!.omegaTendrils, hasLength(2));
    _run(c, 36);

    expect(shieldedGhost.life, lessThan(_life));
    expect(shieldedGhost.held, PowerUpKind.shield);
    expect(armored.life, _life);
    expect(armored.goldenArmorHits, 0);
    expect(c.powerUps!.blasts, 2);
    for (final target in [shieldedGhost, armored]) {
      final away = target.position - owner.position;
      expect(
        target.velocity.dx * away.dx + target.velocity.dy * away.dy,
        greaterThan(0),
      );
    }
  });

  test('Mirror returns a projectile and damages its original attacker', () {
    final c = _match();
    final [attacker, mirror] = c.state.balls;
    mirror.mirrorCharges = 1;
    c.powerUps!.projectiles.add(_bulletAt(attacker, mirror));
    _run(c, 90);
    expect(mirror.life, _life);
    expect(mirror.mirrorCharges, 0);
    expect(attacker.life, lessThan(_life));
  });

  test('Magnetic field returns only one projectile per attacker', () {
    final c = _match();
    final [attacker, field] = c.state.balls;
    field.magneticFieldLeft = 120;
    c.powerUps!.projectiles.addAll([
      _bulletAt(attacker, field),
      _bulletAt(attacker, field),
    ]);
    _run(c, 90);
    expect(field.life, _life);
    expect(
      attacker.life,
      _life - PowerUpTuning.arenaDamage[PowerUpKind.pistol]!,
    );
  });

  test(
    'portal sends its entrant to a random arena side and leaves a warp flash',
    () {
      final c = _match(seed: 17);
      final a = c.state.balls[0];
      final entrance = a.position;
      a.equipWeapon(PowerUpKind.pistol, dualWield: false);

      c.powerUps!.portals.add(ArenaPortal(position: entrance, spawnStep: 0));
      _run(c, 1);

      expect(a.position, isNot(entrance));
      expect(
        a.position.distance,
        closeTo(_arenaRadius - a.radius * 1.5, 0.001),
      );
      expect(a.held, PowerUpKind.pistol);
      expect(c.powerUps!.portalFlashes, hasLength(1));
      expect(c.powerUps!.portals, isEmpty);
      expect(c.powerUps!.portalFlashes.single.from, entrance);
      expect(c.powerUps!.portalFlashes.single.to, a.position);
      expect(c.powerUps!.pickups, 0);
      expect(
        c.state.floatingTexts.items.map((text) => text.text),
        contains('WARP SPEED!'),
      );
    },
  );

  test('spike wall damages, knocks inward and preserves the weapon', () {
    final c = _match();
    final a = c.state.balls[0]
      ..position = const Offset(-100, 0)
      ..velocity = Offset.zero;
    a.equipWeapon(PowerUpKind.shotgun, dualWield: false);

    c.powerUps!.spikeWalls.add(
      SpikeWall(position: a.position, angle: 0, spawnStep: 0),
    );
    _run(c, 1);

    expect(a.life, _life - PowerUpTuning.arenaDamage[PowerUpKind.spikeWall]!);
    expect(a.velocity.dx, greaterThan(0));
    expect(a.held, PowerUpKind.shotgun);
    expect(c.powerUps!.slashMarks, isNotEmpty);
    expect(c.powerUps!.spikeWalls, isEmpty);
    expect(c.powerUps!.pickups, 0);
    expect(
      c.state.floatingTexts.items.map((text) => text.text),
      contains('OUCH! SPIKES!'),
    );
  });

  test('green sticky goo holds a ball in place for two seconds', () {
    final c = _match();
    final a = c.state.balls[0]..velocity = const Offset(90, 0);
    c.powerUps!.stickyGoo.add(StickyGoo(position: a.position, spawnStep: 0));

    _run(c, 1);
    expect(c.powerUps!.stickyGoo, isEmpty);
    expect(a.stickyGooLeft, PowerUpTuning.stickyGooSteps);
    expect(a.velocity, Offset.zero);
    expect(
      c.state.floatingTexts.items.map((text) => text.text),
      contains('STUCK!'),
    );

    _run(c, PowerUpTuning.stickyGooSteps - 1);
    expect(a.velocity, Offset.zero);
    _run(c, 1);
    expect(a.stickyGooLeft, 0);
    expect(a.velocity.distance, greaterThan(0));
  });

  test('golden armor blocks two hits completely, then shatters', () {
    final c = _match();
    final a = c.state.balls[0];
    a.equipWeapon(PowerUpKind.pistol, dualWield: false);

    _give(c, a, PowerUpKind.goldenArmor);
    expect(a.held, PowerUpKind.pistol);
    expect(a.goldenArmorHits, 2);
    expect(c.damage(a, 30), 0);
    expect(a.life, _life);
    expect(a.goldenArmorHits, 1);
    expect(c.damage(a, 30), 0);
    expect(a.life, _life);
    expect(a.goldenArmorHits, 0);
    expect(
      c.state.floatingTexts.items.map((text) => text.text),
      contains('ARMOR BROKEN!'),
    );
    expect(c.damage(a, 30), 30);
    expect(a.life, _life - 30);
  });

  test('a knife damages on contact and is used up', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.knife;
    _bump(c, a, b);
    expect(
      b.life,
      _life -
          PowerUpTuning.arenaCollisionDamage -
          PowerUpTuning.arenaDamage[PowerUpKind.knife]!,
    );
    expect(a.life, _life - PowerUpTuning.arenaCollisionDamage);
    expect(a.held, isNull);
    expect(c.powerUps!.slashes, 1);
    final blood = c.state.particles.particles.whereType<Particle>().where(
      (p) => p.color == c.bloodColor,
    );
    expect(blood, isNotEmpty);
  });

  test('a shield blocks 75% of the next hit, then breaks', () {
    final c = _match();
    final [a, b] = c.state.balls;
    b.held = PowerUpKind.shield;
    final bullet = _bulletAt(a, b);
    c.powerUps!.projectiles.add(bullet);
    _run(c, 1);
    expect(bullet.spent, isTrue);
    expect(
      b.life,
      closeTo(
        _life -
            PowerUpTuning.arenaDamage[PowerUpKind.pistol]! *
                (1 - PowerUpTuning.shieldBlock),
        1e-9,
      ),
    );
    expect(b.held, isNull);
    expect(c.powerUps!.blocks, 1);

    // The next hit lands in full.
    final second = _bulletAt(a, b);
    c.powerUps!.projectiles.add(second);
    _run(c, 1);
    expect(
      b.life,
      closeTo(
        _life -
            PowerUpTuning.arenaDamage[PowerUpKind.pistol]! *
                (2 - PowerUpTuning.shieldBlock),
        1e-9,
      ),
    );
  });

  test('a shield also blocks a knife, and the knife is still used up', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.knife;
    b.held = PowerUpKind.shield;
    _bump(c, a, b);
    expect(
      b.life,
      closeTo(
        _life -
            PowerUpTuning.arenaCollisionDamage -
            PowerUpTuning.arenaDamage[PowerUpKind.knife]! *
                (1 - PowerUpTuning.shieldBlock),
        1e-9,
      ),
    );
    // A was armed, so B's shield blocked instead of bashing.
    expect(a.life, _life - PowerUpTuning.arenaCollisionDamage);
    expect(a.held, isNull);
    expect(b.held, isNull);
  });

  test('a shield bashes an unarmed opponent and breaks', () {
    final c = _match();
    final [a, b] = c.state.balls;
    a.held = PowerUpKind.shield;
    _bump(c, a, b);
    expect(
      b.life,
      _life -
          PowerUpTuning.arenaCollisionDamage -
          PowerUpTuning.arenaShieldBash,
    );
    expect(a.life, _life - PowerUpTuning.arenaCollisionDamage);
    expect(a.held, isNull);

    // Against an armed opponent there is no bash.
    final d = _match();
    final [x, y] = d.state.balls;
    x.held = PowerUpKind.shield;
    y.held = PowerUpKind.pistol;
    _bump(d, x, y);
    expect(y.life, _life - PowerUpTuning.arenaCollisionDamage);
    expect(x.life, _life - PowerUpTuning.arenaCollisionDamage);
    expect(x.held, PowerUpKind.shield);
  });

  test(
    'the shield turns toward an incoming bullet, else the nearest opponent',
    () {
      final c = _match(count: 3);
      final [a, b, other] = c.state.balls;
      a
        ..position = const Offset(0, 60)
        ..held = PowerUpKind.shield;
      _run(c, 60);
      final toB = b.position - a.position;
      expect(a.shieldAngle, closeTo(math.atan2(toB.dy, toB.dx), 1e-6));

      // A bullet from C coming up from below: the shield swings round to face it.
      c.powerUps!.projectiles.add(
        Projectile(
          owner: other,
          kind: PowerUpKind.pistol,
          position: a.position + const Offset(0, 150),
          velocity: const Offset(0, -30),
        ),
      );
      _run(c, 30);
      final bullet = c.powerUps!.projectiles.single;
      final toBullet = bullet.position - a.position;
      expect(
        a.shieldAngle,
        closeTo(math.atan2(toBullet.dy, toBullet.dx), 1e-6),
      );
    },
  );

  test('power-ups preserve equipment; weapons replace it', () {
    for (final kind in [
      PowerUpKind.apple,
      PowerUpKind.speed,
      PowerUpKind.ghost,
      PowerUpKind.magnet,
      PowerUpKind.shield,
    ]) {
      final c = _match();
      final a = c.state.balls.first;
      a
        ..held = PowerUpKind.knife
        ..aimLeft = 12
        ..aimTarget = c.state.balls.last
        ..life = _life / 2;
      _give(c, a, kind);
      final preserves = kind.isPowerUp;
      expect(
        a.held,
        preserves
            ? PowerUpKind.knife
            : kind == PowerUpKind.shield
            ? PowerUpKind.shield
            : isNull,
        reason: kind.label,
      );
      expect(a.aimLeft, preserves ? 12 : 0, reason: '${kind.label} aim');
      expect(
        a.aimTarget,
        preserves ? c.state.balls.last : isNull,
        reason: '${kind.label} target',
      );
      if (kind == PowerUpKind.apple) {
        expect(a.life, _life / 2 + PowerUpTuning.arenaAppleHeal);
      }
    }
  });

  test(
    'dual wield keeps two weapons while single wield replaces the first',
    () {
      final dual = _match(dualWield: true);
      final dualBall = dual.state.balls.first;
      _give(dual, dualBall, PowerUpKind.pistol);
      _give(dual, dualBall, PowerUpKind.sword);
      expect(dualBall.equippedWeapons, [PowerUpKind.pistol, PowerUpKind.sword]);

      final single = _match();
      final singleBall = single.state.balls.first;
      _give(single, singleBall, PowerUpKind.pistol);
      _give(single, singleBall, PowerUpKind.sword);
      expect(singleBall.equippedWeapons, [PowerUpKind.sword]);
    },
  );

  test('rocket launcher is two-handed in a dual-wield match', () {
    final c = _match(dualWield: true);
    final ball = c.state.balls.first;
    _give(c, ball, PowerUpKind.pistol);
    _give(c, ball, PowerUpKind.sword);
    _give(c, ball, PowerUpKind.rocketLauncher);
    expect(ball.equippedWeapons, [PowerUpKind.rocketLauncher]);

    _give(c, ball, PowerUpKind.sword);
    expect(ball.equippedWeapons, [PowerUpKind.sword]);
    _give(c, ball, PowerUpKind.pistol);
    expect(ball.equippedWeapons, [PowerUpKind.sword, PowerUpKind.pistol]);
  });

  test('custom handedness overrides the carrier weapon default', () {
    final pistol = SkillLibrary.defaults
        .create('Heavy Pistol', PowerUpKind.pistol)
        .copyWith(enabled: true, handedness: SkillHandedness.twoHanded);
    final heavyPistol = _match(
      dualWield: true,
      skillLibrary: SkillLibrary.defaults.withDefinition(
        pistol,
        PowerUpConfig.defaults,
      ),
    );
    final first = heavyPistol.state.balls.first;
    _give(heavyPistol, first, PowerUpKind.pistol);
    _give(heavyPistol, first, PowerUpKind.sword);
    expect(first.equippedWeapons, [PowerUpKind.sword]);

    final launcher = SkillLibrary.defaults
        .create('Light Launcher', PowerUpKind.rocketLauncher)
        .copyWith(enabled: true, handedness: SkillHandedness.oneHanded);
    final lightLauncher = _match(
      dualWield: true,
      skillLibrary: SkillLibrary.defaults.withDefinition(
        launcher,
        PowerUpConfig.defaults,
      ),
    );
    final second = lightLauncher.state.balls.first;
    _give(lightLauncher, second, PowerUpKind.rocketLauncher);
    _give(lightLauncher, second, PowerUpKind.sword);
    expect(second.equippedWeapons, [
      PowerUpKind.rocketLauncher,
      PowerUpKind.sword,
    ]);
  });

  test('timer and damage-taken triggers activate deterministically', () {
    final timer = SkillLibrary.defaults
        .create('Pulse', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.timer,
          targeting: SkillTargeting.nearestOpponent,
          delivery: SkillDelivery.instant,
          effectType: SkillEffectType.damage,
          triggerIntervalSeconds: 0.5,
          arsenalDamage: 7,
        );
    final timerMatch = _match(
      skillLibrary: SkillLibrary.defaults.withDefinition(
        timer,
        PowerUpConfig.defaults,
      ),
    );
    timerMatch.powerUps!.automaticSpawning = false;
    _run(timerMatch, 30);
    expect(timerMatch.state.balls[1].life, _life - 7);

    final retaliation = SkillLibrary.defaults
        .create('Second Wind', PowerUpKind.shield)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.damageTaken,
          targeting: SkillTargeting.self,
          delivery: SkillDelivery.instant,
          effectType: SkillEffectType.heal,
          cooldownSeconds: 1,
          healing: 6,
        );
    final damageMatch = _match(
      skillLibrary: SkillLibrary.defaults.withDefinition(
        retaliation,
        PowerUpConfig.defaults,
      ),
    );
    damageMatch.powerUps!.automaticSpawning = false;
    final hurt = damageMatch.state.balls.first;
    damageMatch.damage(hurt, 20, attacker: damageMatch.state.balls.last);
    _run(damageMatch, 1);
    expect(hurt.life, _life - 14);
  });

  test('elimination trigger credits the attacker and applies its effect', () {
    final finisherReward = SkillLibrary.defaults
        .create('Victory Heal', PowerUpKind.apple)
        .copyWith(
          enabled: true,
          trigger: SkillTrigger.elimination,
          targeting: SkillTargeting.self,
          delivery: SkillDelivery.instant,
          effectType: SkillEffectType.heal,
          cooldownSeconds: 1,
          healing: 10,
        );
    final c = _match(
      count: 3,
      skillLibrary: SkillLibrary.defaults.withDefinition(
        finisherReward,
        PowerUpConfig.defaults,
      ),
    );
    c.powerUps!.automaticSpawning = false;
    final [owner, victim, _] = c.state.balls;
    owner.life = 50;
    victim.life = 1;
    c.damage(victim, 5, attacker: owner, move: 'Test hit');
    _run(c, 1);
    expect(owner.life, 60);
  });

  test('arena decoration deploys its automatic themed hazard', () {
    final c = _match(arenaDecoration: ArenaDecoration.space);
    c.powerUps!
      ..automaticSpawning = false
      ..spawnTestArenaHazard();
    expect(c.powerUps!.arenaThemeHazards, isNotEmpty);
    expect(
      c.powerUps!.arenaThemeHazards.single.kind,
      ArenaThemeHazardKind.gravityWell,
    );
  });

  test('admin can disable automatic arena theme hazards', () {
    final tuning = PowerUpConfig.defaults
        .withValue('arenaTrapsEnabled', 0)
        .withValue('trapStart', 0);
    final c = _match(arenaDecoration: ArenaDecoration.space, tuning: tuning);
    _run(c, 2);
    expect(c.powerUps!.arenaThemeHazards, isEmpty);
  });

  test('Chaotic arena deploys every arena-only trap together', () {
    final c = _match(arenaDecoration: ArenaDecoration.chaotic);
    c.powerUps!
      ..automaticSpawning = false
      ..spawnTestArenaHazard();
    expect(
      c.powerUps!.arenaThemeHazards.map((hazard) => hazard.kind).toSet(),
      ArenaThemeHazardKind.values.toSet(),
    );
  });

  test('boomerang can hit several opponents only once per throw', () {
    final c = _match(count: 3);
    final [owner, first, second] = c.state.balls;
    owner.position = const Offset(-180, 0);
    first.position = const Offset(-40, 0);
    second.position = const Offset(100, 0);

    _give(c, owner, PowerUpKind.boomerang);
    _run(c, PowerUpTuning.aimSteps + 2);
    final shot = c.powerUps!.projectiles.single;
    final launchSpot = shot.returnTo;
    owner.position = const Offset(-180, 80);
    _run(c, 420);

    expect(first.life, lessThan(_life));
    expect(second.life, lessThan(_life));
    expect(c.powerUps!.hits, 2);
    expect(shot.position, launchSpot);
    expect(c.powerUps!.projectiles.where((shot) => !shot.spent), isEmpty);
  });

  test('in All-Out a shield halves the threads lost to the next hit', () {
    final c = _match(mode: MatchMode.allOut);
    final [a, b] = c.state.balls;
    b.held = PowerUpKind.shield;
    final before = b.fanLines.length;
    final bullet = _bulletAt(a, b);
    c.powerUps!.projectiles.add(bullet);
    _run(c, 1);
    expect(bullet.spent, isTrue);
    expect(
      b.fanLines.length,
      before -
          (PowerUpTuning.allOutThreads[PowerUpKind.pistol]! *
                  PowerUpTuning.allOutShieldKeep)
              .round(),
    );
    expect(b.held, isNull);
  });

  test('apple heals 25 in Arsenal, past full life up to the max', () {
    final c = _match();
    final a = c.state.balls.first;
    _give(c, a, PowerUpKind.apple);
    expect(a.life, _life + PowerUpTuning.arenaAppleHeal);
    expect(a.held, isNull);
    a.life = PowerUpTuning.arenaMaxLife - 5;
    _give(c, a, PowerUpKind.apple);
    expect(a.life, PowerUpTuning.arenaMaxLife);

    a.life = _life / 2;
    _give(c, a, PowerUpKind.apple);
    expect(a.life, _life / 2 + PowerUpTuning.arenaAppleHeal);

    // A green sparkle burst.
    final sparkles = c.state.particles.particles.whereType<Particle>().where(
      (p) => p.color == ParticleSystem.sparkleColor,
    );
    expect(sparkles, isNotEmpty);
  });

  test(
    'apple in All-Out claims free rim slots, and gives 0 when none are free',
    () {
      final c = _match(mode: MatchMode.allOut);
      final [a, b] = c.state.balls;

      // Every slot is owned at the start: the apple does nothing.
      expect(c.freeSlotCount, 0);
      final start = a.fanLines.length;
      _give(c, a, PowerUpKind.apple);
      expect(a.fanLines.length, start);
      expect(c.freeSlotCount, 0);

      // With free slots it claims allOutAppleSlots of them and shows "+N LINES".
      // Free them near the bottom of the rim, where none of the new lines runs through b.
      c.cutThreads(b, 30, near: const Offset(0, _arenaRadius));
      expect(c.freeSlotCount, 30);
      _give(c, a, PowerUpKind.apple);
      expect(a.fanLines.length, start + PowerUpTuning.allOutAppleSlots);
      expect(a.lineCount, a.fanLines.length);
      expect(c.freeSlotCount, 30 - PowerUpTuning.allOutAppleSlots);
      expect(
        c.state.floatingTexts.items.where(
          (t) => t.text == '+${PowerUpTuning.allOutAppleSlots} LINES',
        ),
        isNotEmpty,
      );
      // Every claimed slot is a distinct one.
      expect(
        {
          for (final l in [...a.fanLines, ...b.fanLines]) l.slotIndex,
        }.length,
        a.fanLines.length + b.fanLines.length,
      );
    },
  );

  test('speed boost doubles speed for 180 steps', () {
    final c = _match();
    final a = c.state.balls.first;
    a.position = const Offset(-100, -100);
    _give(c, a, PowerUpKind.speed);
    a.velocity = const Offset(0, 30);
    expect(a.speedLeft, PowerUpTuning.speedSteps);
    for (var i = 0; i < PowerUpTuning.speedSteps; i++) {
      final before = a.position;
      _run(c, 1);
      expect(
        a.position.dy - before.dy,
        closeTo(30 / 60 * PowerUpTuning.speedFactor, 1e-9),
        reason: 'step $i',
      );
    }
    expect(a.speedLeft, 0);
    final before = a.position;
    _run(c, 1);
    expect(a.position.dy - before.dy, closeTo(30 / 60, 1e-9));
    expect(a.velocity, const Offset(0, 30));
  });

  test(
    'ghost passes through balls, cannot be hit and in All-Out neither loses nor cuts threads for 180 steps',
    () {
      // Arsenal: no bounce, no damage from bullets, knives or mines.
      final c = _match();
      final [a, b] = c.state.balls;
      _give(c, a, PowerUpKind.ghost);
      expect(a.ghostLeft, PowerUpTuning.ghostSteps);
      b.held = PowerUpKind.knife;
      a
        ..position = Offset.zero
        ..velocity = const Offset(30, 0);
      b
        ..position = const Offset(20, 0)
        ..velocity = const Offset(-30, 0);
      _run(c, 1);
      expect(c.ballHits, 0);
      expect(a.velocity, const Offset(30, 0));
      expect(b.velocity, const Offset(-30, 0));
      expect(a.life, _life);
      expect(b.held, PowerUpKind.knife);

      final bullet = _bulletAt(b, a);
      c.powerUps!.projectiles.add(bullet);
      c.powerUps!.mines.add(
        ArmedMine(owner: b, position: a.position, armedStep: 0),
      );
      _run(c, 1);
      expect(bullet.spent, isFalse);
      expect(a.life, _life);

      var ghostSteps = 2;
      while (a.isGhost) {
        _run(c, 1);
        ghostSteps++;
      }
      expect(ghostSteps, PowerUpTuning.ghostSteps);

      // All-Out: a ghost sitting across the opponent's threads, with the opponent across its own.
      final d = _match(mode: MatchMode.allOut);
      final [g, o] = d.state.balls;
      _give(d, g, PowerUpKind.ghost);
      g.position = const Offset(-150, 0);
      o.position = const Offset(150, 0);
      final gLines = g.fanLines.length;
      final oLines = o.fanLines.length;
      _run(d, 1);
      expect(g.fanLines.length, gLines);
      expect(o.fanLines.length, oLines);

      // A bullet through its threads cuts none of them.
      d.powerUps!.projectiles.add(
        Projectile(
          owner: o,
          kind: PowerUpKind.pistol,
          position: const Offset(200, -120),
          velocity: const Offset(
            0,
            _arenaRadius * PowerUpTuning.bulletSpeedRatio,
          ),
        ),
      );
      _run(d, 30);
      expect(g.fanLines.length, gLines);

      // Once the ghost wears off, the bodies cut again.
      _run(d, PowerUpTuning.ghostSteps);
      expect(g.isGhost, isFalse);
      expect(g.fanLines.length + o.fanLines.length, lessThan(gLines + oLines));
    },
  );

  test(
    'a bomb is armed where it lies by the first ball to touch it, and only an opponent sets it off',
    () {
      final c = _match(count: 3);
      final [a, b, other] = c.state.balls;
      a
        ..position = const Offset(-100, 0)
        ..held = PowerUpKind.knife;
      b.position = const Offset(-100 + 60, 0);
      final field = c.powerUps!.field;
      _give(c, a, PowerUpKind.mine);
      // Arming doesn't cost the held power-up, and the armed bomb leaves the field (no limit slot).
      expect(a.held, PowerUpKind.knife);
      expect(field, isEmpty);
      final bomb = c.powerUps!.mines.single;
      expect(bomb.owner, a);
      expect(bomb.position, a.position);

      // Its owner sitting on it never sets it off.
      _run(c, 120);
      expect(c.powerUps!.blasts, 0);
      expect(a.life, _life);

      // An opponent touching it does, at once; the owner is spared even in range.
      b.position = bomb.position + const Offset(10, 0);
      a.position = bomb.position - const Offset(40, 0);
      _run(c, 1);
      expect(c.powerUps!.blasts, 1);
      expect(c.powerUps!.mines, isEmpty);
      // 3 balls: crowded Arsenal damage is x2.25 (never below 0).
      expect(
        b.life,
        math.max(
          0.0,
          _life - PowerUpTuning.arenaDamage[PowerUpKind.mine]! * 2.25,
        ),
      );
      expect(a.life, _life);
      expect(other.life, _life);
      expect(
        c.state.floatingTexts.items.map((t) => t.text),
        contains('KABOOM!'),
      );
    },
  );

  test('a bomb whose owner is out is gone', () {
    final c = _match(count: 3);
    final [a, b, _] = c.state.balls;
    c.powerUps!.mines.add(
      ArmedMine(owner: a, position: const Offset(0, -150), armedStep: 0),
    );
    a.isEliminated = true;
    _run(c, 1);
    expect(c.powerUps!.mines, isEmpty);
    b.position = const Offset(0, -150);
    _run(c, 1);
    expect(c.powerUps!.blasts, 0);
  });

  test('two balls shooting each other out in one step still leave a winner', () {
    final shot = PowerUpTuning.arenaDamage[PowerUpKind.pistol]!;
    // Unequal life before the hits: the one with more life at the start of the step survives, with 1.
    final c = _match();
    final [a, b] = c.state.balls;
    a
      ..position = const Offset(-40, 0)
      ..life = shot - 10;
    b
      ..position = const Offset(40, 0)
      ..life = shot - 5;
    c.powerUps!.projectiles
      ..add(_bulletAt(b, a))
      ..add(_bulletAt(a, b));
    _run(c, 1);
    expect(c.state.status, MatchStatus.finished);
    expect(c.state.winnerId, b.config.id);
    expect(b.isEliminated, isFalse);
    expect(b.life, 1);
    expect(a.isEliminated, isTrue);
    expect(c.lastEliminatedId, a.config.id);

    // Equal life: a seeded coin flip still names a winner.
    for (var seed = 1; seed <= 6; seed++) {
      final d = _match(seed: seed);
      final [x, y] = d.state.balls;
      x
        ..position = const Offset(-40, 0)
        ..life = shot;
      y
        ..position = const Offset(40, 0)
        ..life = shot;
      d.powerUps!.projectiles
        ..add(_bulletAt(y, x))
        ..add(_bulletAt(x, y));
      _run(d, 1);
      expect(d.state.status, MatchStatus.finished);
      expect(d.state.winnerId, isNotNull);
      expect(d.state.balls.where((ball) => !ball.isEliminated).single.life, 1);
    }
  });

  test(
    'magnet pulls the nearest power-up at once, or the next spawn when the field is empty',
    () {
      final c = _match();
      final a = c.state.balls.first;
      final powerUps = c.powerUps!;
      powerUps.field
        ..add(
          FieldPowerUp(
            kind: PowerUpKind.knife,
            position: const Offset(0, 150),
            spawnStep: 0,
          ),
        )
        ..add(
          FieldPowerUp(
            kind: PowerUpKind.pistol,
            position: const Offset(0, -200),
            spawnStep: 0,
          ),
        );
      _give(c, a, PowerUpKind.magnet);
      final knife = powerUps.field.firstWhere(
        (p) => p.kind == PowerUpKind.knife,
      );
      expect(knife.position, a.position);
      expect(
        powerUps.field.firstWhere((p) => p.kind == PowerUpKind.pistol).position,
        const Offset(0, -200),
      );
      expect(a.magnetPending, isFalse);
      _run(c, 1);
      expect(a.held, PowerUpKind.knife);

      // Empty field: it waits for the next spawn.
      final d = _match();
      final x = d.state.balls.first;
      _give(d, x, PowerUpKind.magnet);
      expect(d.powerUps!.field, isEmpty);
      expect(x.magnetPending, isTrue);
      while (d.powerUps!.field.isEmpty &&
          d.stepCount < PowerUpTuning.spawnIntervalSteps * 2) {
        _run(d, 1);
      }
      expect(d.powerUps!.field.single.position, x.position);
      expect(x.magnetPending, isFalse);
    },
  );

  test('a magnet whose ball is eliminated does nothing', () {
    final c = _match(count: 3);
    final a = c.state.balls.first;
    a.magnetPending = true;
    a.isEliminated = true;
    while (c.powerUps!.field.isEmpty &&
        c.stepCount < PowerUpTuning.spawnIntervalSteps * 2) {
      _run(c, 1);
    }
    expect(c.powerUps!.field.single.position, isNot(a.position));
    expect(a.magnetPending, isFalse);
  });

  test(
    'a ball with no life or threads left this step neither fires nor is aimed at',
    () {
      // Arsenal: A is below one life but not yet marked out.
      final c = _match(count: 3);
      final [a, b, other] = c.state.balls;
      a
        ..life = 0.5
        ..held = PowerUpKind.pistol
        ..aimLeft = 1;
      b
        ..held = PowerUpKind.pistol
        ..aimLeft = 1;
      _run(c, 1);
      final shots = c.powerUps!.projectiles;
      expect(shots.length, 1);
      expect(shots.single.owner, same(b));
      final toOther = other.position - b.position;
      expect(
        math.atan2(shots.single.velocity.dy, shots.single.velocity.dx),
        closeTo(math.atan2(toOther.dy, toOther.dx), 1e-9),
      );

      // All-Out: A has no threads left.
      final d = _match(mode: MatchMode.allOut, count: 3);
      final [x, y, z] = d.state.balls;
      d.cutThreads(x, x.fanLines.length);
      x
        ..held = PowerUpKind.pistol
        ..aimLeft = 1;
      y
        ..held = PowerUpKind.pistol
        ..aimLeft = 1;
      _run(d, 1);
      final shot = d.powerUps!.projectiles.single;
      expect(shot.owner, same(y));
      final toZ = z.position - y.position;
      expect(
        math.atan2(shot.velocity.dy, shot.velocity.dx),
        closeTo(math.atan2(toZ.dy, toZ.dx), 1e-9),
      );
    },
  );

  test(
    'a shield softens a whole volley: every pellet of one shotgun blast is blocked the same way',
    () {
      final c = _match();
      final a = c.state.balls[0];
      final b = c.state.balls[1];
      b.held = PowerUpKind.shield;
      // Three pellets of one blast, all hitting B in the same step.
      for (final dy in [-6.0, 0.0, 6.0]) {
        c.powerUps!.projectiles.add(
          Projectile(
            owner: a,
            kind: PowerUpKind.shotgun,
            position: b.position + Offset(-b.radius - 2, dy),
            velocity: const Offset(600, 0),
            volley: 7,
          ),
        );
      }
      _run(c, 1);
      final pellet = PowerUpTuning.arenaDamage[PowerUpKind.shotgun]!;
      expect(
        b.life,
        closeTo(_life - 3 * pellet * (1 - PowerUpTuning.shieldBlock), 1e-9),
      );
      expect(b.held, isNull);
    },
  );

  test(
    'a ghost holding a gun does not aim or fire until the ghost wears off',
    () {
      final c = _match();
      final a = c.state.balls[0];
      a
        ..held = PowerUpKind.pistol
        ..ghostLeft = PowerUpTuning.aimSteps + 30;
      _run(c, PowerUpTuning.aimSteps + 20);
      expect(c.powerUps!.shots, 0);
      expect(a.held, PowerUpKind.pistol);
      _run(c, 10 + PowerUpTuning.aimSteps + 2);
      expect(c.powerUps!.shots, 1);
    },
  );
}
