import 'power_up_spawn_selector.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/utils/math_utils.dart';
import '../../../core/utils/seeded_random.dart';
import '../../match_setup/domain/match_config.dart';
import '../../skills/domain/skill_library.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/fan_line.dart';
import '../domain/floating_text.dart';
import '../domain/power_up.dart';
import '../domain/power_up_config.dart';
import '../domain/simulation_ball.dart';
import 'match_simulation_controller.dart';

/// Runs the power-ups of an Arsenal or All-Out match: spawning, pick-up, aiming, projectiles, mines and
/// the personal effects (apple, speed, ghost, magnet, shield).
///
/// The controller creates one (never in Threads mode), calls [onContact] for every ball-ball bump and
/// [step] once per simulation step, right after the ball-ball collisions. All randomness comes from the
/// match's [rng], drawn only inside the simulation step.
///
/// Guns, the knife and the shield are held ([SimulationBall.held]) until used. Apple, speed, ghost and
/// power-ups act at once and preserve an equipped weapon; weapon pickups replace it. A mine is not
/// carried: the first ball to touch it arms it where it lies ([ArmedMine]), and it keeps what it held. A
/// grenade is held like a gun: aimed, then thrown at where the target is, exploding where it lands.
///
/// Balls yell what they do ("BANG!", "SHIELD BASH!") and every hit shows the damage taken, as floating
/// labels (drawn only; no randomness).
class PowerUpSystem {
  PowerUpSystem(this.match, this.rng) {
    for (final ball in match.state.balls) {
      _lastVital[ball] = _vital(ball);
    }
  }

  /// The match this system belongs to (for [MatchSimulationController.damage] and
  /// [MatchSimulationController.cutThreads]).
  final MatchSimulationController match;

  /// The match's random source.
  final SeededRandom rng;

  /// The match's power-up numbers.
  PowerUpConfig get _t => match.tuning;

  /// Power-ups lying in the arena.
  final List<FieldPowerUp> field = [];

  /// Bullets and pellets in flight.
  final List<Projectile> projectiles = [];
  final Map<Projectile, SkillDefinition> _composedProjectiles = {};
  final List<_ScheduledComposedEffect> _scheduledComposedEffects = [];
  final List<_CustomDamageOverTime> _customDamageOverTime = [];
  final Map<(SimulationBall, String), int> _composedCooldownUntil = {};
  final Map<SimulationBall, double> _lastVital = {};

  /// Armed proximity mines waiting for an opponent of their owner.
  final List<ArmedMine> mines = [];

  /// Recent blasts, for drawing (removed after [PowerUpTuning.explosionShowSteps]).
  final List<Explosion> explosions = [];
  final List<WeaponImpact> weaponImpacts = [];

  /// Three-second floor fires created by thrown Molotovs.
  final List<BurningZone> burningZones = [];

  /// Recent portal exits and entries, retained briefly for the painter.
  final List<PortalFlash> portalFlashes = [];

  /// Portal openings at the arena edge. They are hazards, never pickups.
  final List<ArenaPortal> portals = [];

  /// Physical spike rows in the arena. They are hazards, never pickups.
  final List<SpikeWall> spikeWalls = [];

  /// Green boundary patches that hold the first ball touching them.
  final List<StickyGoo> stickyGoo = [];
  final List<PoisonSwamp> poisonSwamps = [];
  final List<FireWall> fireWalls = [];
  final List<DamageOverTime> damageOverTime = [];
  final List<LightningStrike> lightningStrikes = [];
  final List<EarthquakePulse> earthquakes = [];
  final List<Tornado> tornadoes = [];
  final List<EnergyWave> energyWaves = [];
  final List<EnergyWaveAttack> energyWaveAttacks = [];
  final List<FlameCone> flameCones = [];
  final List<ArenaThemeHazard> arenaThemeHazards = [];

  /// Recent knife slashes, for drawing (removed after [PowerUpTuning.slashShowSteps]).
  final List<SlashMark> slashMarks = [];

  /// Balls being reeled in by a hook.
  final List<HookPull> pulls = [];
  final List<OmegaTendril> omegaTendrils = [];

  /// How many power-ups balls have picked up so far (the screen plays a sound when it goes up).
  int pickups = 0;
  final Map<String, int> interactionSounds = {};
  void _sound(String event) =>
      interactionSounds.update(event, (value) => value + 1, ifAbsent: () => 1);

  /// Configured skill cues, counted separately so the UI can play the exact
  /// selected sound without changing deterministic simulation state.
  final Map<String, int> skillSounds = {};
  void _skillSound(PowerUpKind kind) {
    final cue = match.skillLibrary.activeFor(kind, _t).soundCue;
    skillSounds.update(cue, (value) => value + 1, ifAbsent: () => 1);
  }

  bool usesSprite(PowerUpKind kind) =>
      match.skillLibrary.activeFor(kind, _t).spriteMode ==
      SkillVisualMode.sprite;

  bool usesEffectSprite(PowerUpKind kind) =>
      match.skillLibrary.activeFor(kind, _t).effectMode ==
      SkillVisualMode.sprite;

  String skillName(PowerUpKind kind) =>
      match.skillLibrary.activeFor(kind, _t).name;

  void _skillYell(SimulationBall ball, PowerUpKind kind, String fallback) {
    final skill = match.skillLibrary.activeFor(kind, _t);
    final custom = skill.yell.trim();
    _yell(
      ball,
      custom.isEmpty ? fallback : custom,
      calloutStyle: CalloutStyle.values[skill.calloutStyle.index],
      calloutBubble: CalloutBubble.values[skill.bubbleType.index],
    );
  }

  /// Bullets, pellets and freeze shots fired so far (the screen plays a sound when it goes up).
  int shots = 0;

  /// Weapon hits landed on balls so far (the screen plays a sound when it goes up).
  int hits = 0;

  /// Knife hits landed so far (the screen plays a sound when it goes up).
  int slashes = 0;

  /// Bombs exploded so far (the screen plays a sound when it goes up).
  int blasts = 0;

  /// Hits a shield blocked so far (the screen plays a sound when it goes up).
  int blocks = 0;

  /// Gatling rounds fired so far, also counted in [shots] (the screen plays the gatling sound for them).
  int gatlingShots = 0;

  /// Clears equipment and every carried/timed effect before an Endless Battle respawn.
  void resetForRespawn(SimulationBall ball) {
    ball
      ..held = null
      ..heldSecondary = null
      ..heldTwoHanded = false
      ..heldSecondaryTwoHanded = false
      ..speedLeft = 0
      ..frozenLeft = 0
      ..stunnedLeft = 0
      ..ghostLeft = 0
      ..flailLeft = 0
      ..repulsorLeft = 0
      ..timeBubbleLeft = 0
      ..vampireLeft = 0
      ..mirrorCharges = 0
      ..overchargeLeft = 0
      ..gremlinShots = 0
      ..magneticFieldLeft = 0
      ..goldenArmorHits = 0
      ..stickyGooLeft = 0
      ..burningLeft = 0
      ..poisonLeft = 0
      ..sweepLeft = 0
      ..hurtFlashLeft = 0
      ..magnetPending = false
      ..aimLeft = 0
      ..aimTarget = null
      ..burstLeft = 0;
    ball.magneticReflectedOwners.clear();
    _frozenVelocity.remove(ball);
    _stunnedVelocity.remove(ball);
    _gooVelocity.remove(ball);
    _burstVolley.remove(ball);
    _firedWeaponHold.remove(ball);
    _shieldedVolley.remove(ball);
    _volleyLabel.remove(ball);
    _scheduledComposedEffects.removeWhere(
      (effect) =>
          identical(effect.owner, ball) || effect.targets.contains(ball),
    );
    _customDamageOverTime.removeWhere(
      (effect) =>
          identical(effect.owner, ball) || identical(effect.target, ball),
    );
    _composedCooldownUntil.removeWhere((key, _) => identical(key.$1, ball));
    pulls.removeWhere(
      (pull) => identical(pull.owner, ball) || identical(pull.target, ball),
    );
    omegaTendrils.removeWhere(
      (tendril) =>
          identical(tendril.owner, ball) || identical(tendril.target, ball),
    );
    for (final attack in energyWaveAttacks.toList()) {
      if (identical(attack.owner, ball) || attack.targets.contains(ball)) {
        _releaseEnergyWave(attack, launchAway: false);
      }
    }
  }

  /// Velocity of each frozen ball from before it was frozen, given back when it thaws.
  final Map<SimulationBall, Offset> _frozenVelocity = {};
  final Map<SimulationBall, Offset> _stunnedVelocity = {};
  final Map<SimulationBall, Offset> _gooVelocity = {};

  // Volleys: shots fired as one attack share an id; a shield that breaks on one of them softens the
  // rest of that volley too (see [_hit]).
  int _lastVolley = 0;
  final Map<SimulationBall, int> _burstVolley = {};
  final Map<SimulationBall, Map<PowerUpKind, int>> _firedWeaponHold = {};
  final Map<SimulationBall, int> _shieldedVolley = {};

  // The damage label of the last volley that hit each ball, so a volley's hits add up in one label.
  final Map<SimulationBall, (int, FloatingText, num)> _volleyLabel = {};

  static const Color _damageColor = Color(0xFFFF6B6B);
  static const Color _blastColor = Color(0xFFFFB347);

  /// Fastest a held shield turns toward its threat, in radians per step.
  static const double _shieldTurnPerStep = 0.25;

  /// Largest seeded turn of an inner shotgun pellet off its place in the fan, in radians.
  static const double _pelletJitter = 0.03;

  /// Fired weapons stay visible for half a second so recoil reads clearly.
  static const int firedWeaponHoldSteps = 30;

  int firedWeaponHoldLeft(SimulationBall ball, PowerUpKind kind) =>
      _firedWeaponHold[ball]?[kind] ?? 0;

  /// Pick-up radius of a field power-up: a little smaller than the balls, so it follows the ball size.
  late final double fieldRadius =
      match.state.balls.first.radius * _t.fieldRadiusRatio;

  /// How many balls the match started with (spawn rate and field limit follow it).
  late final int _ballCount = match.state.balls.length;

  /// Advances the power-ups by one simulation step.
  ///
  /// Timers count down first, so an effect picked up in step N lasts its full count from step N + 1 on
  /// (a speed boost picked up in step N runs from step N + 1).
  bool automaticSpawning = true;

  /// Place a selected item using the real spawn rules in the admin test arena.
  void spawnTestItem(PowerUpKind kind) =>
      _spawn(match.stepCount + 1, forcedKind: kind);

  /// Deploys the selected arena decoration's environmental hazard in tests.
  void spawnTestArenaHazard() => _spawnArenaThemeHazard(match.stepCount + 1);

  void step() {
    _processPassiveTriggers();
    _updateArenaThemeHazards();
    _updateFiredWeaponHold();
    _updateScheduledComposedEffects();
    _updateCustomDamageOverTime();
    _updateOmegaTendrils();
    _updateLightningStrikes();
    _updateEarthquakesAndTornadoes();
    for (final wave in energyWaves) {
      wave.age++;
    }
    energyWaves.removeWhere((wave) => wave.age >= wave.durationSteps);
    _updateEnergyWaveAttacks();
    _updateFlameCones();
    _countDown();
    _burn();
    _updateFireWallsAndDamageOverTime();
    _updateStickyGoo();
    _triggerMines();
    _triggerPortals();
    _triggerSpikeWalls();
    _triggerStickyGoo();
    _triggerPoisonSwamps();
    _pickUpTouched();
    _strikeWithOrbitingFlails();
    _sweep();
    _updateFrozen();
    _updateStunned();
    _moveProjectiles();
    _reelIn();
    _aimAndFire();
    // The controller counts a step after it ran, so this is the 1-based number of the running step.
    final number = match.stepCount + 1;
    if (automaticSpawning &&
        number >= _t.trapStartSteps &&
        (number - _t.trapStartSteps) % (15 * 60) == 0) {
      _spawnArenaThemeHazard(number);
    }
    if (automaticSpawning &&
        number >= _t.firstSpawnSteps &&
        (number - _t.firstSpawnSteps) % _t.spawnInterval(_ballCount) == 0) {
      _spawn(number);
    }
    _turnShields();
  }

  void _spawnArenaThemeHazard(int number) {
    if (match.arenaDecoration == ArenaDecoration.defaultArena) {
      _spawn(number, forcedKind: PowerUpKind.spikeWall);
      return;
    }
    final kind = switch (match.arenaDecoration) {
      ArenaDecoration.space => ArenaThemeHazardKind.gravityWell,
      ArenaDecoration.desert => ArenaThemeHazardKind.quicksand,
      ArenaDecoration.wilderness => ArenaThemeHazardKind.vineSnare,
      ArenaDecoration.neonGrid => ArenaThemeHazardKind.laserGate,
      ArenaDecoration.defaultArena => throw StateError('Handled above'),
    };
    final angle = rng.nextDoubleRange(0, math.pi * 2);
    final distance = kind == ArenaThemeHazardKind.laserGate
        ? 0.0
        : rng.nextDoubleRange(0.18, 0.62) * match.arenaRadius;
    arenaThemeHazards.add(
      ArenaThemeHazard(
        kind: kind,
        position: Offset(math.cos(angle), math.sin(angle)) * distance,
        spawnStep: number,
        angle: angle,
      ),
    );
    if (arenaThemeHazards.length > 2) arenaThemeHazards.removeAt(0);
  }

  void _updateArenaThemeHazards() {
    final radius = match.arenaRadius * 0.18;
    for (final hazard in arenaThemeHazards.toList()) {
      hazard.age++;
      if (hazard.age >= 10 * 60) {
        arenaThemeHazards.remove(hazard);
        continue;
      }
      for (final ball in match.state.balls) {
        if (!_alive(ball) || ball.isGhost) continue;
        final offset = hazard.position - ball.position;
        switch (hazard.kind) {
          case ArenaThemeHazardKind.gravityWell:
            if (offset.distance < radius * 2.2 && offset.distance > 0) {
              ball.velocity +=
                  offset / offset.distance * match.arenaRadius * 0.012;
            }
          case ArenaThemeHazardKind.quicksand:
            if (offset.distance < radius) {
              ball.velocity *= 0.93;
              if (hazard.age % 60 == 0) {
                _damageArenaHazard(ball, 2, 1, 'Quicksand');
              }
            }
          case ArenaThemeHazardKind.vineSnare:
            if (offset.distance < radius && hazard.affected.add(ball)) {
              _gooVelocity[ball] = ball.velocity;
              ball
                ..stickyGooLeft = 2 * 60
                ..velocity = Offset.zero;
              _yell(ball, 'VINE SNARE!');
            }
          case ArenaThemeHazardKind.laserGate:
            final direction = Offset(
              math.cos(hazard.angle),
              math.sin(hazard.angle),
            );
            final distanceToBeam =
                (ball.position.dx * direction.dy -
                        ball.position.dy * direction.dx)
                    .abs();
            if (distanceToBeam < ball.radius * 0.45) {
              if (hazard.affected.add(ball)) {
                _damageArenaHazard(ball, 8, 3, 'Laser Gate');
                weaponImpacts.add(
                  WeaponImpact(position: ball.position, strength: 0.35),
                );
              }
            } else {
              hazard.affected.remove(ball);
            }
        }
      }
    }
  }

  void _damageArenaHazard(
    SimulationBall ball,
    double arsenalDamage,
    int allOutLines,
    String move,
  ) {
    final lost = match.mode == MatchMode.arsenal
        ? match.damage(ball, arsenalDamage, move: move)
        : match.cutThreads(ball, allOutLines, near: ball.position, move: move);
    _showDamage(ball, ball.position, lost, 0);
  }

  double _vital(SimulationBall ball) => match.mode == MatchMode.arsenal
      ? ball.life
      : ball.fanLines.length.toDouble();

  Iterable<SkillDefinition> _activeComposedSkills(SkillTrigger trigger) sync* {
    for (final kind in PowerUpKind.values) {
      final skill = match.skillLibrary.activeFor(kind, _t);
      if (skill.custom &&
          skill.enabled &&
          skill.isComposed &&
          skill.trigger == trigger) {
        yield skill;
      }
    }
  }

  void _processPassiveTriggers() {
    final number = match.stepCount + 1;
    final timerSkills = _activeComposedSkills(SkillTrigger.timer).toList();
    final damageSkills = _activeComposedSkills(
      SkillTrigger.damageTaken,
    ).toList();
    for (final ball in match.state.balls) {
      final current = _vital(ball);
      final tookDamage = current < (_lastVital[ball] ?? current);
      _lastVital[ball] = current;
      if (!_alive(ball)) continue;
      for (final skill in timerSkills) {
        final interval = (skill.triggerIntervalSeconds * 60).round();
        if (number % interval == 0) _executeComposed(ball, skill);
      }
      if (tookDamage) {
        for (final skill in damageSkills) {
          _executeComposed(ball, skill);
        }
      }
    }
  }

  void onEliminations(
    Iterable<SimulationBall> eliminated,
    Map<SimulationBall, SimulationBall> attackers,
  ) {
    final skills = _activeComposedSkills(SkillTrigger.elimination).toList();
    if (skills.isEmpty) return;
    for (final victim in eliminated) {
      final owner = attackers[victim];
      if (owner == null || !_alive(owner)) continue;
      for (final skill in skills) {
        _executeComposed(owner, skill, primary: victim);
      }
    }
  }

  void _holdFiredWeapon(
    SimulationBall ball,
    PowerUpKind kind, {
    int steps = firedWeaponHoldSteps,
  }) {
    (_firedWeaponHold[ball] ??= {})[kind] = steps;
  }

  void _updateFiredWeaponHold() {
    for (final ballEntry in _firedWeaponHold.entries.toList()) {
      final ball = ballEntry.key;
      final held = ballEntry.value;
      for (final kind in held.keys.toList()) {
        final left = held[kind]! - 1;
        if (left > 0) {
          held[kind] = left;
          continue;
        }
        while (ball.equippedWeapons.contains(kind)) {
          ball.removeWeapon(kind);
        }
        held.remove(kind);
      }
      if (held.isEmpty) _firedWeaponHold.remove(ball);
    }
  }

  /// Gives [ball] the pickup [p] and takes [p] off the field. Power-ups apply
  /// without replacing equipment; a weapon replaces the one equipped weapon.
  void pickUp(SimulationBall ball, FieldPowerUp p) {
    field.remove(p);
    if (!p.kind.isWeapon) _skillSound(p.kind);
    if (p.kind == PowerUpKind.mine || p.kind == PowerUpKind.phaseMine) {
      _sound('trap');
      mines.add(
        ArmedMine(
          owner: ball,
          position: p.position,
          armedStep: match.stepCount,
          kind: p.kind,
        ),
      );
      _yell(
        ball,
        p.kind == PowerUpKind.phaseMine ? 'NOW YOU SEE ME!' : 'MINE SET!',
      );
      return;
    }
    pickups++;
    final activeSkill = match.skillLibrary.activeFor(p.kind, _t);
    if (activeSkill.isComposed && activeSkill.trigger == SkillTrigger.pickup) {
      _executeComposed(ball, activeSkill);
      return;
    }
    if (p.kind.isWeapon) {
      ball.magnetPending = false;
      // A new power-up starts its own aim (a gatling burst already firing finishes first).
      if (ball.burstLeft == 0) {
        ball
          ..aimLeft = 0
          ..aimTarget = null;
      }
    }
    switch (p.kind) {
      case PowerUpKind.apple:
        _eatApple(ball);
        _skillYell(ball, p.kind, 'YUM!');
      case PowerUpKind.speed:
        ball.speedLeft = _t.speedSteps;
        _skillYell(ball, p.kind, 'ZOOM!');
      case PowerUpKind.ghost:
        ball.ghostLeft = _t.ghostSteps;
        _skillYell(ball, p.kind, 'BOO!');
      case PowerUpKind.magnet:
        _pullNearest(ball);
        _skillYell(ball, p.kind, 'MINE!');
      case PowerUpKind.repulsor:
        ball.repulsorLeft = PowerUpTuning.specialEffectSteps;
        _skillYell(ball, p.kind, 'BACK OFF!');
      case PowerUpKind.timeBubble:
        ball.timeBubbleLeft = PowerUpTuning.specialEffectSteps;
        _skillYell(ball, p.kind, 'TIME OUT!');
      case PowerUpKind.vampire:
        ball.vampireLeft = PowerUpTuning.specialEffectSteps;
        _skillYell(ball, p.kind, 'I WANT YOUR POWER!');
      case PowerUpKind.mirror:
        ball.mirrorCharges++;
        _skillYell(ball, p.kind, 'RETURN TO SENDER!');
      case PowerUpKind.overcharge:
        ball.overchargeLeft = PowerUpTuning.specialEffectSteps;
        _skillYell(ball, p.kind, 'MAXIMUM POWER!');
      case PowerUpKind.gremlin:
        final target = _nearestTarget(ball);
        if (target != null) target.gremlinShots++;
        _skillYell(ball, p.kind, 'CHAOS MODE!');
      case PowerUpKind.magneticField:
        ball.magneticFieldLeft = PowerUpTuning.specialEffectSteps;
        ball.magneticReflectedOwners.clear();
        _skillYell(ball, p.kind, 'NOTHING GETS THROUGH!');
      case PowerUpKind.goldenArmor:
        ball.goldenArmorHits = 2;
        _skillYell(ball, p.kind, 'GOLDEN GUARD!');
      case PowerUpKind.omegaTendrils:
        _launchOmegaTendrils(ball);
        _skillYell(ball, p.kind, 'NO ONE ESCAPES!');
      case PowerUpKind.lightningStrikes:
        final target = _nearestTarget(ball);
        if (target != null) {
          lightningStrikes.add(LightningStrike(owner: ball, target: target));
          _skillYell(ball, p.kind, 'THUNDER, STRIKE!');
        }
      case PowerUpKind.earthquake:
        earthquakes.add(EarthquakePulse(owner: ball));
        _skillYell(ball, p.kind, 'SHAKE THE EARTH!');
      case PowerUpKind.tornado:
        final target = _nearestTarget(ball);
        if (target != null) {
          tornadoes.add(
            Tornado(owner: ball, target: target, position: target.position),
          );
          _skillYell(ball, p.kind, 'TWIST AND SHOUT!');
        }
      default:
        ball.equipWeapon(
          p.kind,
          dualWield: match.dualWield,
          twoHanded: _twoHandedOverride(activeSkill),
        );
        // All-Out sword sweep: for a moment the new blade rakes through threads with a wider reach.
        if (p.kind.isBlade && match.mode == MatchMode.allOut) {
          ball.sweepLeft = PowerUpTuning.sweepSteps;
        }
    }
  }

  bool? _twoHandedOverride(SkillDefinition skill) => switch (skill.handedness) {
    SkillHandedness.carrierDefault => null,
    SkillHandedness.oneHanded => false,
    SkillHandedness.twoHanded => true,
  };

  void _launchOmegaTendrils(SimulationBall owner) {
    for (final target in match.state.balls) {
      if (identical(target, owner) || !_alive(target)) continue;
      omegaTendrils.add(
        OmegaTendril(
          owner: owner,
          target: target,
          savedVelocity: target.velocity,
        ),
      );
    }
  }

  void _updateLightningStrikes() {
    for (final strike in lightningStrikes.toList()) {
      if (!_alive(strike.owner) || !_alive(strike.target)) {
        lightningStrikes.remove(strike);
        continue;
      }
      if (strike.flashLeft > 0) strike.flashLeft--;
      if (strike.strikesLeft <= 0) {
        if (strike.flashLeft <= 0) lightningStrikes.remove(strike);
        continue;
      }
      strike.delay--;
      if (strike.delay > 0) continue;
      _hit(
        strike.target,
        PowerUpKind.lightningStrikes,
        at: strike.target.position,
        from: strike.owner,
        unavoidable: true,
      );
      strike.strikesLeft -= 1;
      strike.flashLeft = 8;
      strike.delay = 12;
      _yell(strike.target, 'ZAP!');
    }
  }

  void _updateEarthquakesAndTornadoes() {
    for (final quake in earthquakes.toList()) {
      if (!_alive(quake.owner)) {
        earthquakes.remove(quake);
        continue;
      }
      if (quake.flashLeft > 0) quake.flashLeft--;
      if (quake.pulsesLeft <= 0) {
        if (quake.flashLeft <= 0) earthquakes.remove(quake);
        continue;
      }
      quake.delay--;
      if (quake.delay > 0) continue;
      for (final target in match.state.balls) {
        if (identical(target, quake.owner) || !_alive(target)) continue;
        _hit(
          target,
          PowerUpKind.earthquake,
          at: target.position + Offset(0, target.radius),
          from: quake.owner,
          unavoidable: true,
        );
      }
      quake.pulsesLeft -= 1;
      quake.flashLeft = 10;
      quake.delay = 15;
      blasts++;
    }
    for (final tornado in tornadoes.toList()) {
      tornado.age++;
      if (tornado.age >= PowerUpTuning.molotovBurnSteps ||
          !_alive(tornado.owner)) {
        tornadoes.remove(tornado);
        continue;
      }
      final toward = tornado.target.position - tornado.position;
      if (toward.distance > 0) {
        tornado.position +=
            toward / toward.distance * match.arenaRadius * 0.012;
      }
      for (final ball in match.state.balls) {
        if (identical(ball, tornado.owner) || !_alive(ball) || ball.isGhost) {
          continue;
        }
        final pull = tornado.position - ball.position;
        if (pull.distance > fieldRadius * 3.2 || pull.distance == 0) continue;
        ball.velocity += pull / pull.distance * match.arenaRadius * 0.018;
        _applyDamageOverTime(ball, PowerUpKind.tornado, owner: tornado.owner);
      }
    }
  }

  void _updateOmegaTendrils() {
    for (final tendril in omegaTendrils.toList()) {
      final target = tendril.target;
      if (!_alive(tendril.owner) || !_alive(target)) {
        omegaTendrils.remove(tendril);
        continue;
      }
      target.velocity = Offset.zero;
      tendril.stepsLeft--;
      if (tendril.stepsLeft > 0) continue;

      final away = target.position - tendril.owner.position;
      final direction = away.distance == 0
          ? const Offset(0, 1)
          : away / away.distance;
      target.position += direction * target.radius * 0.55;
      target.velocity =
          direction *
          math.max(tendril.savedVelocity.distance, match.arenaRadius * 0.45) *
          _t.knockback(PowerUpKind.omegaTendrils);
      final lost = match.damage(
        target,
        _t.arenaDamage(PowerUpKind.omegaTendrils),
        attacker: tendril.owner,
        move: skillName(PowerUpKind.omegaTendrils),
      );
      _showDamage(target, target.position, lost, 0);
      target.hurtFlashLeft = MatchSimulationController.hurtFlashSteps;
      match.state.particles.spawnBlood(
        origin: target.position,
        direction: direction,
        color: match.bloodColor,
        rng: rng,
      );
      explosions.add(
        Explosion(position: target.position, radius: target.radius * 1.8),
      );
      blasts++;
      _yell(target, 'SLAMMED!');
      omegaTendrils.remove(tendril);
    }
  }

  void _teleport(SimulationBall ball, Offset entrance) {
    final safeRadius = match.arenaRadius - ball.radius * 1.5;
    var destination = ball.position;
    for (var attempt = 0; attempt < 12; attempt++) {
      final side = rng.nextInt(4);
      final angle = (side + rng.nextDoubleRange(0.18, 0.82)) * math.pi / 2;
      final candidate = Offset(
        math.cos(angle) * safeRadius,
        math.sin(angle) * safeRadius,
      );
      if (match.state.balls.every(
        (other) =>
            identical(other, ball) ||
            other.isEliminated ||
            (other.position - candidate).distance >=
                other.radius + ball.radius * 1.5,
      )) {
        destination = candidate;
        break;
      }
    }
    ball.position = destination;
    portalFlashes.add(PortalFlash(from: entrance, to: destination));
    _sound('warp');
    _yell(ball, 'WARP SPEED!');
  }

  void _triggerPortals() {
    if (portals.isEmpty) return;
    for (final portal in List<ArenaPortal>.of(portals)) {
      for (final ball in match.state.balls) {
        if (!_alive(ball) || ball.isGhost) continue;
        if ((ball.position - portal.position).distance >=
            ball.radius + fieldRadius) {
          continue;
        }
        portals.remove(portal);
        _teleport(ball, portal.position);
        break;
      }
    }
  }

  void _triggerStickyGoo() {
    if (stickyGoo.isEmpty) return;
    for (final goo in List<StickyGoo>.of(stickyGoo)) {
      final blobs = goo.blobPositions(fieldRadius * 0.36);
      for (final ball in match.state.balls) {
        if (!_alive(ball) || ball.isGhost) continue;
        final touches = blobs.any(
          (blob) =>
              (ball.position - blob).distance <
              ball.radius + fieldRadius * 0.48,
        );
        if (!touches) {
          continue;
        }
        stickyGoo.remove(goo);
        _gooVelocity[ball] = ball.velocity;
        ball
          ..stickyGooLeft = PowerUpTuning.stickyGooSteps
          ..velocity = Offset.zero;
        _sound('trap');
        _yell(ball, 'STUCK!');
        break;
      }
    }
  }

  void _triggerPoisonSwamps() {
    for (final swamp in List<PoisonSwamp>.of(poisonSwamps)) {
      final samples = swamp.samplePositions(fieldRadius * 0.36);
      for (final ball in match.state.balls) {
        if (!_alive(ball) || ball.isGhost) continue;
        if (!samples.any(
          (spot) =>
              (ball.position - spot).distance < ball.radius + fieldRadius * 0.5,
        )) {
          continue;
        }
        poisonSwamps.remove(swamp);
        _applyDamageOverTime(ball, PowerUpKind.poisonSwamp);
        _sound('trap');
        _yell(ball, 'POISONED!');
        break;
      }
    }
  }

  void _applyDamageOverTime(
    SimulationBall target,
    PowerUpKind kind, {
    SimulationBall? owner,
  }) {
    for (final effect in damageOverTime) {
      if (identical(effect.target, target) && effect.kind == kind) {
        effect.stepsLeft = math.max(
          effect.stepsLeft,
          PowerUpTuning.damageOverTimeSteps,
        );
        return;
      }
    }
    damageOverTime.add(
      DamageOverTime(
        target: target,
        kind: kind,
        owner: owner,
        stepsLeft: PowerUpTuning.damageOverTimeSteps,
      ),
    );
    if (kind == PowerUpKind.poisonSwamp) {
      target.poisonLeft = PowerUpTuning.damageOverTimeSteps;
    } else if (_isFireDamage(kind)) {
      target.burningLeft = PowerUpTuning.damageOverTimeSteps;
    }
  }

  bool _isFireDamage(PowerUpKind kind) =>
      kind == PowerUpKind.fireWall ||
      kind == PowerUpKind.flamethrower ||
      kind == PowerUpKind.molotov;

  void _updateFireWallsAndDamageOverTime() {
    for (final wall in fireWalls.toList()) {
      wall.age++;
      if (wall.age >= PowerUpTuning.fireWallSteps || !_alive(wall.owner)) {
        fireWalls.remove(wall);
        continue;
      }
      final tangent = Offset.fromDirection(wall.angle);
      for (final ball in match.state.balls) {
        if (identical(ball, wall.owner) || !_alive(ball) || ball.isGhost) {
          continue;
        }
        final near = MathUtils.distancePointToSegmentSquared(
          ball.position,
          wall.center - tangent * fieldRadius * 2.4,
          wall.center + tangent * fieldRadius * 2.4,
        );
        if (near <= math.pow(ball.radius + fieldRadius * 0.38, 2)) {
          _applyDamageOverTime(ball, PowerUpKind.fireWall, owner: wall.owner);
        }
      }
    }
    for (final effect in damageOverTime.toList()) {
      if (!_alive(effect.target)) {
        damageOverTime.remove(effect);
        continue;
      }
      effect.age += 1;
      effect.stepsLeft -= 1;
      if (effect.kind == PowerUpKind.poisonSwamp) {
        effect.target.poisonLeft = effect.stepsLeft;
      } else if (_isFireDamage(effect.kind)) {
        effect.target.burningLeft = effect.stepsLeft;
      }
      if (effect.age % PowerUpTuning.damageOverTimeTickSteps == 1) {
        _hit(
          effect.target,
          effect.kind,
          at: effect.target.position,
          from: effect.owner,
        );
      }
      if (effect.stepsLeft <= 0) damageOverTime.remove(effect);
    }
  }

  void _hitSpikes(SimulationBall ball, Offset at) {
    _sound('trap');
    final inward = ball.position.distance == 0
        ? const Offset(0, 1)
        : -ball.position / ball.position.distance;
    ball.velocity =
        inward * math.max(ball.velocity.distance, match.arenaRadius);
    slashMarks.add(
      SlashMark(
        position: at,
        angle: math.atan2(inward.dy, inward.dx) + math.pi / 2,
      ),
    );
    if (match.mode == MatchMode.arsenal) {
      final damage = match.damage(
        ball,
        _t.arenaDamage(PowerUpKind.spikeWall),
        move: skillName(PowerUpKind.spikeWall),
      );
      _showDamage(ball, at, damage, 0);
    } else {
      final cut = match.cutThreads(
        ball,
        _t.allOutThreads(PowerUpKind.spikeWall),
        near: at,
        move: skillName(PowerUpKind.spikeWall),
      );
      _showDamage(ball, at, cut, 0);
    }
    slashes++;
    _yell(ball, 'OUCH! SPIKES!');
  }

  void _triggerSpikeWalls() {
    if (spikeWalls.isEmpty) return;
    for (final wall in List<SpikeWall>.of(spikeWalls)) {
      final spikes = wall.spikePositions(fieldRadius * 0.96);
      for (final ball in match.state.balls) {
        if (!_alive(ball) || ball.isGhost) continue;
        final reach = ball.radius + fieldRadius * 0.48;
        if (!spikes.any(
          (spike) => (ball.position - spike).distanceSquared <= reach * reach,
        )) {
          continue;
        }
        spikeWalls.remove(wall);
        _hitSpikes(ball, wall.position);
        break;
      }
    }
  }

  /// Melee on a bump between [a] and [b]: a knife hits the other ball and is used up; a shield bashes an
  /// unarmed other ball (one holding nothing) and breaks. Both sides strike with what they held when they
  /// touched, so two knives hit each other. Nothing happens if either is a ghost or already out.
  void onContact(SimulationBall a, SimulationBall b) {
    if (!_alive(a) || !_alive(b) || a.isGhost || b.isGhost) return;
    if (a.repulsorLeft > 0 || b.repulsorLeft > 0) {
      final delta = b.position - a.position;
      final direction = delta.distance == 0
          ? const Offset(1, 0)
          : delta / delta.distance;
      final push = match.arenaRadius * 1.4;
      if (a.repulsorLeft > 0) b.velocity = direction * push;
      if (b.repulsorLeft > 0) a.velocity = -direction * push;
      _yell(a.repulsorLeft > 0 ? a : b, 'BOOM, MOVE!');
    }
    final heldA = [...a.equippedWeapons];
    final heldB = [...b.equippedWeapons];
    for (final weapon in heldA) {
      _melee(a, weapon, b, heldB);
    }
    for (final weapon in heldB) {
      _melee(b, weapon, a, heldA);
    }
  }

  void _melee(
    SimulationBall attacker,
    PowerUpKind weapon,
    SimulationBall target,
    List<PowerUpKind> targetHeld,
  ) {
    final composed = match.skillLibrary.activeFor(weapon, _t);
    if (composed.isComposed && composed.trigger == SkillTrigger.collision) {
      _executeComposed(attacker, composed, primary: target);
      attacker.removeWeapon(weapon);
      return;
    }
    final PowerUpKind kind;
    if (weapon.isBlade || weapon == PowerUpKind.orbitingFlail) {
      kind = weapon;
      _skillSound(kind);
      slashes++;
      _skillYell(
        attacker,
        weapon,
        weapon == PowerUpKind.sword
            ? 'HIYAA!'
            : weapon == PowerUpKind.orbitingFlail
            ? 'WRECKING BALL!'
            : 'SLASH!',
      );
    } else if (weapon == PowerUpKind.shield && targetHeld.isEmpty) {
      kind = PowerUpKind.shield;
      _skillSound(kind);
      _skillYell(attacker, weapon, 'SHIELD BASH!');
    } else {
      return;
    }
    attacker.removeWeapon(weapon);
    final toAttacker = attacker.position - target.position;
    final distance = toAttacker.distance;
    final at = distance > 0
        ? target.position + toAttacker * (target.radius / distance)
        : target.position;
    if (kind.isBlade) {
      // The cut runs across the line between the two balls.
      slashMarks.add(
        SlashMark(
          position: at,
          angle: math.atan2(toAttacker.dy, toAttacker.dx) + math.pi / 2,
        ),
      );
    }
    _hit(target, kind, at: at, from: attacker);
  }

  /// True while [ball] is still in the match: not eliminated, and not already at 0 life (Arsenal) or out
  /// of threads (All-Out) earlier in this step, before the elimination check has marked it.
  bool _alive(SimulationBall ball) =>
      !ball.isEliminated &&
      (match.mode == MatchMode.arsenal
          ? ball.life > 0
          : ball.fanLines.isNotEmpty);

  /// Counts the speed boosts, ghosts and sweeps down, ages blasts; a ball that is out drops its waiting
  /// magnet.
  void _countDown() {
    for (final e in explosions) {
      e.age++;
    }
    explosions.removeWhere((e) => e.age >= PowerUpTuning.explosionShowSteps);
    for (final impact in weaponImpacts) {
      impact.age++;
    }
    weaponImpacts.removeWhere((impact) => impact.age >= 12);
    for (final fire in burningZones) {
      fire.age++;
    }
    burningZones.removeWhere(
      (fire) => fire.age >= PowerUpTuning.molotovBurnSteps,
    );
    for (final flash in portalFlashes) {
      flash.age++;
    }
    portalFlashes.removeWhere(
      (flash) => flash.age >= PowerUpTuning.explosionShowSteps,
    );
    for (final m in slashMarks) {
      m.age++;
    }
    slashMarks.removeWhere((m) => m.age >= PowerUpTuning.slashShowSteps);
    for (final ball in match.state.balls) {
      if (ball.speedLeft > 0) ball.speedLeft--;
      if (ball.ghostLeft > 0) ball.ghostLeft--;
      if (ball.sweepLeft > 0) ball.sweepLeft--;
      if (ball.flailLeft > 0) ball.flailLeft--;
      if (ball.repulsorLeft > 0) ball.repulsorLeft--;
      if (ball.timeBubbleLeft > 0) ball.timeBubbleLeft--;
      if (ball.vampireLeft > 0) ball.vampireLeft--;
      if (ball.overchargeLeft > 0) ball.overchargeLeft--;
      if (ball.magneticFieldLeft > 0) {
        ball.magneticFieldLeft--;
        if (ball.magneticFieldLeft == 0) {
          ball.magneticReflectedOwners.clear();
        }
      }
      if (!_alive(ball)) ball.magnetPending = false;
    }
  }

  void _ignite(Offset at, SimulationBall owner) {
    final radius = match.arenaRadius * _t.blastRadiusRatio;
    blasts++;
    burningZones.add(BurningZone(owner: owner, position: at, radius: radius));
    match.state.floatingTexts.spawn(at, 'BURN!', const Color(0xFFFF7A2F));
  }

  void _burn() {
    for (final fire in burningZones) {
      if (fire.age % PowerUpTuning.molotovTickSteps != 0) continue;
      for (final ball in match.state.balls) {
        if (identical(ball, fire.owner) || !_alive(ball) || ball.isGhost) {
          continue;
        }
        if ((ball.position - fire.position).distance - ball.radius <=
            fire.radius) {
          ball.burningLeft = math.max(ball.burningLeft, 45);
          _hit(ball, PowerUpKind.molotov, at: ball.position, from: fire.owner);
        }
      }
    }
  }

  /// Arsenal: heals [_t.arenaAppleHeal], on top of full life up to [_t.arenaMaxLife].
  /// All-Out: claims up to
  /// [_t.allOutAppleSlots] free rim slots with the "+N LINES" pop (none when none are free).
  /// Either way a green sparkle bursts from the ball.
  void _eatApple(SimulationBall ball) {
    if (match.mode == MatchMode.arsenal) {
      ball.life = math.min(_t.arenaMaxLife, ball.life + _t.arenaAppleHeal);
    } else {
      final claimed = match.claimFreeSlots(ball, _t.allOutAppleSlots);
      if (claimed > 0) {
        match.state.floatingTexts.spawn(
          ball.position,
          '+$claimed LINES',
          ball.config.primaryColor,
        );
      }
    }
    match.state.particles.spawnSparkle(origin: ball.position, rng: rng);
  }

  /// The magnet pulls the nearest field power-up straight onto [ball] (it is picked up next step as
  /// usual). With the field empty, the next one to spawn is pulled instead.
  void _pullNearest(SimulationBall ball) {
    FieldPowerUp? nearest;
    var best = double.infinity;
    for (final p in field) {
      final distance = (p.position - ball.position).distanceSquared;
      if (distance < best) {
        nearest = p;
        best = distance;
      }
    }
    if (nearest == null) {
      ball.magnetPending = true;
    } else {
      nearest.position = ball.position;
    }
  }

  /// An armed mine goes off as soon as a ball other than its owner touches it (a ghost passes over it).
  /// A mine whose owner is out is gone.
  void _triggerMines() {
    if (mines.isEmpty) return;
    final balls = match.state.balls;
    for (final mine in List.of(mines)) {
      if (!_alive(mine.owner)) {
        mines.remove(mine);
        continue;
      }
      final touched = balls.any(
        (b) =>
            !identical(b, mine.owner) &&
            _alive(b) &&
            !b.isGhost &&
            (b.position - mine.position).distance < b.radius + fieldRadius,
      );
      if (!touched) continue;
      mines.remove(mine);
      _explode(mine.position, mine.owner, mine.kind);
    }
  }

  /// A blast at [at] (a mine or a grenade): hits every ball but [owner] whose body is within
  /// [_t.blastRadiusRatio] arena radii (ghosts are spared), as [kind]. In All-Out it also cuts
  /// every thread passing through it, from every ball but the owner and ghosts.
  void _explode(Offset at, SimulationBall owner, PowerUpKind kind) {
    final radius = match.arenaRadius * _t.blastRadiusRatio;
    final balls = match.state.balls;
    blasts++;
    explosions.add(Explosion(position: at, radius: radius, kind: kind));
    match.state.floatingTexts.spawn(at, 'KABOOM!', _blastColor);
    if (match.mode == MatchMode.allOut) {
      for (final ball in balls) {
        if (identical(ball, owner) || !_alive(ball) || ball.isGhost) continue;
        for (final line in List.of(ball.fanLines)) {
          if (MathUtils.distancePointToSegmentSquared(
                at,
                line.startPoint,
                ball.position,
              ) <=
              radius * radius) {
            _cutLine(ball, line, move: skillName(kind), attacker: owner);
          }
        }
      }
    }
    for (final ball in balls) {
      if (identical(ball, owner) || !_alive(ball)) continue;
      final offset = ball.position - at;
      final distance = offset.distance;
      if (distance - ball.radius > radius) continue;
      // The side of the ball facing the blast, so the splash flies away from it.
      final side = distance > ball.radius
          ? at + offset * ((distance - ball.radius) / distance)
          : at;
      _hit(ball, kind, at: side);
    }
  }

  /// Turns every held shield toward its biggest threat: the nearest enemy projectile coming at it, else
  /// the nearest opponent. Only shows where it braces; a shield blocks from every side.
  void _turnShields() {
    for (final ball in match.state.balls) {
      if (!ball.equippedWeapons.contains(PowerUpKind.shield) || !_alive(ball)) {
        continue;
      }
      final threat =
          _incoming(ball)?.position ?? _nearestTarget(ball)?.position;
      if (threat == null) continue;
      final toThreat = threat - ball.position;
      final want = math.atan2(toThreat.dy, toThreat.dx);
      final turn = _wrap(
        want - ball.shieldAngle,
      ).clamp(-_shieldTurnPerStep, _shieldTurnPerStep);
      ball.shieldAngle = _wrap(ball.shieldAngle + turn);
    }
  }

  /// The nearest projectile not fired by [ball] that is still moving toward it, or null.
  Projectile? _incoming(SimulationBall ball) {
    Projectile? best;
    var bestDistance = double.infinity;
    for (final p in projectiles) {
      if (p.spent || identical(p.owner, ball)) continue;
      final toBall = ball.position - p.position;
      if (toBall.dx * p.velocity.dx + toBall.dy * p.velocity.dy <= 0) continue;
      final distance = toBall.distanceSquared;
      if (distance < bestDistance) {
        best = p;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// [angle] wrapped into -pi..pi.
  static double _wrap(double angle) =>
      (angle + math.pi) % (2 * math.pi) - math.pi;

  void _pickUpTouched() {
    if (field.isEmpty) return;
    final radius = fieldRadius;
    for (final ball in match.state.balls) {
      if (!_alive(ball)) continue;
      // At most one per step, so a second one in reach is not used up unseen. The index is found first,
      // so [field] is never changed while it is being walked.
      final index = field.indexWhere(
        (p) => (p.position - ball.position).distance < ball.radius + radius,
      );
      if (index >= 0) pickUp(ball, field[index]);
    }
  }

  /// Spawns one of the chosen kinds at a random spot in the emptiest quadrant of the arena (the one with
  /// the fewest power-ups and armed mines, a seeded pick among ties), away from the rim and the center
  /// and clear of balls and other power-ups. Skipped when 10 tries find no clear spot.
  void _spawn(int number, {PowerUpKind? forcedKind}) {
    // Uniform over the chosen kinds; with all of them chosen this draws exactly as with none chosen.
    final chosen = match.powerUpKinds;
    final kinds = chosen == null || chosen.length == PowerUpKind.values.length
        ? PowerUpKind.values
        : [
            for (final k in PowerUpKind.values)
              if (chosen.contains(k) || k.isTrap) k,
          ];
    final timedKinds = number < _t.trapStartSteps
        ? kinds.where((kind) => !kind.isTrap).toList()
        : kinds;
    final claimedKinds = {for (final pickup in field) pickup.kind};
    final eligibleKinds = timedKinds
        .where((kind) => kind.isTrap || !claimedKinds.contains(kind))
        .toList();
    if (eligibleKinds.isEmpty && forcedKind == null) return;
    final kind =
        forcedKind ?? PowerUpSpawnSelector.choose(eligibleKinds, _t, rng);
    final radius = fieldRadius;
    final balls = match.state.balls;
    final taken = List.filled(4, 0);
    for (final f in field) {
      taken[quadrantOf(f.position)]++;
    }
    for (final b in mines) {
      taken[quadrantOf(b.position)]++;
    }
    for (final wall in spikeWalls) {
      taken[quadrantOf(wall.position)]++;
    }
    for (final portal in portals) {
      taken[quadrantOf(portal.position)]++;
    }
    for (final goo in stickyGoo) {
      taken[quadrantOf(goo.position)]++;
    }
    for (final swamp in poisonSwamps) {
      taken[quadrantOf(swamp.position)]++;
    }
    final fewest = taken.reduce(math.min);
    final open = [
      for (var q = 0; q < 4; q++)
        if (taken[q] == fewest) q,
    ];
    final quadrant = open[rng.nextInt(open.length)];
    final inner = match.arenaRadius * PowerUpTuning.spawnMinDistance;
    final outer = match.arenaRadius * PowerUpTuning.spawnMaxDistance;
    for (var attempt = 0; attempt < 10; attempt++) {
      final angle = (quadrant + rng.nextDoubleRange(0.1, 0.9)) * math.pi / 2;
      final distance =
          kind == PowerUpKind.spikeWall ||
              kind == PowerUpKind.stickyGoo ||
              kind == PowerUpKind.poisonSwamp ||
              kind == PowerUpKind.portal
          ? match.arenaRadius - radius * 0.38
          : kind.isTrap
          ? match.arenaRadius - radius * 1.6
          : math.sqrt(rng.nextDoubleRange(inner * inner, outer * outer));
      final spot = Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance,
      );
      final clear =
          balls.every(
            (b) =>
                b.isEliminated ||
                (b.position - spot).distance >= b.radius + radius,
          ) &&
          field.every((f) => (f.position - spot).distance >= 2 * radius) &&
          mines.every((b) => (b.position - spot).distance >= 2 * radius) &&
          spikeWalls.every(
            (wall) => (wall.position - spot).distance >= 4 * radius,
          ) &&
          portals.every(
            (portal) => (portal.position - spot).distance >= 2 * radius,
          ) &&
          stickyGoo.every(
            (goo) => (goo.position - spot).distance >= 2 * radius,
          ) &&
          poisonSwamps.every(
            (swamp) => (swamp.position - spot).distance >= 2 * radius,
          );
      if (!clear) continue;
      if (kind == PowerUpKind.portal) {
        portals.add(ArenaPortal(position: spot, spawnStep: number));
        if (portals.length > PowerUpTuning.maxOnField(_ballCount)) {
          portals.removeAt(0);
        }
        return;
      }
      if (kind == PowerUpKind.spikeWall) {
        spikeWalls.add(
          SpikeWall(position: spot, angle: angle, spawnStep: number),
        );
        if (spikeWalls.length > PowerUpTuning.maxOnField(_ballCount)) {
          spikeWalls.removeAt(0);
        }
        return;
      }
      if (kind == PowerUpKind.stickyGoo) {
        stickyGoo.add(StickyGoo(position: spot, spawnStep: number));
        if (stickyGoo.length > PowerUpTuning.maxOnField(_ballCount)) {
          stickyGoo.removeAt(0);
        }
        return;
      }
      if (kind == PowerUpKind.poisonSwamp) {
        poisonSwamps.add(PoisonSwamp(position: spot, spawnStep: number));
        if (poisonSwamps.length > PowerUpTuning.maxOnField(_ballCount)) {
          poisonSwamps.removeAt(0);
        }
        return;
      }
      final spawned = FieldPowerUp(
        kind: kind,
        position: spot,
        spawnStep: number,
      );
      field.add(spawned);
      if (field.length > PowerUpTuning.maxOnField(_ballCount)) {
        field.removeAt(0);
      }
      // A waiting magnet pulls it straight in.
      for (final ball in balls) {
        if (!ball.magnetPending || !_alive(ball)) continue;
        ball.magnetPending = false;
        spawned.position = ball.position;
        break;
      }
      return;
    }
  }

  /// The quadrant (0-3, counted from the positive x axis toward positive y) that [position] lies in.
  static int quadrantOf(Offset position) {
    final angle = math.atan2(position.dy, position.dx) % (2 * math.pi);
    return (angle / (math.pi / 2)).floor().clamp(0, 3);
  }

  /// Counts frozen balls down: they stay still and get their old speed back when the freeze runs out. A
  /// bump while frozen still counts: the ball leaves in the direction it was knocked.
  void _updateFrozen() {
    for (final ball in match.state.balls) {
      if (ball.frozenLeft <= 0) continue;
      final knocked = ball.velocity;
      final old = _frozenVelocity[ball];
      if (old != null && knocked != Offset.zero) {
        _frozenVelocity[ball] = knocked * (old.distance / knocked.distance);
      }
      ball.frozenLeft--;
      if (ball.frozenLeft == 0) {
        ball.velocity = _frozenVelocity.remove(ball) ?? ball.velocity;
      } else {
        ball.velocity = Offset.zero;
      }
    }
  }

  void _updateStickyGoo() {
    for (final ball in match.state.balls) {
      if (ball.stickyGooLeft <= 0) continue;
      ball.stickyGooLeft--;
      if (ball.stickyGooLeft == 0) {
        ball.velocity = _gooVelocity.remove(ball) ?? ball.velocity;
      } else {
        ball.velocity = Offset.zero;
      }
    }
  }

  void _updateStunned() {
    for (final ball in match.state.balls) {
      if (ball.stunnedLeft <= 0) continue;
      ball.stunnedLeft--;
      if (ball.stunnedLeft == 0) {
        ball.velocity = _stunnedVelocity.remove(ball) ?? ball.velocity;
      } else {
        ball.velocity = Offset.zero;
      }
    }
  }

  /// The nearest opponent of [ball] a gun can aim at (still in the match, not a ghost), or null.
  SimulationBall? _nearestTarget(SimulationBall ball) {
    SimulationBall? best;
    var bestDistance = double.infinity;
    for (final other in match.state.balls) {
      if (identical(other, ball) || !_alive(other) || other.isGhost) continue;
      final distance = (other.position - ball.position).distanceSquared;
      if (distance < bestDistance) {
        best = other;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _launchComposed(
    SimulationBall owner,
    SimulationBall target,
    SkillDefinition skill,
  ) {
    if (skill.delivery == SkillDelivery.projectile) {
      final delta = target.position - owner.position;
      final direction = delta.distance == 0
          ? const Offset(1, 0)
          : delta / delta.distance;
      final shot = Projectile(
        owner: owner,
        kind: skill.baseKind,
        position: owner.position + direction * owner.radius,
        velocity:
            direction *
            match.arenaRadius *
            (skill.projectileSpeed ?? _t.bulletSpeedRatio),
      );
      projectiles.add(shot);
      _composedProjectiles[shot] = skill;
      shots++;
      _skillSound(skill.baseKind);
      if (skill.yell.isNotEmpty) _skillYell(owner, skill.baseKind, skill.yell);
      return;
    }
    _executeComposed(owner, skill, primary: target);
  }

  void _executeComposed(
    SimulationBall owner,
    SkillDefinition skill, {
    SimulationBall? primary,
  }) {
    final cooldownKey = (owner, skill.id);
    if ((_composedCooldownUntil[cooldownKey] ?? 0) > match.stepCount) return;
    final targets = switch (skill.targeting) {
      SkillTargeting.self => [owner],
      SkillTargeting.nearestOpponent => [
        ?primary != null && _alive(primary) ? primary : _nearestTarget(owner),
      ],
      SkillTargeting.allOpponents => [
        for (final target in match.state.balls)
          if (!identical(target, owner) && _alive(target)) target,
      ],
      null => const <SimulationBall>[],
    };
    if (targets.isEmpty) return;
    if (skill.cooldownSeconds > 0) {
      _composedCooldownUntil[cooldownKey] =
          match.stepCount + (skill.cooldownSeconds * 60).round();
    }
    if (skill.startDelaySeconds > 0) {
      _scheduledComposedEffects.add(
        _ScheduledComposedEffect(
          owner: owner,
          targets: List.unmodifiable(targets),
          skill: skill,
          repeatsLeft: skill.repeatCount,
          stepsLeft: (skill.startDelaySeconds * 60).round(),
          announceOnNext: true,
        ),
      );
      return;
    }
    _applyComposedEffects(owner, targets, skill);
    if (skill.repeatCount > 1) {
      _scheduledComposedEffects.add(
        _ScheduledComposedEffect(
          owner: owner,
          targets: List.unmodifiable(targets),
          skill: skill,
          repeatsLeft: skill.repeatCount - 1,
          stepsLeft: (skill.repeatIntervalSeconds * 60).round(),
        ),
      );
    }
    _skillSound(skill.baseKind);
    if (skill.yell.isNotEmpty) _skillYell(owner, skill.baseKind, skill.yell);
  }

  void _applyComposedEffects(
    SimulationBall owner,
    Iterable<SimulationBall> targets,
    SkillDefinition skill,
  ) {
    for (final target in targets) {
      if (!_alive(target)) continue;
      _applyComposedEffect(owner, target, skill, skill.effectType);
      if (skill.secondaryEffectType != null) {
        _applyComposedEffect(owner, target, skill, skill.secondaryEffectType);
      }
      match.state.particles.spawnImpact(
        origin: target.position,
        rng: rng,
        color: Color(skill.effectColor),
        accent: const Color(0xFFFFFFFF),
        count: 7 + (skill.screenShake * 10).round(),
      );
      if (skill.screenShake > 0) {
        weaponImpacts.add(
          WeaponImpact(position: target.position, strength: skill.screenShake),
        );
      }
    }
  }

  void _updateScheduledComposedEffects() {
    for (final scheduled in _scheduledComposedEffects.toList()) {
      scheduled.stepsLeft--;
      if (scheduled.stepsLeft > 0) continue;
      _applyComposedEffects(
        scheduled.owner,
        scheduled.targets,
        scheduled.skill,
      );
      if (scheduled.announceOnNext) {
        _skillSound(scheduled.skill.baseKind);
        if (scheduled.skill.yell.isNotEmpty) {
          _skillYell(
            scheduled.owner,
            scheduled.skill.baseKind,
            scheduled.skill.yell,
          );
        }
        scheduled.announceOnNext = false;
      }
      scheduled.repeatsLeft--;
      if (scheduled.repeatsLeft <= 0 || !_alive(scheduled.owner)) {
        _scheduledComposedEffects.remove(scheduled);
      } else {
        scheduled.stepsLeft = (scheduled.skill.repeatIntervalSeconds * 60)
            .round();
      }
    }
  }

  void _updateCustomDamageOverTime() {
    for (final effect in _customDamageOverTime.toList()) {
      if (!_alive(effect.owner) || !_alive(effect.target)) {
        _customDamageOverTime.remove(effect);
        continue;
      }
      effect.stepsLeft--;
      effect.stepsUntilTick--;
      if (effect.stepsUntilTick <= 0) {
        _applyComposedEffect(
          effect.owner,
          effect.target,
          effect.skill,
          SkillEffectType.damage,
        );
        effect.stepsUntilTick = (effect.skill.tickIntervalSeconds * 60).round();
      }
      if (effect.stepsLeft <= 0) _customDamageOverTime.remove(effect);
    }
  }

  void _applyComposedEffect(
    SimulationBall owner,
    SimulationBall target,
    SkillDefinition skill,
    SkillEffectType? effect,
  ) {
    switch (effect) {
      case SkillEffectType.damage:
        if (match.mode == MatchMode.arsenal) {
          final dealt = match.damage(
            target,
            skill.arsenalDamage ?? 0,
            move: skill.name,
            attacker: owner,
          );
          _showDamage(target, target.position, dealt, 0);
        } else {
          final cut = match.cutThreads(
            target,
            skill.allOutDamage ?? 0,
            near: target.position,
            move: skill.name,
            attacker: owner,
          );
          _showDamage(target, target.position, cut, 0);
        }
      case SkillEffectType.damageOverTime:
        _customDamageOverTime.add(
          _CustomDamageOverTime(
            owner: owner,
            target: target,
            skill: skill,
            stepsLeft: ((skill.durationSeconds ?? 2) * 60).round(),
            stepsUntilTick: (skill.tickIntervalSeconds * 60).round(),
          ),
        );
      case SkillEffectType.heal:
        if (match.mode == MatchMode.arsenal) {
          target.life = math.min(
            _t.arenaMaxLife,
            target.life + (skill.arsenalDamage ?? 10),
          );
        }
      case SkillEffectType.shield:
        target.goldenArmorHits = math.max(
          target.goldenArmorHits,
          skill.projectileCount ?? 1,
        );
      case SkillEffectType.freeze:
        if (target.frozenLeft == 0) _frozenVelocity[target] = target.velocity;
        target.frozenLeft = ((skill.durationSeconds ?? 2) * 60).round();
        target.velocity = Offset.zero;
      case SkillEffectType.stun:
        if (target.stunnedLeft == 0) {
          _stunnedVelocity[target] = target.velocity;
        }
        target.stunnedLeft = ((skill.durationSeconds ?? 2) * 60).round();
        target.velocity = Offset.zero;
      case SkillEffectType.speed:
        target.speedLeft = ((skill.durationSeconds ?? 2) * 60).round();
      case SkillEffectType.pull:
        final toward = owner.position - target.position;
        if (toward.distance > 0) {
          target.velocity =
              toward / toward.distance * match.arenaRadius * skill.knockback;
        }
      case SkillEffectType.knockback:
        final away = target.position - owner.position;
        if (away.distance > 0) {
          target.velocity =
              away / away.distance * match.arenaRadius * skill.knockback;
        }
      case SkillEffectType.teleport:
        _teleport(target, target.position);
      case SkillEffectType.equipCarrier:
        if (skill.baseKind.isWeapon) {
          target.equipWeapon(
            skill.baseKind,
            dualWield: match.dualWield,
            twoHanded: _twoHandedOverride(skill),
          );
        }
      case SkillEffectType.disarm:
        target
          ..held = null
          ..heldSecondary = null
          ..heldTwoHanded = false
          ..heldSecondaryTwoHanded = false;
      case null:
    }
  }

  /// Guns aim at the nearest opponent for [_t.aimSteps] steps, then fire. A gatling then
  /// fires its other rounds one every [PowerUpTuning.gatlingIntervalSteps] steps. Balls that are out
  /// (or lost their last life or thread earlier this step) or frozen neither aim nor fire (bullets
  /// already in flight still fly).
  void _strikeWithOrbitingFlails() {
    for (final attacker in match.state.balls) {
      if (!_alive(attacker) ||
          !attacker.equippedWeapons.contains(PowerUpKind.orbitingFlail)) {
        continue;
      }
      for (final target in match.state.balls) {
        if (identical(attacker, target) || !_alive(target) || target.isGhost) {
          continue;
        }
        final reach = attacker.radius * 2.7 + target.radius;
        if ((target.position - attacker.position).distance <= reach) {
          _melee(attacker, PowerUpKind.orbitingFlail, target, [
            ...target.equippedWeapons,
          ]);
          break;
        }
      }
    }
  }

  void _aimAndFire() {
    for (final ball in match.state.balls) {
      if (!_alive(ball)) {
        ball
          ..aimLeft = 0
          ..aimTarget = null
          ..burstLeft = 0;
        continue;
      }
      // A frozen ball can't shoot; a ghost is purely defensive, so it holds its aim until it's solid.
      if (ball.frozenLeft > 0 ||
          ball.stunnedLeft > 0 ||
          ball.stickyGooLeft > 0 ||
          ball.isGhost) {
        continue;
      }
      final bursting = ball.burstLeft > 0;
      final guns = ball.equippedWeapons.where((weapon) {
        final skill = match.skillLibrary.activeFor(weapon, _t);
        final canAim = skill.isComposed
            ? skill.trigger == SkillTrigger.aimedFire
            : weapon.isGun;
        return canAim &&
            (weapon != PowerUpKind.energyWave || energyWaveAttacks.isEmpty) &&
            !(_firedWeaponHold[ball]?.containsKey(weapon) ?? false);
      }).toList();
      if (!bursting && guns.isEmpty) continue;
      final target = _nearestTarget(ball);
      ball.aimTarget = target;
      if (target == null) {
        // Nobody to aim at: a new aim starts over once someone is.
        if (!bursting) ball.aimLeft = 0;
        continue;
      }
      if (!bursting && ball.aimLeft == 0) ball.aimLeft = _t.aimSteps;
      ball.aimLeft--;
      if (ball.aimLeft > 0) continue;

      if (bursting) {
        _holdFiredWeapon(ball, PowerUpKind.gatling);
        _fire(
          ball,
          target,
          PowerUpKind.gatling,
          0,
          volley: _burstVolley[ball] ?? 0,
        );
        gatlingShots++;
        ball.burstLeft--;
      } else {
        for (final kind in guns) {
          _holdFiredWeapon(ball, kind);
          final composed = match.skillLibrary.activeFor(kind, _t);
          if (composed.isComposed &&
              composed.trigger == SkillTrigger.aimedFire) {
            _launchComposed(ball, target, composed);
            continue;
          }
          switch (kind) {
            case PowerUpKind.shotgun:
              _fireShotgun(ball, target);
              _skillYell(ball, kind, 'BLAM!');
            case PowerUpKind.gatling:
              _burstVolley[ball] = ++_lastVolley;
              _fire(ball, target, kind, 0, volley: _lastVolley);
              gatlingShots++;
              ball.burstLeft = _t.gatlingRounds - 1;
              _skillYell(ball, kind, 'RATATAT!');
            case PowerUpKind.freeze:
              _fire(ball, target, kind, 0);
              _skillYell(ball, kind, 'FREEZE!');
            case PowerUpKind.grenade:
              _throwGrenade(ball, target);
              _skillYell(ball, kind, 'FIRE IN THE HOLE!');
            case PowerUpKind.molotov:
              _throwMolotov(ball, target);
              _skillYell(ball, kind, 'LIGHT IT UP!');
            case PowerUpKind.hook:
              _fire(
                ball,
                target,
                kind,
                0,
                speedRatio: PowerUpTuning.hookSpeedRatio,
              );
              _skillYell(ball, kind, 'COME OVER HERE!');
            case PowerUpKind.ricochetDisc:
              _fire(ball, target, kind, 0);
              _skillYell(ball, kind, 'BANK SHOT!');
            case PowerUpKind.threadHarpoon:
              _fire(ball, target, kind, 0);
              _skillYell(ball, kind, 'GIVE IT HERE!');
            case PowerUpKind.prismLaser:
              _fire(ball, target, kind, 0);
              _skillYell(ball, kind, 'TASTE THE RAINBOW!');
            case PowerUpKind.swapCannon:
              _fire(ball, target, kind, 0);
              _skillYell(ball, kind, 'SWAP INCOMING!');
            case PowerUpKind.bow:
              _fireBow(ball, target);
              _skillYell(ball, kind, 'ARROWS, FLY!');
            case PowerUpKind.rocketLauncher:
              _fireRocket(ball, target);
              _skillYell(ball, kind, 'TARGET LOCKED!');
            case PowerUpKind.boomerang:
              _fire(ball, target, kind, 0, speedRatio: 0.72);
              _skillYell(ball, kind, 'COMING BACK!');
            case PowerUpKind.fireWall:
              _raiseFireWall(ball, target);
              _skillYell(ball, kind, 'BURNING BARRIER!');
            case PowerUpKind.waterGun:
              _fire(ball, target, kind, 0, speedRatio: 1.55);
              _skillYell(ball, kind, 'SPLASH!');
            case PowerUpKind.energyWave:
              _fireEnergyWave(ball, target);
              _skillYell(ball, kind, 'KA-ME-HA-ME-HAAA!');
            case PowerUpKind.flamethrower:
              _startFlamethrower(ball, target);
              _skillYell(ball, kind, 'BURN IT DOWN!');
            default:
              _fire(ball, target, kind, 0);
              _skillYell(ball, kind, 'BANG!');
          }
        }
      }
      if (ball.burstLeft > 0) {
        ball.aimLeft = PowerUpTuning.gatlingIntervalSteps;
      } else {
        ball.aimTarget = null;
      }
    }
  }

  /// A hook caught [target]: a held shield blocks it (and breaks); otherwise [owner] yells and starts
  /// reeling it in. A ball already on a hook isn't caught again.
  void _catch(SimulationBall owner, SimulationBall target) {
    if (!_alive(owner) || !_alive(target) || target.isGhost) return;
    if (target.equippedWeapons.contains(PowerUpKind.shield)) {
      target.removeWeapon(PowerUpKind.shield);
      blocks++;
      _yell(target, 'BLOCKED!');
      return;
    }
    if (pulls.any(
      (h) => identical(h.target, target) || identical(h.target, owner),
    )) {
      return;
    }
    hits++;
    _yell(owner, 'COME OVER HERE!');
    pulls.add(
      HookPull(
        owner: owner,
        target: target,
        speed: target.velocity.distance,
        stepsLeft: PowerUpTuning.hookMaxPullSteps,
      ),
    );
    target.velocity = Offset.zero;
  }

  /// Hooked balls move straight toward their owner. Once they touch (or the reel-in runs out) the owner
  /// uppercuts: a hook hit (damage or lines, through [_hit]), then the target is thrown in a seeded random
  /// direction at its old speed, with a short speed burst. A pull ends early when either ball is out or
  /// the target turns ghost.
  void _reelIn() {
    if (pulls.isEmpty) return;
    final pull =
        match.arenaRadius *
        PowerUpTuning.hookPullRatio *
        MatchSimulationController.fixedTimestep;
    for (final h in List.of(pulls)) {
      final owner = h.owner;
      final target = h.target;
      if (!_alive(owner) || !_alive(target) || target.isGhost) {
        pulls.remove(h);
        continue;
      }
      final toOwner = owner.position - target.position;
      final gap = toOwner.distance - owner.radius - target.radius;
      h.stepsLeft--;
      if (gap > 2 && h.stepsLeft > 0) {
        target
          ..position += toOwner / toOwner.distance * math.min(pull, gap - 1)
          ..velocity = Offset.zero;
        continue;
      }
      pulls.remove(h);
      final distance = toOwner.distance;
      final at = distance > 0
          ? target.position + toOwner * (target.radius / distance)
          : target.position;
      _yell(owner, 'UPPERCUT!');
      slashMarks.add(SlashMark(position: at, angle: -math.pi / 2));
      _hit(target, PowerUpKind.hook, at: at, from: owner);
      final angle = rng.nextDoubleRange(0, 2 * math.pi);
      final speed = h.speed > 0 ? h.speed : match.arenaRadius * 0.5;
      target
        ..velocity = Offset(math.cos(angle), math.sin(angle)) * speed
        ..speedLeft = math.max(target.speedLeft, PowerUpTuning.hookThrowSteps);
    }
  }

  /// Fans [_t.shotgunPellets] pellets evenly over [PowerUpTuning.shotgunSpread]. The inner
  /// pellets get a seeded jitter of up to [_pelletJitter]; the two outer ones mark the fan's edges.
  void _fireShotgun(SimulationBall ball, SimulationBall target) {
    final count = _t.shotgunPellets;
    final spread = _t.shotgunSpreadRadians;
    final volley = ++_lastVolley;
    final sabotaged = _consumeGremlin(ball);
    for (var i = 0; i < count; i++) {
      final edge = i == 0 || i == count - 1;
      final jitter = edge
          ? 0.0
          : rng.nextDoubleRange(-_pelletJitter, _pelletJitter);
      _fire(
        ball,
        target,
        PowerUpKind.shotgun,
        -spread / 2 + spread * i / (count - 1) + jitter,
        volley: volley,
        sabotaged: sabotaged,
      );
    }
  }

  void _fireBow(SimulationBall ball, SimulationBall target) {
    final count = _t.bowArrows;
    final spread = PowerUpTuning.bowSpread(
      (target.position - ball.position).distance,
      match.arenaRadius,
    );
    final volley = ++_lastVolley;
    final sabotaged = _consumeGremlin(ball);
    for (var i = 0; i < count; i++) {
      _fire(
        ball,
        target,
        PowerUpKind.bow,
        -spread / 2 + spread * i / (count - 1),
        volley: volley,
        sabotaged: sabotaged,
      );
    }
  }

  /// Throws a grenade from [ball]'s edge at where [target] is now; it explodes on the first opponent it
  /// meets or where it lands.
  void _throwGrenade(SimulationBall ball, SimulationBall target) {
    final toTarget = target.position - ball.position;
    final distance = toTarget.distance;
    var direction = distance == 0 ? const Offset(1, 0) : toTarget / distance;
    if (_consumeGremlin(ball)) direction = -direction;
    projectiles.add(
      Projectile(
        owner: ball,
        kind: PowerUpKind.grenade,
        position: ball.position + direction * ball.radius,
        velocity: direction * (match.arenaRadius * _t.grenadeSpeedRatio),
        landAt: ball.position + direction * distance,
      ),
    );
    _skillSound(PowerUpKind.grenade);
    shots++;
  }

  void _throwMolotov(SimulationBall ball, SimulationBall target) {
    final toTarget = target.position - ball.position;
    final distance = toTarget.distance;
    var direction = distance == 0 ? const Offset(1, 0) : toTarget / distance;
    if (_consumeGremlin(ball)) direction = -direction;
    projectiles.add(
      Projectile(
        owner: ball,
        kind: PowerUpKind.molotov,
        position: ball.position + direction * ball.radius,
        velocity: direction * (match.arenaRadius * _t.grenadeSpeedRatio),
        landAt: ball.position + direction * distance,
      ),
    );
    shots++;
  }

  void _fireRocket(SimulationBall ball, SimulationBall target) {
    final toTarget = target.position - ball.position;
    final distance = toTarget.distance;
    var direction = distance == 0 ? const Offset(1, 0) : toTarget / distance;
    final sabotaged = _consumeGremlin(ball);
    if (sabotaged) direction = -direction;
    projectiles.add(
      Projectile(
        owner: ball,
        kind: PowerUpKind.rocketLauncher,
        position: ball.position + direction * ball.radius,
        velocity: direction * (match.arenaRadius * _t.bulletSpeedRatio * 0.72),
        target: target,
        homing: !sabotaged,
      ),
    );
    shots++;
  }

  void _raiseFireWall(SimulationBall ball, SimulationBall target) {
    final toward = target.position - ball.position;
    final shotAngle = math.atan2(toward.dy, toward.dx);
    fireWalls.add(
      FireWall(
        owner: ball,
        center: target.position,
        angle: shotAngle + math.pi / 2,
      ),
    );
    shots++;
  }

  void _fireEnergyWave(SimulationBall ball, SimulationBall target) {
    final targets =
        match.state.balls
            .where((other) => !identical(other, ball) && _alive(other))
            .toList()
          ..sort((a, b) {
            final aa = math.atan2(
              a.position.dy - ball.position.dy,
              a.position.dx - ball.position.dx,
            );
            final ba = math.atan2(
              b.position.dy - ball.position.dy,
              b.position.dx - ball.position.dx,
            );
            return aa.compareTo(ba);
          });
    if (targets.isEmpty) return;
    final toward = target.position - ball.position;
    final direction = toward.distance == 0
        ? const Offset(1, 0)
        : toward / toward.distance;
    energyWaveAttacks.add(
      EnergyWaveAttack(owner: ball, targets: targets, direction: direction),
    );
    final total =
        EnergyWaveAttack.chargeSteps + EnergyWaveAttack.beamSteps + 12;
    _holdFiredWeapon(ball, PowerUpKind.energyWave, steps: total);
    shots++;
  }

  void _updateEnergyWaveAttacks() {
    for (final attack in energyWaveAttacks.toList()) {
      if (!_alive(attack.owner)) {
        _releaseEnergyWave(attack, launchAway: false);
        continue;
      }
      attack.age++;
      attack.owner.position = attack.savedOwnerPosition;
      attack.owner.velocity = Offset.zero;
      for (final target in attack.targets) {
        if (_alive(target)) {
          target.position = attack.savedPositions[target] ?? target.position;
          target.velocity = Offset.zero;
        }
      }
      if (attack.age < EnergyWaveAttack.chargeSteps) continue;

      if (!attack.fired) {
        attack.fired = true;
        final start =
            attack.owner.position + attack.direction * attack.owner.radius;
        final end = start + attack.direction * match.arenaRadius * 2.4;
        energyWaves.add(
          EnergyWave(
            owner: attack.owner,
            start: start,
            end: end,
            sweepStartAngle: attack.startAngle,
            sweepEndAngle: attack.endAngle,
          ),
        );
      }

      // Damage each target once, when the rotating beam reaches its bearing.
      final progress = EnergyWaveAttack.sweepProgress(
        attack.age - EnergyWaveAttack.chargeSteps,
      );
      final startAngle = attack.startAngle;
      for (final target in attack.targets) {
        if (!_alive(target) || attack.hitTargets.contains(target)) continue;
        final delta = target.position - attack.owner.position;
        final bearing =
            (math.atan2(delta.dy, delta.dx) - startAngle) % (2 * math.pi);
        if (bearing >
            progress * (attack.endAngle - attack.startAngle) + 0.000001) {
          continue;
        }
        attack.hitTargets.add(target);
        weaponImpacts.add(WeaponImpact(position: target.position, strength: 1));
        _hit(
          target,
          PowerUpKind.energyWave,
          at: target.position,
          from: attack.owner,
          unavoidable: true,
          scaleForCrowd: false,
        );
        _yell(target, 'BLASTED!');
      }

      final finishedAt =
          EnergyWaveAttack.chargeSteps + EnergyWaveAttack.beamSteps;
      if (attack.age < finishedAt) continue;
      _releaseEnergyWave(attack, launchAway: true);
    }
  }

  void _releaseEnergyWave(EnergyWaveAttack attack, {required bool launchAway}) {
    if (_alive(attack.owner)) {
      attack.owner.position = attack.savedOwnerPosition;
      attack.owner.velocity = attack.savedOwnerVelocity;
    }
    for (final target in attack.targets) {
      if (!_alive(target)) continue;
      final saved = attack.savedVelocities[target] ?? Offset.zero;
      if (!launchAway) {
        target.velocity = saved;
        continue;
      }
      final away = target.position - attack.owner.position;
      target.velocity = away.distance == 0
          ? saved
          : away /
                away.distance *
                math.max(saved.distance, match.arenaRadius * 0.42) *
                _t.knockback(PowerUpKind.energyWave);
    }
    energyWaveAttacks.remove(attack);
  }

  void _startFlamethrower(SimulationBall ball, SimulationBall target) {
    final toward = target.position - ball.position;
    flameCones.add(
      FlameCone(owner: ball, angle: math.atan2(toward.dy, toward.dx)),
    );
    _holdFiredWeapon(
      ball,
      PowerUpKind.flamethrower,
      steps: PowerUpTuning.flamethrowerSteps,
    );
    shots++;
  }

  void _updateFlameCones() {
    for (final cone in flameCones.toList()) {
      cone.age++;
      if (cone.age >= PowerUpTuning.flamethrowerSteps || !_alive(cone.owner)) {
        flameCones.remove(cone);
        continue;
      }
      if (cone.age % PowerUpTuning.flamethrowerTickSteps != 1) continue;
      for (final target in match.state.balls) {
        if (identical(target, cone.owner) ||
            !_alive(target) ||
            target.isGhost) {
          continue;
        }
        final offset = target.position - cone.owner.position;
        if (offset.distance > match.arenaRadius * 0.78 + target.radius) {
          continue;
        }
        final angle = math.atan2(offset.dy, offset.dx);
        if (_wrap(angle - cone.angle).abs() > 0.48) continue;
        _applyDamageOverTime(
          target,
          PowerUpKind.flamethrower,
          owner: cone.owner,
        );
      }
    }
  }

  /// Fires one projectile from [ball]'s edge toward [target], turned by [turn] radians.
  void _fire(
    SimulationBall ball,
    SimulationBall target,
    PowerUpKind kind,
    double turn, {
    int volley = 0,
    double? speedRatio,
    bool? sabotaged,
  }) {
    final toTarget = target.position - ball.position;
    final firesBackward = sabotaged ?? _consumeGremlin(ball);
    final angle =
        math.atan2(toTarget.dy, toTarget.dx) +
        turn +
        (firesBackward ? math.pi : 0);
    final direction = Offset(math.cos(angle), math.sin(angle));
    projectiles.add(
      Projectile(
        owner: ball,
        kind: kind,
        position: ball.position + direction * ball.radius,
        velocity:
            direction *
            (match.arenaRadius * (speedRatio ?? _t.projectileSpeedRatio(kind))),
        volley: volley,
        returnTo: kind == PowerUpKind.boomerang ? ball.position : null,
      ),
    );
    _skillSound(kind);
    shots++;
  }

  /// Moves every projectile one step. A projectile strikes the first ball (not its owner, not out, not a
  /// ghost) its path enters and is spent, or is spent at the rim. In All-Out it also cuts the opponent
  /// threads its path crosses on the way.
  void _moveProjectiles() {
    if (projectiles.isEmpty) return;
    final balls = match.state.balls;
    final allOut = match.mode == MatchMode.allOut;
    final spawned = <Projectile>[];
    for (final p in projectiles) {
      if (p.spent) continue;
      final from = p.position;
      if (p.kind == PowerUpKind.rocketLauncher && p.homing) {
        var target = p.target;
        if (target == null || !_alive(target)) {
          target = _nearestTarget(p.owner);
          p.target = target;
        }
        if (target != null) {
          final toward = target.position - from;
          if (toward.distance > 0) {
            p.velocity =
                toward /
                toward.distance *
                (match.arenaRadius * _t.bulletSpeedRatio * 0.72);
          }
        }
      }
      if (p.kind == PowerUpKind.boomerang && p.returning) {
        final returnSpot = p.returnTo ?? p.owner.position;
        final home = returnSpot - from;
        if (home.distance <= p.owner.radius * 1.15) {
          p.position = returnSpot;
          p.spent = true;
          continue;
        }
        p.velocity = home / home.distance * (match.arenaRadius * 0.72);
      }
      var projectileScale = 1.0;
      for (final ball in balls) {
        if (ball.timeBubbleLeft > 0 &&
            !identical(ball, p.owner) &&
            (from - ball.position).distance < ball.radius * 3) {
          projectileScale = 0.35;
        }
      }
      final to =
          from +
          p.velocity *
              MatchSimulationController.fixedTimestep *
              projectileScale;

      SimulationBall? struck;
      var strikeAt = double.infinity;
      for (final ball in balls) {
        if (identical(ball, p.owner) ||
            ball.isEliminated ||
            ball.isGhost ||
            (p.kind == PowerUpKind.boomerang && p.hitTargets.contains(ball))) {
          continue;
        }
        final t = _entry(
          from,
          to,
          ball.position,
          ball.magneticFieldLeft > 0 &&
                  !ball.magneticReflectedOwners.contains(p.owner)
              ? ball.radius * 2
              : ball.radius,
        );
        if (t != null && t < strikeAt) {
          struck = ball;
          strikeAt = t;
        }
      }
      var end = struck == null ? to : Offset.lerp(from, to, strikeAt)!;
      final landAt = p.landAt;
      if (landAt != null) {
        // A thrown explosive resolves on a ball, its target, or the rim.
        final left = (landAt - from).distance;
        final landed = struck == null && (to - from).distance >= left;
        if (landed) end = landAt;
        if (struck != null || landed || end.distance >= match.arenaRadius) {
          p
            ..position = end
            ..spent = true;
          if (p.kind == PowerUpKind.molotov) {
            _ignite(end, p.owner);
          } else {
            _explode(end, p.owner, PowerUpKind.grenade);
          }
        } else {
          p.position = end;
        }
        continue;
      }

      // A hook's chain doesn't cut threads.
      if (allOut &&
          p.kind != PowerUpKind.hook &&
          !_composedProjectiles.containsKey(p)) {
        for (final ball in balls) {
          if (identical(ball, p.owner) || ball.isEliminated || ball.isGhost) {
            continue;
          }
          for (final line in List.of(ball.fanLines)) {
            // Rim anchors are unique, so the thread nearest a thread's own anchor is that thread.
            if (_crosses(from, end, line.startPoint, ball.position)) {
              _cutLine(ball, line, move: skillName(p.kind), attacker: p.owner);
            }
          }
        }
      }

      p.position = end;
      if (struck != null) {
        if (struck.magneticFieldLeft > 0 &&
            struck.magneticReflectedOwners.contains(p.owner)) {
          p.spent = true;
          continue;
        }
        if (struck.magneticFieldLeft > 0 || struck.mirrorCharges > 0) {
          final normal = end - struck.position;
          final unit = normal.distance == 0
              ? const Offset(1, 0)
              : normal / normal.distance;
          final along = p.velocity.dx * unit.dx + p.velocity.dy * unit.dy;
          p.velocity = p.velocity - unit * (2 * along);
          p.position += unit * 2;
          if (struck.mirrorCharges > 0 && struck.magneticFieldLeft == 0) {
            struck.mirrorCharges--;
          }
          if (struck.magneticFieldLeft > 0) {
            struck.magneticReflectedOwners.add(p.owner);
          }
          p.owner = struck;
          _yell(struck, 'RETURN TO SENDER!');
          continue;
        }
        p.spent = p.kind != PowerUpKind.boomerang;
        if (p.kind == PowerUpKind.hook) {
          _catch(p.owner, struck);
        } else {
          final composed = _composedProjectiles.remove(p);
          if (composed != null) {
            _executeComposed(p.owner, composed, primary: struck);
          } else {
            _hit(struck, p.kind, at: end, from: p.owner, volley: p.volley);
          }
          if (p.kind == PowerUpKind.boomerang) {
            p.hitTargets.add(struck);
            p.position += p.velocity / p.velocity.distance * 2;
          }
          if (p.kind == PowerUpKind.rocketLauncher) {
            explosions.add(
              Explosion(
                position: end,
                radius: match.arenaRadius * PowerUpTuning.blastRadiusRatio,
                kind: PowerUpKind.rocketLauncher,
              ),
            );
          }
        }
      } else if (end.distance >= match.arenaRadius &&
          p.kind != PowerUpKind.rocketLauncher) {
        if (p.kind == PowerUpKind.boomerang) {
          p
            ..position = end / end.distance * (match.arenaRadius - 2)
            ..returning = true;
        } else if ((p.kind == PowerUpKind.ricochetDisc ||
                p.kind == PowerUpKind.prismLaser) &&
            p.wallBounces < _t.maxBounces(p.kind)) {
          final normal = end.distance == 0
              ? const Offset(1, 0)
              : end / end.distance;
          final along = p.velocity.dx * normal.dx + p.velocity.dy * normal.dy;
          p
            ..position = normal * (match.arenaRadius - 2)
            ..velocity -= normal * (2 * along);
          p.wallBounces++;
          if (p.kind == PowerUpKind.prismLaser) {
            for (final turn in [-0.32, 0.32]) {
              final angle = math.atan2(p.velocity.dy, p.velocity.dx) + turn;
              spawned.add(
                Projectile(
                  owner: p.owner,
                  kind: PowerUpKind.prismLaser,
                  position: p.position,
                  velocity:
                      Offset(math.cos(angle), math.sin(angle)) *
                      p.velocity.distance,
                )..wallBounces = 1,
              );
            }
            _yell(p.owner, 'SPLIT THE LIGHT!');
          }
        } else {
          p.spent = true;
        }
      }
    }
    projectiles.addAll(spawned);
    _composedProjectiles.removeWhere((projectile, _) => projectile.spent);
    projectiles.removeWhere((p) => p.spent);
  }

  bool _consumeGremlin(SimulationBall ball) {
    if (ball.gremlinShots <= 0) return false;
    ball.gremlinShots--;
    return true;
  }

  /// Every weapon hit lands here (bullets, pellets, freeze shots, knife, shield bash, bomb). A ghost can't
  /// be hit at all. A held shield absorbs part of the hit, then breaks: [_t.shieldBlock] of it
  /// in Arsenal, while in All-Out only [_t.allOutShieldKeep] of the threads are lost. Arsenal
  /// takes life off [target], All-Out snaps its threads nearest the impact point [at]; both splash "blood"
  /// in the target's color. A freeze shot instead stops the target for [_t.freezeSteps] steps
  /// (shortened the same way by a shield). [kind] [PowerUpKind.shield] is a shield bash. [from] is the
  /// attacker (null for a bomb: the splash then flies away from [at]).
  void _hit(
    SimulationBall target,
    PowerUpKind kind, {
    Offset? at,
    SimulationBall? from,
    int volley = 0,
    bool unavoidable = false,
    bool scaleForCrowd = true,
  }) {
    if (target.isGhost && !unavoidable) return;
    if (target.magneticFieldLeft > 0 && !unavoidable) {
      _sound('repel');
      _yell(target, 'REPELLED!');
      return;
    }
    hits++;
    target.hurtFlashLeft = MatchSimulationController.hurtFlashSteps;
    final impact = at ?? target.position;
    final (impactColor, impactAccent) = _impactColors(kind);
    match.state.particles.spawnImpact(
      origin: impact,
      rng: rng,
      color: impactColor,
      accent: impactAccent,
      count: 7 + (kind.impactWeight * 10).round(),
    );
    weaponImpacts.add(
      WeaponImpact(position: impact, strength: kind.impactWeight),
    );
    var share = 1.0;
    final shielded = match.mode == MatchMode.arsenal
        ? 1 - _t.shieldBlock
        : _t.allOutShieldKeep;
    if (target.equippedWeapons.contains(PowerUpKind.shield)) {
      target.removeWeapon(PowerUpKind.shield);
      blocks++;
      _yell(target, 'BLOCKED!');
      share = shielded;
      // One attack is the whole volley: its other shots are blocked the same way.
      if (volley != 0) _shieldedVolley[target] = volley;
    } else if (volley != 0 && _shieldedVolley[target] == volley) {
      share = shielded;
    }
    if (kind == PowerUpKind.freeze) {
      _sound('freeze');
      final steps = (_t.freezeSteps * share).round();
      if (steps > target.frozenLeft) {
        if (target.frozenLeft == 0) _frozenVelocity[target] = target.velocity;
        target.frozenLeft = steps;
      }
      if (target.frozenLeft > 0) target.velocity = Offset.zero;
      return;
    }
    if (kind == PowerUpKind.swapCannon && from != null) {
      final oldPosition = from.position;
      final oldVelocity = from.velocity;
      from
        ..position = target.position
        ..velocity = target.velocity;
      target
        ..position = oldPosition
        ..velocity = oldVelocity;
      portalFlashes.add(PortalFlash(from: oldPosition, to: from.position));
      _sound('warp');
      _yell(from, 'SWITCHEROO!');
      _yell(target, 'SWAPPED!');
    }
    final bash = kind == PowerUpKind.shield;
    if (match.mode == MatchMode.arsenal) {
      final power = (from?.overchargeLeft ?? 0) > 0 ? 1.5 : 1.0;
      final lost = match.damage(
        target,
        (bash ? _t.arenaShieldBash : _t.arenaDamage(kind)) * share * power,
        attacker: from,
        move: skillName(kind),
        scaleForCrowd: scaleForCrowd,
      );
      if (from != null &&
          (from.vampireLeft > 0 || kind == PowerUpKind.threadHarpoon)) {
        from.life = math.min(_t.arenaMaxLife, from.life + lost * 0.5);
        _yell(from, 'MINE NOW!');
      }
      _showDamage(target, impact, lost, volley);
    } else {
      // Thread snap: the threads nearest the impact break, each with its rim spark.
      final threads =
          ((bash ? _t.allOutShieldBash : _t.allOutThreads(kind)) * share)
              .round();
      final nearest = [...target.fanLines]
        ..sort(
          (x, y) => (x.startPoint - impact).distanceSquared.compareTo(
            (y.startPoint - impact).distanceSquared,
          ),
        );
      var cut = 0;
      for (final line in nearest.take(threads)) {
        if (_cutLine(target, line, move: skillName(kind), attacker: from)) {
          cut++;
        }
      }
      if (from != null &&
          (from.vampireLeft > 0 || kind == PowerUpKind.threadHarpoon)) {
        match.claimFreeSlots(from, math.max(1, cut ~/ 2));
        _yell(from, 'MINE NOW!');
      }
      _showDamage(target, impact, cut, volley);
    }
    match.state.particles.spawnBlood(
      origin: impact,
      direction: target.position - (from?.position ?? impact),
      color: match.bloodColor,
      rng: rng,
    );
  }

  (Color, Color) _impactColors(PowerUpKind kind) => switch (kind) {
    PowerUpKind.freeze => (const Color(0xFF79E8FF), const Color(0xFFFFFFFF)),
    PowerUpKind.molotov => (const Color(0xFFFF5A1F), const Color(0xFFFFD43B)),
    PowerUpKind.rocketLauncher ||
    PowerUpKind.grenade => (const Color(0xFFFF7A3D), const Color(0xFFFFFFFF)),
    PowerUpKind.omegaTendrils => (
      const Color(0xFFE21D35),
      const Color(0xFFFF6578),
    ),
    PowerUpKind.boomerang || PowerUpKind.ricochetDisc => (
      const Color(0xFF20DDF2),
      const Color(0xFFFFFFFF),
    ),
    PowerUpKind.prismLaser => (
      const Color(0xFFFF4FD8),
      const Color(0xFF5BE7FF),
    ),
    PowerUpKind.fireWall || PowerUpKind.flamethrower => (
      const Color(0xFFFF5A1F),
      const Color(0xFFFFD43B),
    ),
    PowerUpKind.poisonSwamp => (
      const Color(0xFF78A92B),
      const Color(0xFFCAFF54),
    ),
    PowerUpKind.waterGun => (const Color(0xFF39BFFF), const Color(0xFFD7FAFF)),
    PowerUpKind.lightningStrikes => (
      const Color(0xFF70D7FF),
      const Color(0xFFFFFF66),
    ),
    PowerUpKind.knife ||
    PowerUpKind.sword => (const Color(0xFFDCE5EC), const Color(0xFFFFD43B)),
    _ => (const Color(0xFFFFFFFF), const Color(0xFFFFD43B)),
  };

  /// All-Out sword sweep: while [SimulationBall.sweepLeft] runs, a ball cuts every opponent thread that
  /// passes within [PowerUpTuning.sweepReach] times its radius (wider than its body). Ghosts on either side
  /// are left alone: a ghost cuts nothing and its threads can't be cut.
  void _sweep() {
    if (match.mode != MatchMode.allOut) return;
    final balls = match.state.balls;
    for (final cutter in balls) {
      if (cutter.sweepLeft == 0 || !_alive(cutter) || cutter.isGhost) continue;
      final reach = cutter.radius * PowerUpTuning.sweepReach;
      for (final target in balls) {
        if (identical(target, cutter) || !_alive(target) || target.isGhost) {
          continue;
        }
        for (final line in List.of(target.fanLines)) {
          if (MathUtils.distancePointToSegmentSquared(
                cutter.position,
                line.startPoint,
                target.position,
              ) <=
              reach * reach) {
            _cutLine(
              target,
              line,
              move: skillName(PowerUpKind.sword),
              attacker: cutter,
            );
          }
        }
      }
    }
  }

  /// A floating "-N" (Arsenal life) or "-N LINES" (All-Out) at [at]. Hits of one volley on the same ball
  /// add up in a single label while it still shows.
  void _showDamage(SimulationBall target, Offset at, num amount, int volley) {
    if (amount <= 0) return;
    String label(num total) => match.mode == MatchMode.arsenal
        ? '-${total.round()}'
        : '-$total ${total == 1 ? 'LINE' : 'LINES'}';
    final last = _volleyLabel[target];
    if (volley != 0 &&
        last != null &&
        last.$1 == volley &&
        !last.$2.isExpired) {
      final total = last.$3 + amount;
      last.$2.text = label(total);
      _volleyLabel[target] = (volley, last.$2, total);
      return;
    }
    final text = match.state.floatingTexts.spawn(
      at,
      label(amount),
      _damageColor,
    );
    _volleyLabel[target] = (volley, text, amount);
  }

  /// [ball] yells [text] (a floating label just above it, in its color).
  void _yell(
    SimulationBall ball,
    String text, {
    CalloutStyle calloutStyle = CalloutStyle.normal,
    CalloutBubble calloutBubble = CalloutBubble.shout,
  }) {
    match.state.floatingTexts.spawn(
      ball.position - Offset(0, ball.radius * 1.4),
      text,
      ball.config.primaryColor,
      callout: true,
      calloutStyle: calloutStyle,
      calloutBubble: calloutBubble,
    );
  }

  /// Cuts [line] of [ball] (rim anchors are unique, so the thread nearest its own anchor is that thread)
  /// with a spark leaving the rim, like a body cut. False if it was already gone.
  bool _cutLine(
    SimulationBall ball,
    FanLine line, {
    String? move,
    SimulationBall? attacker,
  }) {
    if (match.cutThreads(
          ball,
          1,
          near: line.startPoint,
          move: move,
          attacker: attacker,
        ) ==
        0) {
      return false;
    }
    match.state.particles.spawnRimArcs(
      origin: line.startPoint,
      normal: Offset(math.cos(line.rimAngle), math.sin(line.rimAngle)),
      arenaRadius: match.arenaRadius,
      rng: rng,
    );
    return true;
  }

  /// Where along the segment [from]-[to] (0..1) it first comes closer than [radius] to [center], or null
  /// if it never does.
  static double? _entry(Offset from, Offset to, Offset center, double radius) {
    final f = from - center;
    final c = f.distanceSquared - radius * radius;
    if (c < 0) return 0;
    final d = to - from;
    final a = d.distanceSquared;
    if (a == 0) return null;
    final b = 2 * (f.dx * d.dx + f.dy * d.dy);
    final disc = b * b - 4 * a * c;
    if (disc < 0) return null;
    final t = (-b - math.sqrt(disc)) / (2 * a);
    return t >= 0 && t <= 1 ? t : null;
  }

  /// True when the segments [p1]-[p2] and [q1]-[q2] properly cross.
  static bool _crosses(Offset p1, Offset p2, Offset q1, Offset q2) {
    double side(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    return side(q1, q2, p1) * side(q1, q2, p2) < 0 &&
        side(p1, p2, q1) * side(p1, p2, q2) < 0;
  }
}

class _ScheduledComposedEffect {
  _ScheduledComposedEffect({
    required this.owner,
    required this.targets,
    required this.skill,
    required this.repeatsLeft,
    required this.stepsLeft,
    this.announceOnNext = false,
  });

  final SimulationBall owner;
  final List<SimulationBall> targets;
  final SkillDefinition skill;
  int repeatsLeft;
  int stepsLeft;
  bool announceOnNext;
}

class _CustomDamageOverTime {
  _CustomDamageOverTime({
    required this.owner,
    required this.target,
    required this.skill,
    required this.stepsLeft,
    required this.stepsUntilTick,
  });

  final SimulationBall owner;
  final SimulationBall target;
  final SkillDefinition skill;
  int stepsLeft;
  int stepsUntilTick;
}
