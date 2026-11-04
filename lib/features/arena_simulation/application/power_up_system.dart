import '../../skills/domain/native_advanced_skill_config.dart';
import '../../skills/domain/skill_projectile_budget.dart';
import '../../../core/sprites/facing_offset.dart';
import 'power_up_spawn_selector.dart';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/utils/math_utils.dart';
import '../../../core/utils/seeded_random.dart';
import '../../match_setup/domain/match_config.dart';
import '../../skills/domain/skill_library.dart';
import '../../skills/domain/skill_hybrid_contact_policy.dart';
import '../../skills/domain/skill_trigger_scheduler.dart';
import '../../skills/domain/skill_activation_gate.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/combat_targeting.dart';
import '../domain/fan_line.dart';
import '../domain/arena_boundary_geometry.dart';
import '../domain/floating_text.dart';
import '../domain/power_up.dart';
import '../domain/power_up_config.dart';
import '../domain/simulation_ball.dart';
import 'match_simulation_controller.dart';

part 'persistent_skill_effects.dart';

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
  static const int maxScheduledCustomEffects = 64;
  static const int maxCustomDamageOverTimeEffects = 64;
  static const int maxComposedProjectiles = 96;
  static const int maxMayhemAllOpponentRepeats = 5;
  static const int maxShellCasings = 80;

  /// Safety limit for projectiles trapped in endless bounce/return cycles.
  /// At 60 simulation steps per second this permits two minutes of flight,
  /// well beyond ordinary weapon range, without leaking live projectile state.
  static const int maxProjectileFlightSteps = 7200;

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

  // Retained aimed targets are per-match state and are discarded on respawn.
  final Map<SimulationBall, SimulationBall> _aimedTargets = {};
  int targetSwitchCount = 0;
  int homingRetargetCount = 0;
  int blockedTargetFallbackCount = 0;
  int projectileSweepCount = 0;
  int projectileContactCount = 0;
  int projectileCenterWallBounceCount = 0;

  /// Read-only counters for combat debugging and regression diagnostics.
  Map<String, int> get targetingDiagnostics => Map.unmodifiable({
    'targetSwitches': targetSwitchCount,
    'homingRetargets': homingRetargetCount,
    'blockedTargetFallbacks': blockedTargetFallbackCount,
    'projectileSweeps': projectileSweepCount,
    'projectileContacts': projectileContactCount,
    'projectileCenterWallBounces': projectileCenterWallBounceCount,
  });
  final List<ShellCasing> shellCasings = [];

  /// Casings ejected so far this match ([ShellCasing.sequence]).
  int _shellSequence = 0;
  final Map<Projectile, SkillDefinition> _composedProjectiles = {};

  /// Shots fired by one skill as another skill's projectile ([SkillDefinition.payloadSkillId]): the skill
  /// that fired them, credited for their hits (the winning move and its finisher name it).
  final Map<Projectile, SkillDefinition> _composedIssuers = {};

  /// While a payload shot lands: its firing definition, retained through delayed damage as well.
  SkillDefinition? _creditSkill;

  /// The definition a composed shot carries (its own skill, or the skill it was fired as), or null for a
  /// built-in shot.
  SkillDefinition? projectileSkill(Projectile p) => _composedProjectiles[p];
  double projectileCollisionRadius(Projectile p) {
    final skill = _composedProjectiles[p];
    return p.owner.radius *
        (skill != null && skill.effectSteps.isNotEmpty
            ? skill.projectileHitRadius
            : .15 * p.renderScale);
  }

  /// The skill that fired [p] as another skill's projectile, or null.
  SkillDefinition? projectileIssuer(Projectile p) => _composedIssuers[p];
  final List<_ScheduledComposedEffect> _scheduledComposedEffects = [];
  final List<_CustomDamageOverTime> _customDamageOverTime = [];
  final List<_ScheduledEffectStep> _effectStepQueue = [];
  static const maxScheduledEffectSteps = 256;
  int compositionLimitHits = 0;
  final Map<(SimulationBall, String), int> _composedCooldownUntil = {};
  final Map<SimulationBall, double> _lastVital = {};
  // Per-owner passive trigger state. The effect executor remains responsible
  // for start delays, repeats and effect-step scheduling.
  final Map<(SimulationBall, String), SkillTriggerScheduler>
  _passiveSchedulers = {};

  SkillTriggerScheduler _passiveScheduler(
    SimulationBall owner,
    SkillDefinition skill,
  ) => _passiveSchedulers.putIfAbsent(
    (owner, skill.id),
    () => SkillTriggerScheduler(
      skill.copyWith(startDelaySeconds: 0, repeatCount: 1, cooldownSeconds: 0),
    ),
  );

  bool _passiveTriggered(
    SimulationBall owner,
    SkillDefinition skill,
    SkillTrigger event,
    double time,
  ) {
    final scheduler = _passiveScheduler(owner, skill);
    // A rejected activation already owns a retry slot. Do not enqueue
    // another damage event every frame while draining that retry.
    if (event != SkillTrigger.timer &&
        scheduler.pendingCount == 0 &&
        !scheduler.signal(event, time)) {
      return false;
    }
    return scheduler.advance(time).isNotEmpty;
  }

  int get activeCustomEffectCount =>
      _composedProjectiles.length +
      _scheduledComposedEffects.length +
      _customDamageOverTime.length +
      _effectStepQueue.length;

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
  // Distinguishes skill goo from automatic arena vine snares.
  final Set<SimulationBall> _skillGooVictims = {};
  // Vine snares are automatic arena hazards, independent of skill goo.
  final Set<SimulationBall> _vineSnareVictims = {};
  final Map<SimulationBall, int> _skillGooRemaining = {};
  final Map<SimulationBall, int> _vineSnareRemaining = {};
  final List<PoisonSwamp> poisonSwamps = [];
  final List<FireWall> fireWalls = [];
  final List<DamageOverTime> damageOverTime = [];
  final List<LightningStrike> lightningStrikes = [];
  final List<EarthquakePulse> earthquakes = [];
  final List<Tornado> tornadoes = [];
  final List<EnergyWave> energyWaves = [];
  final List<EnergyWaveAttack> energyWaveAttacks = [];
  final List<FlameCone> flameCones = [];
  final List<SniperFlash> sniperFlashes = [];
  final List<OmnislashAttack> omnislashAttacks = [];
  final List<RagingDemonAttack> ragingDemonAttacks = [];
  final List<ShadowCloneAttack> shadowCloneAttacks = [];
  final List<CastingArtwork> castingArtwork = [];
  final List<MuzzleArtwork> muzzleArtwork = [];
  late final persistentEffects = PersistentSkillEffects(this);
  final Map<Object, int> _cinematicFreezes = {};
  final Map<SimulationBall, int> _otherStuns = {};
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
  int _visualSteps(
    PowerUpKind? kind,
    String? skillId,
    SkillVisualRole role,
    int fallback,
  ) {
    if (match.skillLibrary.effects.isEmpty) return fallback;
    if (kind == null) return fallback;
    final skill = visualSkill(kind, skillId: skillId);
    if (!skill.visualBindings.containsKey(role)) return fallback;
    final duration = match.skillLibrary
        .resolveVisual(skill, role)
        ?.durationSeconds;
    return duration == null ? fallback : (duration * 60).round().clamp(1, 600);
  }

  // Cache a hit's visual lifetime on first use. The painter and countdown
  // must agree on the same duration even if the library is edited mid-effect.
  // Expando keys are the effect instances, so expired hits are not retained.
  final Expando<int> _impactVisualLifetime = Expando<int>('impactLifetime');
  final Expando<int> _explosionVisualLifetime = Expando<int>(
    'explosionLifetime',
  );
  final Expando<ResolvedSkillEffect> _impactVisualSnapshot =
      Expando<ResolvedSkillEffect>('impactVisual');
  final Expando<ResolvedSkillEffect> _explosionVisualSnapshot =
      Expando<ResolvedSkillEffect>('explosionVisual');

  // Normal combat events are snapshotted when created. External/replay/test
  // events can enter the lists directly, so resolve their artwork lazily once
  // rather than silently falling back to unrelated legacy animations.
  ResolvedSkillEffect? impactVisual(WeaponImpact impact) =>
      _impactVisualSnapshot[impact] ??= _snapshotVisual(
        impact.kind,
        impact.skillId,
        SkillVisualRole.impact,
      );
  ResolvedSkillEffect? explosionVisual(Explosion explosion) =>
      _explosionVisualSnapshot[explosion] ??= _snapshotVisual(
        explosion.kind,
        explosion.skillId,
        SkillVisualRole.explosion,
      );

  ResolvedSkillEffect? _snapshotVisual(
    PowerUpKind? kind,
    String? skillId,
    SkillVisualRole role,
  ) {
    if (kind == null) return null;
    final skill = visualSkill(kind, skillId: skillId);
    // Capture legacy-only artwork too. A skill does not need a Visual Events
    // binding to have a resolved Casting/Impact/Explosion sprite. Without this
    // snapshot, a legacy hit can change artwork halfway through playback when
    // the library is edited, unlike a migrated hit.
    return match.skillLibrary.resolveVisual(skill, role);
  }

  int impactVisualSteps(WeaponImpact impact) =>
      _impactVisualLifetime[impact] ??= _visualSteps(
        impact.kind,
        impact.skillId,
        SkillVisualRole.impact,
        12,
      );
  int explosionVisualSteps(Explosion explosion) =>
      _explosionVisualLifetime[explosion] ??= _visualSteps(
        explosion.kind,
        explosion.skillId,
        SkillVisualRole.explosion,
        PowerUpTuning.explosionShowSteps,
      );

  // Snapshot event lifetime when gameplay creates the effect, not at the
  // first paint/tick. This also protects the first frame if an editor changes
  // the skill library between effect creation and the next simulation step.
  void _recordWeaponImpact(WeaponImpact impact) {
    impactVisualSteps(impact);
    _impactVisualSnapshot[impact] = _snapshotVisual(
      impact.kind,
      impact.skillId,
      SkillVisualRole.impact,
    );
    weaponImpacts.add(impact);
  }

  void _recordExplosion(Explosion explosion) {
    explosionVisualSteps(explosion);
    _explosionVisualSnapshot[explosion] = _snapshotVisual(
      explosion.kind,
      explosion.skillId,
      SkillVisualRole.explosion,
    );
    explosions.add(explosion);
  }

  void _startCastingArtwork(SimulationBall ball, SkillDefinition skill) {
    final visual = match.skillLibrary.resolveVisual(
      skill,
      SkillVisualRole.casting,
    );
    if (visual == null) return;
    bool Function()? follow<T>(
      List<T> moves,
      SimulationBall Function(T) ownerOf,
    ) {
      final activation = moves
          .where((move) => identical(ownerOf(move), ball))
          .toList();
      return activation.isEmpty ? null : () => activation.any(moves.contains);
    }

    final active = !skill.castingFollowsActive || skill.isComposed
        ? null
        : switch (skill.baseKind) {
            PowerUpKind.energyWave => follow(energyWaveAttacks, (a) => a.owner),
            PowerUpKind.flamethrower => follow(flameCones, (a) => a.owner),
            PowerUpKind.tornado => follow(tornadoes, (a) => a.owner),
            PowerUpKind.omegaTendrils => follow(omegaTendrils, (a) => a.owner),
            PowerUpKind.lightningStrikes => follow(
              lightningStrikes,
              (a) => a.owner,
            ),
            PowerUpKind.earthquake => follow(earthquakes, (a) => a.owner),
            PowerUpKind.shadowClone => follow(
              shadowCloneAttacks,
              (a) => a.owner,
            ),
            PowerUpKind.ragingDemon => follow(
              ragingDemonAttacks,
              (a) => a.owner,
            ),
            PowerUpKind.busterSword => follow(omnislashAttacks, (a) => a.owner),
            _ => null,
          };
    castingArtwork.removeWhere(
      (effect) => identical(effect.owner, ball) && effect.skill.id == skill.id,
    );
    castingArtwork.add(
      CastingArtwork(
        ball,
        skill,
        ((visual.durationSeconds ?? skill.castingDurationSeconds) * 60)
            .round()
            .clamp(1, 600),
        active,
        // Freeze authored timing at activation. Editing the skill library while
        // a cast is visible must not silently change its cleanup policy.
        hasExplicitDuration: visual.durationSeconds != null,
        resolvedVisual: visual,
      ),
    );
  }

  void _skillSound(PowerUpKind kind) {
    final cue = match.skillLibrary.activeFor(kind, _t).soundCue;
    skillSounds.update(cue, (value) => value + 1, ifAbsent: () => 1);
  }

  void _announceSkill(SimulationBall ball, SkillDefinition skill) {
    _startCastingArtwork(ball, skill);
    skillSounds.update(skill.soundCue, (value) => value + 1, ifAbsent: () => 1);
    if (skill.yell.trim().isEmpty) return;
    _yell(
      ball,
      skill.yell.trim(),
      calloutStyle: CalloutStyle.values[skill.calloutStyle.index],
      calloutBubble: CalloutBubble.values[skill.bubbleType.index],
      durationSeconds: match.skillLibrary.calloutSecondsFor(skill),
    );
  }

  SkillDefinition visualSkill(
    PowerUpKind kind, {
    SimulationBall? ball,
    String? skillId,
  }) => _skillForId(
    kind,
    skillId ??
        (ball == null
            ? null
            : _equippedSkillId(ball, kind) ?? ball.activeEffectSkillIds[kind]),
  );

  bool usesSprite(
    PowerUpKind kind, {
    String? skillId,
    Projectile? projectile,
    SimulationBall? ball,
  }) =>
      (projectile == null
              ? visualSkill(kind, skillId: skillId, ball: ball)
              : _composedProjectiles[projectile] ?? visualSkill(kind))
          .spriteMode ==
      SkillVisualMode.sprite;

  /// Includes the payload's artwork for composed weapons.
  SkillDefinition projectileVisualSkill(Projectile projectile) =>
      _composedProjectiles[projectile] ?? visualSkill(projectile.kind);

  int artworkTint(
    PowerUpKind kind, {
    String? skillId,
    Projectile? projectile,
    SimulationBall? ball,
  }) =>
      (projectile == null
              ? visualSkill(kind, skillId: skillId, ball: ball)
              : _composedProjectiles[projectile] ?? visualSkill(kind))
          .spriteTint;

  /// The tier of [kind] as [ball] holds or uses it: a held custom skill's own tier, else the
  /// built-in's ([SkillLibrary.rarityOf]). Null for traps.
  PowerUpRarity? itemRarity(PowerUpKind kind, {SimulationBall? ball}) =>
      SkillLibrary.rarityOf(visualSkill(kind, ball: ball), _t);

  bool usesEffectSprite(
    PowerUpKind kind, {
    SimulationBall? ball,
    String? skillId,
    Projectile? projectile,
    bool globalSprite = true,
  }) {
    final skill = projectile == null
        ? visualSkill(kind, ball: ball, skillId: skillId)
        : _composedProjectiles[projectile] ?? visualSkill(kind);
    return skill.usesSpriteEffects(globalSprite: globalSprite);
  }

  String skillName(PowerUpKind kind) => visualSkill(kind).name;

  /// Sprite sizes as drawn: the skill's own, or the library's global value while its "Let each
  /// skill set its own" switch is off ([SkillLibrary.weaponDisplayScaleFor] etc.).
  double weaponDisplayScale(
    PowerUpKind kind, {
    SimulationBall? ball,
    String? skillId,
  }) => match.skillLibrary.weaponDisplayScaleFor(
    visualSkill(kind, ball: ball, skillId: skillId),
  );
  double pickupDisplayScale(PowerUpKind kind, {String? skillId}) => match
      .skillLibrary
      .pickupDisplayScaleFor(visualSkill(kind, skillId: skillId));
  double effectDisplayScale(
    PowerUpKind kind, {
    SimulationBall? ball,
    String? skillId,
  }) => effectDisplayScaleOf(visualSkill(kind, ball: ball, skillId: skillId));
  double effectDisplayScaleOf(SkillDefinition skill) =>
      match.skillLibrary.effectDisplayScaleFor(skill);
  SkillDefinition handArtworkSettings(
    PowerUpKind kind, {
    SimulationBall? ball,
  }) => visualSkill(kind, ball: ball);
  double handEffectScale(PowerUpKind kind, {SimulationBall? ball}) =>
      visualSkill(kind, ball: ball).handEffectScale;
  Color handEffectColor(PowerUpKind kind, {SimulationBall? ball}) =>
      Color(visualSkill(kind, ball: ball).handEffectColor);
  double weaponGripInset(PowerUpKind kind, {SimulationBall? ball}) =>
      visualSkill(kind, ball: ball).weaponGripInset;
  double skillRange(PowerUpKind kind, {SimulationBall? ball}) =>
      visualSkill(kind, ball: ball).range;

  void _skillYell(SimulationBall ball, PowerUpKind kind, String fallback) {
    final skill = match.skillLibrary.activeFor(kind, _t);
    // Composed/custom activations use _announceSkill with their explicit definition.
    _startCastingArtwork(
      ball,
      match.simulationRevision >= 3 ? skill : visualSkill(kind, ball: ball),
    );
    final custom = skill.yell.trim();
    _yell(
      ball,
      custom.isEmpty ? fallback : custom,
      calloutStyle: CalloutStyle.values[skill.calloutStyle.index],
      calloutBubble: CalloutBubble.values[skill.bubbleType.index],
      durationSeconds: match.skillLibrary.calloutSecondsFor(skill),
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
    _aimedTargets.remove(ball);
    _aimedTargets.removeWhere((_, target) => identical(target, ball));
    // Respawn is a new life. Old traps and custom projectiles must not
    // outlive their owner and damage players after the reset.
    mines.removeWhere((mine) => identical(mine.owner, ball));
    projectiles.removeWhere(
      (shot) =>
          identical(shot.owner, ball) && _composedProjectiles.containsKey(shot),
    );
    final liveShotsAfterReset = projectiles.toSet();
    _composedProjectiles.removeWhere(
      (shot, _) => !liveShotsAfterReset.contains(shot),
    );
    _composedIssuers.removeWhere(
      (shot, _) => !liveShotsAfterReset.contains(shot),
    );
    // End native multi-target cinematic effects that involve this life.
    _cancelOmegaTendrilsInvolving(ball);
    persistentEffects.reset(ball);
    castingArtwork.removeWhere((effect) => identical(effect.owner, ball));
    muzzleArtwork.removeWhere((effect) => identical(effect.owner, ball));
    _otherStuns.remove(ball);
    if (match.simulationRevision >= 2) {
      ragingDemonAttacks.removeWhere(
        (a) => identical(a.owner, ball) || identical(a.target, ball),
      );
      omnislashAttacks.removeWhere(
        (a) => identical(a.owner, ball) || identical(a.target, ball),
      );
    }
    ball.activeEffectSkillIds.clear();
    ball
      ..held = null
      ..heldSecondary = null
      ..heldSkillId = null
      ..heldSecondarySkillId = null
      ..meleeAttackVisual = null
      ..heldTwoHanded = false
      ..heldSecondaryTwoHanded = false
      ..speedLeft = 0
      ..speedFactor = _t.speedFactor
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
    _skillGooVictims.remove(ball);
    _vineSnareVictims.remove(ball);
    _skillGooRemaining.remove(ball);
    _vineSnareRemaining.remove(ball);
    _burstVolley.remove(ball);
    _burstShellSkill.remove(ball);
    _firedWeaponHold.remove(ball);
    _shieldedVolley.remove(ball);
    _volleyLabel.remove(ball);
    _scheduledComposedEffects.removeWhere(
      (effect) =>
          identical(effect.owner, ball) || effect.targets.contains(ball),
    );
    _effectStepQueue.removeWhere(
      (effect) =>
          identical(effect.owner, ball) || effect.targets.contains(ball),
    );
    _customDamageOverTime.removeWhere(
      (effect) =>
          identical(effect.owner, ball) || identical(effect.target, ball),
    );
    _composedCooldownUntil.removeWhere((key, _) => identical(key.$1, ball));
    _passiveSchedulers.removeWhere((key, _) => identical(key.$1, ball));
    _lastVital.remove(ball);
    pulls.removeWhere(
      (pull) => identical(pull.owner, ball) || identical(pull.target, ball),
    );
    _cancelOmegaTendrilsInvolving(ball);
    for (final attack in energyWaveAttacks.toList()) {
      if (identical(attack.owner, ball) || attack.targets.contains(ball)) {
        _releaseEnergyWave(attack, launchAway: false);
      }
    }
    // Remove attacks from this life. Surviving owners retarget on their
    // next update instead of striking the newly respawned player.
    shadowCloneAttacks.removeWhere(
      (attack) =>
          identical(attack.owner, ball) ||
          (match.simulationRevision >= 2 && identical(attack.target, ball)),
    );
    if (match.simulationRevision < 2) {
      for (final attack in shadowCloneAttacks) {
        if (identical(attack.target, ball)) {
          attack.target = null;
        }
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

  /// The skill of the gatling a ball's burst came from, for its casings.
  final Map<SimulationBall, SkillDefinition> _burstShellSkill = {};
  final Map<SimulationBall, int> _burstVolley = {};
  final Map<SimulationBall, Map<({PowerUpKind kind, String? id}), int>>
  _firedWeaponHold = {};
  ({PowerUpKind kind, String? id}) _holdKey(
    SimulationBall ball,
    PowerUpKind kind,
    String? id,
  ) => (
    kind: kind,
    id: match.simulationRevision < 3
        ? null
        : id ?? _equippedSkillId(ball, kind) ?? 'builtin.${kind.name}',
  );
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

  int firedWeaponHoldLeft(
    SimulationBall ball,
    PowerUpKind kind, {
    String? skillId,
  }) => _firedWeaponHold[ball]?[_holdKey(ball, kind, skillId)] ?? 0;

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

  /// Editor demos activate one skill explicitly, without unrelated innate triggers.
  bool automaticPassiveTriggers = true;

  /// Place a selected item using the real spawn rules in the admin test arena.
  void spawnTestItem(PowerUpKind kind, {String? skillId}) =>
      _spawn(match.stepCount + 1, forcedKind: kind, forcedSkillId: skillId);

  /// Deploys the selected arena decoration's environmental hazard in tests.
  void spawnTestArenaHazard() {
    if (_t.arenaTrapsEnabled) _spawnArenaThemeHazard(match.stepCount + 1);
  }

  /// One manual activation for the editor demo. Ordinary match triggers are unchanged.
  void activateTestSkill(
    SimulationBall owner,
    SkillDefinition skill,
    SimulationBall target,
  ) {
    // Demo activations must obey the same trap policy as match spawning.
    if (!_t.skillTrapsEnabled &&
        (skill.baseKind.isTrap ||
            skill.resolvedCategory == SkillCategory.trap ||
            skill.resolvedCategory == SkillCategory.arenaTrap)) {
      return;
    }
    if (skill.isComposed) {
      final payload = match.skillLibrary.resolvePayload(skill, _t);
      final activated =
          skill.delivery == SkillDelivery.projectile || payload != null
          ? _launchComposed(owner, target, skill, payload: payload)
          : _executeComposed(owner, skill, primary: target);
      if (activated && skill.resolvedCategory == SkillCategory.weapon) {
        _holdFiredWeapon(owner, skill.baseKind, skillId: skill.id);
      }
      return;
    }
    if (skill.resolvedCategory == SkillCategory.trap ||
        skill.resolvedCategory == SkillCategory.arenaTrap) {
      if (skill.baseKind == PowerUpKind.mine ||
          skill.baseKind == PowerUpKind.phaseMine) {
        pickUp(
          owner,
          FieldPowerUp(
            kind: skill.baseKind,
            skillId: skill.id,
            position: owner.position,
            spawnStep: match.stepCount,
          ),
        );
      } else {
        spawnTestItem(skill.baseKind, skillId: skill.id);
      }
      final position = switch (skill.baseKind) {
        PowerUpKind.mine || PowerUpKind.phaseMine => mines.lastOrNull?.position,
        PowerUpKind.portal => portals.lastOrNull?.position,
        PowerUpKind.spikeWall => spikeWalls.lastOrNull?.position,
        PowerUpKind.stickyGoo => stickyGoo.lastOrNull?.position,
        PowerUpKind.poisonSwamp => poisonSwamps.lastOrNull?.position,
        _ => null,
      };
      if (position != null) {
        target.position = position * .96;
        target.velocity = Offset.zero;
      }
      return;
    }
    pickUp(
      owner,
      FieldPowerUp(
        kind: skill.baseKind,
        skillId: skill.id,
        position: owner.position,
        spawnStep: match.stepCount,
      ),
    );
    if (skill.resolvedCategory == SkillCategory.weapon) {
      if (skill.baseKind.isGun) {
        owner.aimLeft = 1;
      } else if (skill.baseKind == PowerUpKind.orbitingFlail) {
        // Start its real orbit/contact updates rather than consuming it as a bump.
        return;
      } else {
        onContact(owner, target);
      }
    }
  }

  void step() {
    _clearDisabledSkillTraps();
    _processPassiveTriggers();
    _updateArenaThemeHazards();
    // Visual-only: a consumed sword must remain gone for combat, but its
    // strike artwork needs a few frames to complete the swing.
    for (final ball in match.state.balls) {
      final visual = ball.meleeAttackVisual;
      if (visual != null) {
        visual.stepsLeft -= 1;
        if (visual.stepsLeft <= 0) ball.meleeAttackVisual = null;
      }
    }
    _updateFiredWeaponHold();
    _updateScheduledComposedEffects();
    _updateEffectSteps();
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
    _updatePhaseEightAttacks();
    _updateShellCasings();
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
    _strikeWithMeleeReach();
    _sweep();
    _updateFrozen();
    _updateStunned();
    _moveProjectiles();
    _reelIn();
    _aimAndFire();
    // The controller counts a step after it ran, so this is the 1-based number of the running step.
    final number = match.stepCount + 1;
    if (automaticSpawning &&
        _t.arenaTrapsEnabled &&
        number >= _t.trapStartSteps &&
        (number - _t.trapStartSteps) % _t.arenaTrapIntervalSteps == 0) {
      _spawnArenaThemeHazard(number);
    }
    if (automaticSpawning &&
        number >= _t.firstSpawnSteps &&
        (number - _t.firstSpawnSteps) % _t.spawnInterval(_ballCount) == 0) {
      _spawn(number);
    }
    _turnTrackedItems();
    persistentEffects.sync();
  }

  void _spawnArenaThemeHazard(int number) {
    if (!_t.arenaTrapsEnabled) return;
    if (match.arenaDecoration == ArenaDecoration.defaultArena) {
      _spawn(number, forcedKind: PowerUpKind.spikeWall, arenaHazard: true);
      return;
    }
    if (match.arenaDecoration == ArenaDecoration.chaotic) {
      for (final kind in ArenaThemeHazardKind.values) {
        _addArenaThemeHazard(kind, number);
      }
      return;
    }
    final kind = switch (match.arenaDecoration) {
      ArenaDecoration.space => ArenaThemeHazardKind.gravityWell,
      ArenaDecoration.desert => ArenaThemeHazardKind.quicksand,
      ArenaDecoration.wilderness => ArenaThemeHazardKind.vineSnare,
      ArenaDecoration.neonGrid => ArenaThemeHazardKind.laserGate,
      ArenaDecoration.chaotic => throw StateError('Handled above'),
      ArenaDecoration.defaultArena => throw StateError('Handled above'),
    };
    _addArenaThemeHazard(kind, number);
  }

  void _addArenaThemeHazard(ArenaThemeHazardKind kind, int number) {
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
    final limit = match.arenaDecoration == ArenaDecoration.chaotic ? 8 : 2;
    while (arenaThemeHazards.length > limit) {
      // Capacity eviction is an expiry too: release current quicksand
      // occupants unless another surviving patch still contains them.
      final evicted = arenaThemeHazards.removeAt(0);
      _releaseEvictedQuicksand(evicted);
    }
  }

  /// Apply the same ownership check for age expiry and capacity eviction.
  /// A removed patch must never eject a ball still inside another patch.
  void _releaseEvictedQuicksand(ArenaThemeHazard removed) {
    if (removed.kind != ArenaThemeHazardKind.quicksand) return;
    final radius = match.arenaRadius * 0.18;
    for (final ball in removed.affected) {
      if ((ball.position - removed.position).distance >= radius) continue;
      if (arenaThemeHazards.any(
        (other) =>
            other.kind == ArenaThemeHazardKind.quicksand &&
            (ball.position - other.position).distance < radius,
      )) {
        continue;
      }
      _releaseQuicksandVictim(ball, removed.position);
    }
  }

  /// Remove hazards belonging to the outgoing arena theme, not skill traps.
  /// Called both by the arena-trap switch and by dynamic theme rotation.
  /// Skill goo and its saved pre-immobilization velocity must survive.
  void clearAutomaticArenaHazards() {
    spikeWalls.removeWhere((wall) => wall.arenaGenerated);
    final releasedQuicksand = <SimulationBall, Offset>{};
    final radius = match.arenaRadius * 0.18;
    for (final hazard in arenaThemeHazards) {
      if (hazard.kind != ArenaThemeHazardKind.quicksand) continue;
      for (final ball in hazard.affected) {
        if ((ball.position - hazard.position).distance < radius) {
          releasedQuicksand.putIfAbsent(ball, () => hazard.position);
        }
      }
    }
    // Remove all automatic sources before deciding whether a victim is free.
    arenaThemeHazards.clear();
    for (final ball in _vineSnareVictims.toList()) {
      _vineSnareRemaining.remove(ball);
      final remaining = _skillGooRemaining[ball] ?? 0;
      ball.stickyGooLeft = remaining;
      if (remaining == 0) {
        ball.velocity = _gooVelocity.remove(ball) ?? ball.velocity;
      }
    }
    _vineSnareVictims.clear();
    for (final entry in releasedQuicksand.entries) {
      _releaseQuicksandVictim(entry.key, entry.value);
    }
  }

  void _updateArenaThemeHazards() {
    // Settings can change during a match. Existing automatic hazards must
    // stop affecting balls immediately when arena traps are disabled.
    if (!_t.arenaTrapsEnabled) {
      clearAutomaticArenaHazards();
      return;
    }
    final radius = match.arenaRadius * 0.18;
    // A ball inside multiple quicksand patches must be slowed and damaged
    // once per simulation step, not once per overlapping patch. Each patch
    // still tracks its own occupants for expiration and capacity eviction.
    final quicksandSlowedThisStep = <SimulationBall>{};
    final quicksandDamagedThisStep = <SimulationBall>{};
    // Overlapping laser gates must not multiply their damage in one frame.
    // Each gate still tracks independent entry/exit for subsequent frames.
    final laserDamagedThisStep = <SimulationBall>{};
    for (final hazard in arenaThemeHazards.toList()) {
      hazard.age++;
      if (hazard.age >= _t.arenaTrapDurationSteps) {
        // Remove the expired patch before releasing victims. Another active
        // quicksand patch may still own them, in which case they stay slowed.
        arenaThemeHazards.remove(hazard);
        _releaseEvictedQuicksand(hazard);
        continue;
      }
      for (final ball in match.state.balls) {
        if (!_alive(ball) || ball.isGhost) {
          hazard.affected.remove(ball);
          continue;
        }
        final offset = hazard.position - ball.position;
        switch (hazard.kind) {
          case ArenaThemeHazardKind.gravityWell:
            if (offset.distance < radius * 2.2 && offset.distance > 0) {
              ball.velocity +=
                  offset /
                  offset.distance *
                  match.arenaRadius *
                  _t.gravityWellForce;
            }
          case ArenaThemeHazardKind.quicksand:
            if (offset.distance < radius) {
              hazard.affected.add(ball);
              if (quicksandSlowedThisStep.add(ball)) {
                ball.velocity *= _t.quicksandVelocityMultiplier;
              }
              if ((match.stepCount + 1) % 60 == 0 &&
                  quicksandDamagedThisStep.add(ball)) {
                _damageArenaHazard(
                  ball,
                  _t.quicksandDamage,
                  _t.quicksandLines,
                  'Quicksand',
                );
              }
            } else {
              // Track current occupants, not every ball ever touched.
              hazard.affected.remove(ball);
            }
          case ArenaThemeHazardKind.vineSnare:
            // Membership is spatial, not a permanent record of first contact.
            // A ball that leaves and re-enters an active snare can be caught
            // again, without repeatedly refreshing its timer while inside.
            if (offset.distance >= radius) {
              hazard.affected.remove(ball);
              break;
            }
            if (hazard.affected.add(ball)) {
              // Keep the original pre-immobilization velocity if skill goo
              // already owns this victim. A second snare must not overwrite
              // it with the zero velocity of an immobilized ball.
              _gooVelocity.putIfAbsent(ball, () => ball.velocity);
              _vineSnareVictims.add(ball);
              _vineSnareRemaining[ball] = math.max(
                _vineSnareRemaining[ball] ?? 0,
                _t.vineSnareSteps,
              );
              ball
                ..stickyGooLeft = math.max(
                  ball.stickyGooLeft,
                  _t.vineSnareSteps,
                )
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
              if (hazard.affected.add(ball) && laserDamagedThisStep.add(ball)) {
                _damageArenaHazard(
                  ball,
                  _t.laserGateDamage,
                  _t.laserGateLines,
                  'Laser Gate',
                );
                _recordWeaponImpact(
                  WeaponImpact(position: ball.position, strength: 0.35),
                );
                _sound('laser');
              }
            } else {
              hazard.affected.remove(ball);
            }
        }
      }
    }
  }

  void _releaseQuicksandVictim(SimulationBall ball, Offset origin) {
    if (!_alive(ball)) return;
    // A different enabled trap may still be immobilizing the victim.
    if (ball.stickyGooLeft > 0 ||
        (_skillGooRemaining[ball] ?? 0) > 0 ||
        (_vineSnareRemaining[ball] ?? 0) > 0) {
      return;
    }
    final away = ball.position - origin;
    final direction = away.distance == 0
        ? Offset.fromDirection(rng.nextDoubleRange(0, math.pi * 2))
        : away / away.distance;
    ball.velocity =
        direction * math.max(ball.velocity.distance, match.arenaRadius * 0.42);
    _yell(ball, 'FREE!');
  }

  void _damageArenaHazard(
    SimulationBall ball,
    double arsenalDamage,
    int allOutLines,
    String move,
  ) {
    final lost = match.mode == MatchMode.arsenal
        ? match.damage(
            ball,
            arsenalDamage,
            move: move,
            moveSourceId: 'arena.${move.toLowerCase().replaceAll(' ', '-')}',
          )
        : match.cutThreads(
            ball,
            allOutLines,
            near: ball.position,
            move: move,
            moveSourceId: 'arena.${move.toLowerCase().replaceAll(' ', '-')}',
          );
    _showDamage(ball, ball.position, lost, 0);
  }

  double _vital(SimulationBall ball) => match.mode == MatchMode.arsenal
      ? ball.life
      : ball.fanLines.length.toDouble();

  Iterable<SkillDefinition> _activeComposedSkills(SkillTrigger trigger) sync* {
    for (final skill in match.skillLibrary.custom) {
      if (skill.enabled && skill.isComposed && skill.trigger == trigger) {
        yield skill;
      }
    }
  }

  /// One policy for every composed trap entry point, including delayed work.
  /// Arena hazards use their separate arena-trap setting elsewhere.
  bool _allowsSkillActivation(SkillDefinition skill) =>
      _t.skillTrapsEnabled ||
      !(skill.baseKind.isTrap ||
          skill.resolvedCategory == SkillCategory.trap ||
          skill.resolvedCategory == SkillCategory.arenaTrap);

  void _dispatchPassive(
    SimulationBall owner,
    SkillDefinition skill,
    SkillTrigger event,
    double time, {
    SimulationBall? primary,
  }) {
    if (!_allowsSkillActivation(skill)) return;
    if (!_passiveTriggered(owner, skill, event, time)) return;
    if (!_executeComposed(owner, skill, primary: primary) &&
        event != SkillTrigger.elimination) {
      _passiveScheduler(owner, skill).retryRejected(time);
    }
  }

  void _processPassiveTriggers() {
    if (!automaticPassiveTriggers) {
      _passiveSchedulers.clear();
      _lastVital.clear();
      return;
    }
    final time = (match.stepCount + 1) / 60.0;
    final timerSkills = _activeComposedSkills(SkillTrigger.timer).toList();
    final damageSkills = _activeComposedSkills(
      SkillTrigger.damageTaken,
    ).toList();
    // Remove passive state for actors or skills no longer participating.
    // Otherwise a removed custom skill may retain an old timer if recreated
    // with the same ID, and eliminated actors may retain pending events.
    final liveBalls = match.state.balls.where(_alive).toSet();
    final activePassiveIds = <String>{
      for (final skill in timerSkills) skill.id,
      for (final skill in damageSkills) skill.id,
      for (final skill in _activeComposedSkills(SkillTrigger.elimination))
        skill.id,
    };
    _passiveSchedulers.removeWhere(
      (key, _) =>
          !liveBalls.contains(key.$1) || !activePassiveIds.contains(key.$2),
    );
    _lastVital.removeWhere((ball, _) => !liveBalls.contains(ball));
    for (final ball in match.state.balls) {
      final current = _vital(ball);
      final tookDamage = current < (_lastVital[ball] ?? current);
      _lastVital[ball] = current;
      if (!_alive(ball)) continue;
      for (final skill in timerSkills) {
        _dispatchPassive(ball, skill, SkillTrigger.timer, time);
      }

      for (final skill in damageSkills) {
        // Also drain rejected activations on frames without fresh damage.
        if (tookDamage || _passiveScheduler(ball, skill).pendingCount > 0) {
          _dispatchPassive(ball, skill, SkillTrigger.damageTaken, time);
        }
      }
    }
  }

  void onEliminations(
    Iterable<SimulationBall> eliminated,
    Map<SimulationBall, SimulationBall> attackers,
  ) {
    final victims = eliminated.toSet();
    if (victims.isEmpty) return;
    mines.removeWhere((mine) => victims.contains(mine.owner));
    // A composed projectile belongs to a specific life. Remove it when its
    // owner is eliminated, before another actor can inherit its impact job.
    projectiles.removeWhere(
      (shot) =>
          victims.contains(shot.owner) &&
          _composedProjectiles.containsKey(shot),
    );
    final survivingShots = projectiles.toSet();
    _composedProjectiles.removeWhere(
      (shot, _) => !survivingShots.contains(shot),
    );
    _composedIssuers.removeWhere((shot, _) => !survivingShots.contains(shot));
    _passiveSchedulers.removeWhere((key, _) => victims.contains(key.$1));
    _lastVital.removeWhere((ball, _) => victims.contains(ball));
    _scheduledComposedEffects.removeWhere(
      (effect) => victims.contains(effect.owner),
    );
    _effectStepQueue.removeWhere((effect) => victims.contains(effect.owner));
    _customDamageOverTime.removeWhere(
      (effect) => victims.contains(effect.owner),
    );
    _composedCooldownUntil.removeWhere((key, _) => victims.contains(key.$1));
    if (!automaticPassiveTriggers) return;
    final skills = _activeComposedSkills(SkillTrigger.elimination).toList();
    if (skills.isEmpty) return;
    final time = (match.stepCount + 1) / 60.0;
    for (final victim in victims) {
      final owner = attackers[victim];
      if (owner == null || !_alive(owner)) continue;
      for (final skill in skills) {
        _dispatchPassive(
          owner,
          skill,
          SkillTrigger.elimination,
          time,
          primary: victim,
        );
      }
    }
  }

  void _holdFiredWeapon(
    SimulationBall ball,
    PowerUpKind kind, {
    int steps = firedWeaponHoldSteps,
    String? skillId,
  }) {
    persistentEffects.rememberEquipment(ball);
    final skill = visualSkill(kind, ball: ball, skillId: skillId);
    if (kind.isGun || skill.trigger == SkillTrigger.aimedFire) {
      final visual = match.skillLibrary.resolveVisual(
        skill,
        SkillVisualRole.muzzle,
      );
      if (visual != null) {
        final direction =
            (ball.aimTarget?.position ?? ball.position + ball.velocity) -
            ball.position;
        muzzleArtwork.add(
          MuzzleArtwork(
            ball,
            skill,
            direction,
            ((visual.durationSeconds ?? .12) * 60).round().clamp(1, 600),
            resolvedVisual: visual,
          ),
        );
        if (muzzleArtwork.length > 128) muzzleArtwork.removeAt(0);
      }
    }
    (_firedWeaponHold[ball] ??= {})[_holdKey(
      ball,
      kind,
      skillId,
    )] = kind == PowerUpKind.fireWall
        ? (visualSkill(kind, ball: ball).handEffectDurationSeconds * 60).round()
        : steps;
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
        while ((ball.held == kind.kind &&
                (kind.id == null ||
                    (ball.heldSkillId ?? 'builtin.${kind.kind.name}') ==
                        kind.id)) ||
            (ball.heldSecondary == kind.kind &&
                (kind.id == null ||
                    (ball.heldSecondarySkillId ??
                            'builtin.${kind.kind.name}') ==
                        kind.id))) {
          persistentEffects.emit(
            visualSkill(kind.kind, skillId: kind.id),
            SkillVisualRole.discard,
            ball.position,
            owner: ball,
          );
          ball.removeWeapon(kind.kind, skillId: kind.id);
          persistentEffects.rememberEquipment(ball);
        }
        held.remove(kind);
      }
      if (held.isEmpty) _firedWeaponHold.remove(ball);
    }
  }

  /// Gives [ball] the pickup [p] and takes [p] off the field. Power-ups apply
  /// without replacing equipment; a weapon replaces the one equipped weapon.
  void pickUp(SimulationBall ball, FieldPowerUp p) {
    final matchingCustom = match.skillLibrary.custom
        .where((skill) => skill.enabled && skill.baseKind == p.kind)
        .toList();
    final activeSkill = p.skillId != null
        ? match.skillLibrary.byId(p.skillId!, _t) ??
              match.skillLibrary.builtIn(p.kind, _t)
        : match.simulationRevision < 3 && matchingCustom.length == 1
        ? matchingCustom.single
        : match.skillLibrary.builtIn(p.kind, _t);
    // A trap pickup already on the field must not bypass a policy change.
    // Leave it unconsumed so the player's independent setting can be restored.
    if (!_t.skillTrapsEnabled &&
        (p.kind.isTrap ||
            activeSkill.baseKind.isTrap ||
            activeSkill.resolvedCategory == SkillCategory.trap ||
            activeSkill.resolvedCategory == SkillCategory.arenaTrap)) {
      return;
    }
    // Do not consume a pickup while its composed activation is unavailable.
    // The executor also checks target availability and scheduling capacity.
    if (activeSkill.isComposed && activeSkill.trigger == SkillTrigger.pickup) {
      if (!_executeComposed(ball, activeSkill)) return;
      persistentEffects.rememberEquipment(ball);
      field.remove(p);
      if (activeSkill.resolvedCategory != SkillCategory.weapon) {
        ball.activeEffectSkillIds[p.kind] = activeSkill.id;
      }
      pickups++;
      return;
    }
    persistentEffects.rememberEquipment(ball);
    field.remove(p);
    if (activeSkill.resolvedCategory != SkillCategory.weapon) {
      ball.activeEffectSkillIds[p.kind] = activeSkill.id;
    }
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
        ball
          ..speedLeft = _t.speedSteps
          ..speedFactor = _t.speedFactor;
        _skillYell(ball, p.kind, 'ZOOM!');
      case PowerUpKind.ghost:
        ball.ghostLeft = _t.ghostSteps;
        _skillYell(ball, p.kind, 'BOO!');
      case PowerUpKind.magnet:
        _pullNearest(ball);
        _skillYell(ball, p.kind, 'MINE!');
      case PowerUpKind.repulsor:
        ball.repulsorLeft = _t.repulsorSteps;
        _skillYell(ball, p.kind, 'BACK OFF!');
      case PowerUpKind.timeBubble:
        ball.timeBubbleLeft = _t.timeBubbleSteps;
        _skillYell(ball, p.kind, 'TIME OUT!');
      case PowerUpKind.vampire:
        ball.vampireLeft = ((activeSkill.durationSeconds ?? 3) * 60).round();
        _skillYell(ball, p.kind, 'I WANT YOUR POWER!');
      case PowerUpKind.mirror:
        ball.mirrorCharges++;
        _skillYell(ball, p.kind, 'RETURN TO SENDER!');
      case PowerUpKind.overcharge:
        ball.overchargeLeft = _t.maximumPowerSteps;
        _skillYell(ball, p.kind, 'MAXIMUM POWER!');
      case PowerUpKind.gremlin:
        final target = _nearestTarget(ball);
        if (target != null) {
          target.gremlinShots++;
          target.activeEffectSkillIds[PowerUpKind.gremlin] = activeSkill.id;
        }
        _skillYell(ball, p.kind, 'CHAOS MODE!');
      case PowerUpKind.magneticField:
        ball.magneticFieldLeft = ((activeSkill.durationSeconds ?? 3) * 60)
            .round();
        ball.magneticReflectedOwners.clear();
        _skillYell(ball, p.kind, 'NOTHING GETS THROUGH!');
      case PowerUpKind.goldenArmor:
        ball.goldenArmorHits = activeSkill.shieldHits;
        _skillYell(ball, p.kind, 'GOLDEN GUARD!');
      case PowerUpKind.omegaTendrils:
        _launchOmegaTendrils(ball);
        _skillYell(ball, p.kind, 'NO ONE ESCAPES!');
      case PowerUpKind.lightningStrikes:
        final target = _nearestTarget(ball);
        if (target != null) {
          lightningStrikes.add(
            LightningStrike(owner: ball, target: target)
              ..strikesLeft = activeSkill.projectileCount ?? 3,
          );
          _skillYell(ball, p.kind, 'THUNDER, STRIKE!');
        }
      case PowerUpKind.earthquake:
        earthquakes.add(EarthquakePulse(owner: ball));
        _skillYell(ball, p.kind, 'SHAKE THE EARTH!');
      case PowerUpKind.tornado:
        final target = _nearestTarget(ball);
        if (target != null) {
          tornadoes.add(
            Tornado(
              owner: ball,
              target: target,
              position: ball.position,
              aimSteps:
                  (match.skillLibrary
                              .activeFor(PowerUpKind.tornado, _t)
                              .handEffectDurationSeconds *
                          60)
                      .round(),
            ),
          );
          _skillYell(ball, p.kind, 'TWIST AND SHOUT!');
        }
      case PowerUpKind.friedChicken:
        _eatFriedChicken(ball);
      case PowerUpKind.ragingDemon:
        _startRagingDemon(ball);
      case PowerUpKind.shadowClone:
        _startShadowClone(ball);
      default:
        if (match.simulationRevision >= 3) {
          _firedWeaponHold[ball]?.remove(
            _holdKey(ball, p.kind, activeSkill.id),
          );
        }
        ball.equipWeapon(
          p.kind,
          dualWield: match.dualWield,
          twoHanded: _twoHandedOverride(activeSkill),
          skillId: activeSkill.id,
        );
        // All-Out sword sweep: for a moment the new blade rakes through threads with a wider reach.
        if (p.kind.isBlade && match.mode == MatchMode.allOut) {
          ball.sweepLeft = PowerUpTuning.sweepSteps;
        }
    }
  }

  void _eatFriedChicken(SimulationBall ball) {
    if (match.mode == MatchMode.arsenal) {
      if (ball.life >= 100) return;
      ball.life = 100;
      match.state.floatingTexts.spawn(
        ball.position,
        'FULL HEALTH!',
        const Color(0xFFFFD54F),
      );
    } else {
      final claimed = match.claimFreeSlots(ball, 1 << 20);
      if (claimed == 0) return;
      match.state.floatingTexts.spawn(
        ball.position,
        '+$claimed LINES',
        const Color(0xFFFFD54F),
      );
    }
    match.state.particles.spawnSparkle(
      origin: ball.position,
      rng: rng,
      displayScale: effectDisplayScale(PowerUpKind.friedChicken, ball: ball),
    );
    _skillYell(ball, PowerUpKind.friedChicken, 'FEAST MODE!');
  }

  SimulationBall? _farthestTarget(SimulationBall owner) {
    SimulationBall? result;
    var distance = -1.0;
    for (final target in match.state.balls) {
      if (identical(target, owner) || !_alive(target)) continue;
      final candidate = (target.position - owner.position).distanceSquared;
      if (candidate > distance) {
        result = target;
        distance = candidate;
      }
    }
    return result;
  }

  void _freezeTime(int steps, {Object? source}) {
    if (match.simulationRevision >= 2 && source != null) {
      if (_cinematicFreezes.isEmpty) {
        for (final ball in match.state.balls) {
          _otherStuns[ball] = ball.stunnedLeft;
        }
      }
      _cinematicFreezes[source] = steps;
    }
    for (final ball in match.state.balls) {
      if (!_alive(ball)) continue;
      if (ball.stunnedLeft == 0) _stunnedVelocity[ball] = ball.velocity;
      ball
        ..stunnedLeft = math.max(ball.stunnedLeft, steps)
        ..velocity = Offset.zero;
    }
  }

  void _fireSniper(SimulationBall owner, SimulationBall target) {
    sniperFlashes.add(SniperFlash(owner: owner, target: target));
    target.goldenArmorHits = 0;
    if (match.mode == MatchMode.arsenal) {
      match.damage(
        target,
        math.max(1, target.life),
        attacker: owner,
        move: skillName(PowerUpKind.sniperRifle),
        moveSkill: visualSkill(PowerUpKind.sniperRifle),
        scaleForCrowd: false,
        applyFrozenMultiplier: false,
      );
    } else {
      match.cutThreads(
        target,
        target.fanLines.length,
        near: target.position,
        attacker: owner,
        move: skillName(PowerUpKind.sniperRifle),
        moveSkill: visualSkill(PowerUpKind.sniperRifle),
      );
    }
    _recordWeaponImpact(
      WeaponImpact(
        position: target.position,
        target: target,
        direction: target.position - owner.position,
        strength: 1,
        kind: PowerUpKind.sniperRifle,
        skillId: visualSkill(PowerUpKind.sniperRifle, ball: owner).id,
      ),
    );
    hits++;
    _skillSound(PowerUpKind.sniperRifle);
    _skillYell(owner, PowerUpKind.sniperRifle, 'ONE SHOT.');
  }

  void _startOmnislash(SimulationBall owner) {
    final target = _farthestTarget(owner);
    if (target == null) return;
    final attack = OmnislashAttack(owner: owner, target: target);
    _freezeTime(52, source: attack);
    omnislashAttacks.add(attack);
    _skillYell(owner, PowerUpKind.busterSword, 'OMNISLASH!');
  }

  void _startRagingDemon(SimulationBall owner) {
    final target = _nearestTarget(owner);
    if (target == null) return;
    final skill = match.skillLibrary.activeFor(PowerUpKind.ragingDemon, _t);
    final settings = RagingDemonCastSettings.resolve(
      configuredHits: skill.projectileCount,
      tunedHits: _t.ragingDemonHits,
    );
    final attack = RagingDemonAttack(
      owner: owner,
      target: target,
      totalHits: settings.hits,
    );
    _freezeTime(settings.freezeSteps, source: attack);
    ragingDemonAttacks.add(attack);
    _skillYell(owner, PowerUpKind.ragingDemon, 'DIE ONE THOUSAND DEATHS!');
  }

  /// Kage bunshin: time freezes for the whole sequence while the clones strike one by one
  /// ([_updateShadowClones]).
  void _startShadowClone(SimulationBall owner) {
    final target = _nearestTarget(owner);
    if (target == null) return;
    // Native cinematic strikes honor the configured count without replacing
    // their original animation or turning the strikes into projectiles.
    final skill = match.skillLibrary.activeFor(PowerUpKind.shadowClone, _t);
    final settings = ShadowCloneCastSettings.resolve(
      count: skill.projectileCount,
      tunedCount: _t.shadowCloneCount,
      appearanceSteps: skill.shadowAppearSteps,
      strikeIntervalSteps: skill.shadowStrikeSteps,
      disappearanceSteps: skill.shadowVanishSteps,
    );
    final attack = ShadowCloneAttack(
      owner: owner,
      target: target,
      clones: settings.count,
      appearanceSteps: settings.appearanceSteps,
      strikeIntervalSteps: settings.strikeIntervalSteps,
      disappearanceSteps: settings.disappearanceSteps,
    );
    _freezeTime(attack.totalDuration, source: attack);
    shadowCloneAttacks.add(attack);
    _skillYell(owner, PowerUpKind.shadowClone, 'KAGE BUNSHIN NO JUTSU!');
  }

  void _updateShadowClones() {
    for (final attack in shadowCloneAttacks.toList()) {
      attack.age++;
      if (attack.vanishAt == null) {
        final current = attack.target;
        if (current == null || !_alive(current)) {
          attack.target = _nearestTarget(attack.owner);
        }
        final victim = attack.target;
        if (victim == null || !_alive(attack.owner)) {
          attack
            ..target = null
            ..vanishAt = attack.age;
        } else if (attack.age >= attack.strikeAt(attack.clonesDone)) {
          attack.struckAt.add(attack.strikePoint(attack.clonesDone, victim));
          attack.clonesDone++;
          _hit(
            victim,
            PowerUpKind.shadowClone,
            at: victim.position,
            from: attack.owner,
            scaleForCrowd: false,
          );
          _skillSound(PowerUpKind.shadowClone);
          if (attack.clonesDone >= attack.clones) {
            attack.vanishAt = attack.age;
          } else if (!_alive(victim)) {
            attack.target = _nearestTarget(attack.owner);
            if (attack.target == null) attack.vanishAt = attack.age;
          }
        }
      }
      if (attack.finished) shadowCloneAttacks.remove(attack);
    }
  }

  void _updatePhaseEightAttacks() {
    for (final flash in sniperFlashes) {
      flash.age++;
    }
    sniperFlashes.removeWhere((flash) => flash.age >= 24);

    for (final attack in omnislashAttacks.toList()) {
      if (match.simulationRevision >= 2 &&
          (!_alive(attack.owner) ||
              !_alive(attack.target) ||
              !omnislashAttacks.contains(attack))) {
        omnislashAttacks.remove(attack);
        continue;
      }
      attack.age++;
      if (attack.age % 5 == 0 && attack.hitsShown < 8) {
        attack.hitsShown++;
        attack.owner.position =
            attack.target.position +
            Offset.fromDirection(
              attack.hitsShown * math.pi * 0.73,
              attack.target.radius * 1.65,
            );
        _hit(
          attack.target,
          PowerUpKind.busterSword,
          at: attack.target.position,
          from: attack.owner,
          scaleForCrowd: false,
        );
        slashMarks.add(
          SlashMark(
            position: attack.target.position,
            angle: attack.hitsShown * math.pi / 4,
            kind: PowerUpKind.busterSword,
          ),
        );
      }
      if (attack.hitsShown >= 8 && attack.age >= 46) {
        omnislashAttacks.remove(attack);
      }
    }

    for (final attack in ragingDemonAttacks.toList()) {
      if (match.simulationRevision >= 2 &&
          (!_alive(attack.owner) ||
              !_alive(attack.target) ||
              !ragingDemonAttacks.contains(attack))) {
        ragingDemonAttacks.remove(attack);
        continue;
      }
      attack.age++;
      if (attack.age % 2 == 0 && attack.hitsShown < attack.totalHits) {
        attack.hitsShown++;
        // Stage each strike just outside collision range. Moving the attacker
        // into the victim made the physics engine add hidden knockback on
        // every hit, even when the skill's configured knockback was zero.
        final strikeAngle = attack.hitsShown * math.pi * 0.73;
        final separation = (attack.owner.radius + attack.target.radius) * 1.08;
        attack.owner.position =
            attack.target.position +
            Offset.fromDirection(strikeAngle, separation);
        _hit(
          attack.target,
          PowerUpKind.ragingDemon,
          at: attack.target.position,
          from: attack.owner,
          scaleForCrowd: false,
        );
      }
      if (attack.hitsShown >= attack.totalHits &&
          attack.age >= attack.totalHits * 2 + 12) {
        _recordWeaponImpact(
          WeaponImpact(position: attack.target.position, strength: 1),
        );
        ragingDemonAttacks.remove(attack);
      }
    }
    _updateShadowClones();
  }

  bool? _twoHandedOverride(SkillDefinition skill) => switch (skill.handedness) {
    SkillHandedness.carrierDefault => null,
    SkillHandedness.oneHanded => false,
    SkillHandedness.twoHanded => true,
  };

  void _launchOmegaTendrils(SimulationBall owner) {
    // Snapshot every native parameter at cast time, as with Shadow Clone.
    // A library edit during a grab must not alter its pending release.
    final skill = match.skillLibrary.activeFor(PowerUpKind.omegaTendrils, _t);
    final settings = OmegaTendrilsCastSettings.resolve(
      targetCount: skill.projectileCount,
      durationSeconds: skill.durationSeconds,
      slamOffsetRatio: skill.omegaSlamOffsetRatio,
      slamVelocityMultiplier: skill.omegaSlamVelocityMultiplier,
    );
    // Build one identity-based snapshot of currently held opponents. Repeated
    // casts must skip held targets *before* applying the new target limit.
    // Identity is essential: distinct balls may compare equal by value.
    final heldTargets = HashSet<SimulationBall>.identity()
      ..addAll(omegaTendrils.map((effect) => effect.target));
    final targets = NativeAdvancedTargetSelection.select<SimulationBall>(
      owner: owner,
      candidates: match.state.balls,
      isActive: _alive,
      isEligible: (candidate) => !heldTargets.contains(candidate),
      limit: settings.targetLimit,
    );
    // Never stack independent release timers or replace the saved velocity
    // of a grab already in flight.
    for (final target in targets) {
      if (!heldTargets.add(target)) continue;
      omegaTendrils.add(
        OmegaTendril(
          owner: owner,
          target: target,
          savedVelocity: target.velocity,
          stepsLeft: settings.holdSteps,
          slamOffsetRatio: settings.slamOffsetRatio,
          slamVelocityMultiplier: settings.slamVelocityMultiplier,
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
      if (tornado.isAiming) {
        tornado.position = tornado.owner.position;
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

  /// Cancel a native grab without its slam when a participant leaves this
  /// life. A surviving victim must regain the velocity captured at grab time;
  /// otherwise a canceled tendril can leave them motionless indefinitely.
  void _cancelOmegaTendrilsInvolving(SimulationBall ball) {
    for (final tendril in omegaTendrils.toList()) {
      if (!identical(tendril.owner, ball) && !identical(tendril.target, ball)) {
        continue;
      }
      if (!identical(tendril.target, ball) && _alive(tendril.target)) {
        tendril.target.velocity = tendril.savedVelocity;
      }
      omegaTendrils.remove(tendril);
    }
  }

  void _updateOmegaTendrils() {
    for (final tendril in omegaTendrils.toList()) {
      final target = tendril.target;
      if (!_alive(tendril.owner) || !_alive(target)) {
        if (_alive(target)) target.velocity = tendril.savedVelocity;
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
      target.position += direction * target.radius * tendril.slamOffsetRatio;
      target.velocity =
          direction *
          math.max(tendril.savedVelocity.distance, match.arenaRadius * 0.45) *
          _t.knockback(PowerUpKind.omegaTendrils) *
          tendril.slamVelocityMultiplier;
      final lost = match.damage(
        target,
        _t.arenaDamage(PowerUpKind.omegaTendrils),
        attacker: tendril.owner,
        move: skillName(PowerUpKind.omegaTendrils),
        moveSkill: visualSkill(PowerUpKind.omegaTendrils),
      );
      _showDamage(target, target.position, lost, 0);
      target.hurtFlashLeft = MatchSimulationController.hurtFlashSteps;
      match.state.particles.spawnBlood(
        origin: target.position,
        direction: direction,
        color: match.bloodColor,
        rng: rng,
      );
      _recordExplosion(
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

  /// Remove already-placed skill hazards before any collision or damage pass.
  /// Automatic arena hazards are intentionally governed by their own switch.
  void _clearDisabledSkillTraps() {
    if (_t.skillTrapsEnabled) return;
    mines.clear();
    portals.clear();
    spikeWalls.removeWhere((wall) => !wall.arenaGenerated);
    stickyGoo.clear();
    poisonSwamps.clear();
    for (final ball in _skillGooVictims) {
      _skillGooRemaining.remove(ball);
      final remaining = _t.arenaTrapsEnabled
          ? (_vineSnareRemaining[ball] ?? 0)
          : 0;
      ball.stickyGooLeft = remaining;
      if (remaining == 0) {
        ball.velocity = _gooVelocity.remove(ball) ?? ball.velocity;
      }
    }
    _skillGooVictims.clear();
    for (final effect in damageOverTime.toList()) {
      if (effect.kind != PowerUpKind.poisonSwamp) continue;
      effect.target.poisonLeft = 0;
      effect.target.activeEffectSkillIds.remove(PowerUpKind.poisonSwamp);
      damageOverTime.remove(effect);
    }
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
      final blobs = match.arenaShape == ArenaShape.circle
          ? goo.blobPositions(fieldRadius * 0.36)
          : arenaRimSamples(
              goo.position,
              match.arenaRadius,
              fieldRadius * 0.36,
              15,
              match.arenaShape,
            );
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
        // Preserve the initial velocity and any longer arena snare timer
        // when both independent trap sources immobilize the same ball.
        _gooVelocity.putIfAbsent(ball, () => ball.velocity);
        _skillGooVictims.add(ball);
        _skillGooRemaining[ball] = math.max(
          _skillGooRemaining[ball] ?? 0,
          PowerUpTuning.stickyGooSteps,
        );
        ball
          ..stickyGooLeft = math.max(
            ball.stickyGooLeft,
            PowerUpTuning.stickyGooSteps,
          )
          ..velocity = Offset.zero;
        _sound('trap');
        _yell(ball, 'STUCK!');
        break;
      }
    }
  }

  void _triggerPoisonSwamps() {
    for (final swamp in List<PoisonSwamp>.of(poisonSwamps)) {
      final samples = match.arenaShape == ArenaShape.circle
          ? swamp.samplePositions(fieldRadius * 0.36)
          : arenaRimSamples(
              swamp.position,
              match.arenaRadius,
              fieldRadius * 0.36,
              15,
              match.arenaShape,
            );
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
    target.activeEffectSkillIds[kind == PowerUpKind.poisonSwamp
        ? kind
        : PowerUpKind.molotov] = visualSkill(
      kind,
      ball: owner,
    ).id;
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
        kind: PowerUpKind.spikeWall,
      ),
    );
    if (match.mode == MatchMode.arsenal) {
      final damage = match.damage(
        ball,
        _t.arenaDamage(PowerUpKind.spikeWall),
        move: skillName(PowerUpKind.spikeWall),
        moveSkill: visualSkill(PowerUpKind.spikeWall),
      );
      _showDamage(ball, at, damage, 0);
    } else {
      final cut = match.cutThreads(
        ball,
        _t.allOutThreads(PowerUpKind.spikeWall),
        near: at,
        move: skillName(PowerUpKind.spikeWall),
        moveSkill: visualSkill(PowerUpKind.spikeWall),
      );
      _showDamage(ball, at, cut, 0);
    }
    slashes++;
    _yell(ball, 'OUCH! SPIKES!');
  }

  void _triggerSpikeWalls() {
    if (spikeWalls.isEmpty) return;
    for (final wall in List<SpikeWall>.of(spikeWalls)) {
      final spikes = match.arenaShape == ArenaShape.circle
          ? wall.spikePositions(fieldRadius * 0.96)
          : arenaRimSamples(
              wall.position,
              match.arenaRadius,
              fieldRadius * 0.96,
              wall.spikeCount,
              match.arenaShape,
            );
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
      final push = match.arenaRadius * _t.repulsorForce;
      if (a.repulsorLeft > 0) b.velocity = direction * push;
      if (b.repulsorLeft > 0) a.velocity = -direction * push;
      _yell(a.repulsorLeft > 0 ? a : b, 'BOOM, MOVE!');
    }
    if (a.speedLeft > 0) {
      _hit(b, PowerUpKind.speed, at: b.position, from: a, scaleForCrowd: false);
    }
    if (b.speedLeft > 0) {
      _hit(a, PowerUpKind.speed, at: a.position, from: b, scaleForCrowd: false);
    }
    final heldA = [...a.equippedWeapons];
    final heldB = [...b.equippedWeapons];
    final idsA = [
      if (match.simulationRevision < 2 || a.held != null) a.heldSkillId,
      if (match.simulationRevision < 2 || a.heldSecondary != null)
        a.heldSecondarySkillId,
    ];
    final idsB = [
      if (match.simulationRevision < 2 || b.held != null) b.heldSkillId,
      if (match.simulationRevision < 2 || b.heldSecondary != null)
        b.heldSecondarySkillId,
    ];
    for (var slot = 0; slot < heldA.length; slot++) {
      _melee(a, heldA[slot], b, heldB, skillId: idsA[slot]);
    }
    for (var slot = 0; slot < heldB.length; slot++) {
      _melee(b, heldB[slot], a, heldA, skillId: idsB[slot]);
    }
  }

  void _melee(
    SimulationBall attacker,
    PowerUpKind weapon,
    SimulationBall target,
    List<PowerUpKind> targetHeld, {
    String? skillId,
  }) {
    final composed = _skillForId(weapon, skillId);
    // Physical blades, shields and flails retain their contact-hit semantics
    // even when their custom skill also defines a projectile/aimed behavior.
    // Only composed non-contact carriers use the effect activation path.
    if (SkillHybridContactPolicy.usesComposedContact(composed) &&
        !(weapon.isBlade ||
            weapon == PowerUpKind.shield ||
            weapon == PowerUpKind.orbitingFlail)) {
      // A hybrid aimed-fire weapon can strike on contact as well as shoot.
      // A rejected activation must not destroy an equipped weapon.
      if (!_executeComposed(attacker, composed, primary: target)) return;
      attacker.removeWeapon(
        weapon,
        skillId: match.simulationRevision >= 3 ? skillId : null,
      );
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
    // Save appearance only. The weapon is still consumed immediately, so it
    // cannot hit twice or interfere with a new pickup during the swing.
    final struckSkill = visualSkill(weapon, ball: attacker, skillId: skillId);
    final animation = struckSkill.heldAttackAnimation;
    if (weapon.isBlade &&
        (animation == HeldAttackAnimation.slash ||
            animation == HeldAttackAnimation.thrust ||
            animation == HeldAttackAnimation.throwArc)) {
      attacker.meleeAttackVisual = MeleeAttackVisual(
        kind: weapon,
        skillId: skillId,
        slot:
            attacker.held == weapon &&
                (skillId == null || attacker.heldSkillId == skillId)
            ? 0
            : 1,
        stepsLeft: struckSkill.heldAttackDurationSteps,
        totalSteps: struckSkill.heldAttackDurationSteps,
      );
    }
    attacker.removeWeapon(
      weapon,
      skillId: match.simulationRevision >= 3 ? skillId : null,
    );
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
          kind: kind,
          skillId: skillId,
        ),
      );
    }
    _hit(
      target,
      kind,
      at: at,
      from: attacker,
      skillId: match.simulationRevision >= 2 ? composed.id : null,
    );
  }

  String? _equippedSkillId(SimulationBall ball, PowerUpKind weapon) {
    if (ball.held == weapon) return ball.heldSkillId;
    if (ball.heldSecondary == weapon) return ball.heldSecondarySkillId;
    return null;
  }

  /// True while [ball] is still in the match: not eliminated, and not already at 0 life (Arsenal) or out
  /// of threads (All-Out) earlier in this step, before the elimination check has marked it.
  bool _alive(SimulationBall ball) =>
      !ball.isEliminated &&
      (match.mode == MatchMode.arsenal
          ? ball.life >= 1
          : ball.fanLines.isNotEmpty);

  /// Counts the speed boosts, ghosts and sweeps down, ages blasts; a ball that is out drops its waiting
  /// magnet.
  void _countDown() {
    for (final flash in muzzleArtwork) {
      flash.age++;
    }
    muzzleArtwork.removeWhere(
      (flash) => flash.age >= flash.steps || !_alive(flash.owner),
    );
    for (final effect in castingArtwork) {
      effect.age++;
    }
    castingArtwork.removeWhere(
      (effect) => !_alive(effect.owner) || effect.isFinished,
    );
    for (final e in explosions) {
      e.age++;
    }
    explosions.removeWhere((e) => e.age >= explosionVisualSteps(e));
    for (final impact in weaponImpacts) {
      impact.age++;
    }
    weaponImpacts.removeWhere(
      (impact) => impact.age >= impactVisualSteps(impact),
    );
    if (weaponImpacts.length > 512) {
      weaponImpacts.removeRange(0, weaponImpacts.length - 512);
    }
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
    final radius =
        match.arenaRadius *
        (visualSkill(PowerUpKind.molotov, ball: owner).areaRadiusRatio ??
            _t.blastRadiusRatio);
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
          ball.activeEffectSkillIds[PowerUpKind.molotov] = visualSkill(
            PowerUpKind.molotov,
            ball: fire.owner,
          ).id;
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
      ball.life = math.min(
        _t.arenaMaxLife,
        ball.life + visualSkill(PowerUpKind.apple, ball: ball).healing,
      );
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
    match.state.particles.spawnSparkle(
      origin: ball.position,
      rng: rng,
      displayScale: effectDisplayScale(PowerUpKind.apple, ball: ball),
    );
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
    // Armed skill mines must not continue to damage balls after traps are
    // disabled mid-match. Clear them instead of allowing delayed explosions.
    if (!_t.skillTrapsEnabled) {
      mines.clear();
      return;
    }
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
    final skill = visualSkill(kind);
    final radius =
        match.arenaRadius *
        (skill.areaRadiusRatio ??
            (skill.explodesOnImpact ? skill.range : _t.blastRadiusRatio));
    final balls = match.state.balls;
    blasts++;
    _recordExplosion(
      Explosion(
        position: at,
        radius: radius,
        kind: kind,
        direction: at - owner.position,
      ),
    );
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
            _cutLine(
              ball,
              line,
              move: skillName(kind),
              moveSkill: visualSkill(kind, ball: owner),
              attacker: owner,
            );
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
      _hit(ball, kind, at: side, from: owner);
    }
  }

  /// Turns every held shield toward its biggest threat: the nearest enemy projectile coming at it, else
  /// the nearest opponent. Only shows where it braces; a shield blocks from every side.
  void _turnTrackedItems() {
    for (final ball in match.state.balls) {
      ball.trackingItems
        ..clear()
        ..addAll(
          ball.equippedWeapons.where(
            (kind) => visualSkill(kind, ball: ball).trackNearestOpponent,
          ),
        );
      if (ball.trackingItems.isEmpty || !_alive(ball)) {
        continue;
      }
      final threat = ball.trackingItems.contains(PowerUpKind.shield)
          ? _incoming(ball)?.position ?? _nearestTarget(ball)?.position
          : _nearestTarget(ball)?.position;
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
  void _spawn(
    int number, {
    PowerUpKind? forcedKind,
    String? forcedSkillId,
    bool arenaHazard = false,
  }) {
    // Explicit test spawns obey the same trap policy as ordinary matches.
    if (forcedKind?.isTrap == true &&
        !(arenaHazard ? _t.arenaTrapsEnabled : _t.skillTrapsEnabled)) {
      return;
    }
    // A forced custom skill may be categorized as a trap even if its base
    // pickup kind is not. Reject it before choosing any spawn position.
    if (forcedSkillId != null && !_t.skillTrapsEnabled) {
      final requested = match.skillLibrary.byId(forcedSkillId, _t);
      if (requested != null &&
          (requested.baseKind.isTrap ||
              requested.resolvedCategory == SkillCategory.trap ||
              requested.resolvedCategory == SkillCategory.arenaTrap)) {
        return;
      }
    }
    // Uniform over the chosen kinds; with all of them chosen this draws exactly as with none chosen.
    final chosen = match.powerUpKinds;
    // Custom skills are chosen on their own (null: every active one); one can spawn even when its base
    // weapon is switched off.
    final chosenCustom = match.customSkillIds;
    final spawnableCustom = [
      for (final skill in match.skillLibrary.custom)
        if (skill.spawnsInArena &&
            (_t.skillTrapsEnabled ||
                (skill.resolvedCategory != SkillCategory.trap &&
                    skill.resolvedCategory != SkillCategory.arenaTrap &&
                    !skill.baseKind.isTrap)) &&
            (chosenCustom == null || chosenCustom.contains(skill.id)))
          skill,
    ];
    final kinds = chosen == null || chosen.length == PowerUpKind.values.length
        ? PowerUpKind.values
        : [
            for (final k in PowerUpKind.values)
              if (chosen.contains(k) ||
                  k.isTrap ||
                  spawnableCustom.any((skill) => skill.baseKind == k))
                k,
          ];
    final timedKinds = kinds
        .where(
          (kind) =>
              !kind.isTrap ||
              (_t.skillTrapsEnabled && number >= _t.trapStartSteps),
        )
        .toList();
    final claimedKinds = {for (final pickup in field) pickup.kind};
    final eligibleKinds = timedKinds
        .where((kind) => kind.isTrap || !claimedKinds.contains(kind))
        .toList();
    if (eligibleKinds.isEmpty && forcedKind == null) return;
    // The built-in itself only when it's chosen too (with everything chosen this draws as before).
    bool builtInChosen(PowerUpKind kind) =>
        chosen == null || chosen.contains(kind) || kind.isTrap;
    final SkillDefinition selectedSkill;
    if (forcedSkillId != null) {
      final requested = match.skillLibrary.byId(forcedSkillId, _t);
      if (requested == null || requested.baseKind != forcedKind) {
        throw StateError(
          'The selected test skill is no longer available. Choose it again.',
        );
      }
      selectedSkill = requested;
    } else if (forcedKind == null &&
        PowerUpSpawnSelector.customTiersDiffer(spawnableCustom, _t)) {
      // A custom skill with a tier of its own spawns at that tier's odds.
      selectedSkill = PowerUpSpawnSelector.chooseSkill(
        eligibleKinds,
        _t,
        rng,
        library: match.skillLibrary,
        custom: spawnableCustom,
        builtInChosen: builtInChosen,
      );
    } else {
      // Every custom skill at its base kind's tier: exactly the draws from before custom tiers.
      final kind =
          forcedKind ?? PowerUpSpawnSelector.choose(eligibleKinds, _t, rng);
      final variants = spawnableCustom
          .where((skill) => skill.baseKind == kind)
          .toList();
      final candidates = [
        if (builtInChosen(kind)) match.skillLibrary.builtIn(kind, _t),
        ...variants,
      ];
      selectedSkill = forcedKind == null && variants.isNotEmpty
          ? candidates[rng.nextInt(candidates.length)]
          : match.skillLibrary.builtIn(kind, _t);
    }
    if (!(arenaHazard ? _t.arenaTrapsEnabled : _t.skillTrapsEnabled) &&
        (selectedSkill.baseKind.isTrap ||
            selectedSkill.resolvedCategory == SkillCategory.trap ||
            selectedSkill.resolvedCategory == SkillCategory.arenaTrap)) {
      return;
    }
    final kind = selectedSkill.baseKind;
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
      // For square arenas, project the chosen direction to the square wall
      // instead of placing perimeter traps on an imaginary circular rim.
      final direction = Offset(math.cos(angle), math.sin(angle));
      final squareScale = math.max(direction.dx.abs(), direction.dy.abs());
      final spot = match.arenaShape == ArenaShape.square
          ? direction * (distance / squareScale)
          : direction * distance;
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
      // The center obstacle is solid for pickups as well as projectiles.
      // Reserve the entire pickup footprint, not just its center point.
      final centerExtent = match.arenaRadius * match.centerObstacleScale;
      final centerClearance = centerExtent + radius;
      if (match.centerObstacle == CenterObstacle.circle &&
          spot.distance < centerClearance) {
        continue;
      }
      if (match.centerObstacle == CenterObstacle.square &&
          spot.dx.abs() < centerClearance &&
          spot.dy.abs() < centerClearance) {
        continue;
      }
      if (kind == PowerUpKind.portal) {
        portals.add(ArenaPortal(position: spot, spawnStep: number));
        if (portals.length > PowerUpTuning.maxOnField(_ballCount)) {
          portals.removeAt(0);
        }
        return;
      }
      if (kind == PowerUpKind.spikeWall) {
        spikeWalls.add(
          SpikeWall(
            position: spot,
            angle: angle,
            spawnStep: number,
            arenaGenerated: arenaHazard,
          ),
        );
        // Automatic arena spikes and skill-created spikes have independent
        // quotas. Evicting from the shared list by total length would let
        // one enabled source silently delete the other source's hazards.
        final sourceLimit = PowerUpTuning.maxOnField(_ballCount);
        while (spikeWalls
                .where((wall) => wall.arenaGenerated == arenaHazard)
                .length >
            sourceLimit) {
          spikeWalls.removeAt(
            spikeWalls.indexWhere((wall) => wall.arenaGenerated == arenaHazard),
          );
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
        skillId: selectedSkill.id,
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
      if (ball.stickyGooLeft <= 0 &&
          !_skillGooRemaining.containsKey(ball) &&
          !_vineSnareRemaining.containsKey(ball)) {
        continue;
      }
      final skill = math.max(0, (_skillGooRemaining[ball] ?? 0) - 1);
      final vine = math.max(0, (_vineSnareRemaining[ball] ?? 0) - 1);
      if (skill == 0) {
        _skillGooRemaining.remove(ball);
        _skillGooVictims.remove(ball);
      } else {
        _skillGooRemaining[ball] = skill;
      }
      if (vine == 0) {
        _vineSnareRemaining.remove(ball);
        _vineSnareVictims.remove(ball);
      } else {
        _vineSnareRemaining[ball] = vine;
      }
      // Legacy saves may carry a timer without source bookkeeping.
      final legacy = skill == 0 && vine == 0 && !_gooVelocity.containsKey(ball)
          ? math.max(0, ball.stickyGooLeft - 1)
          : 0;
      ball.stickyGooLeft = math.max(math.max(skill, vine), legacy);
      if (ball.stickyGooLeft == 0) {
        ball.velocity = _gooVelocity.remove(ball) ?? ball.velocity;
      } else {
        ball.velocity = Offset.zero;
      }
    }
  }

  void _updateStunned() {
    if (match.simulationRevision >= 2 &&
        (_cinematicFreezes.isNotEmpty || _otherStuns.isNotEmpty)) {
      _cinematicFreezes.removeWhere(
        (source, _) =>
            !omnislashAttacks.contains(source) &&
            !ragingDemonAttacks.contains(source) &&
            !shadowCloneAttacks.contains(source),
      );
      _cinematicFreezes.updateAll((_, steps) => steps - 1);
      _cinematicFreezes.removeWhere((_, steps) => steps <= 0);
      _otherStuns.updateAll((_, steps) => math.max(0, steps - 1));
      final frozen = _cinematicFreezes.values.fold<int>(0, math.max);
      for (final ball in match.state.balls) {
        final remaining = math.max(frozen, _otherStuns[ball] ?? 0);
        if (ball.stunnedLeft > 0 && remaining == 0) {
          ball.velocity = _stunnedVelocity.remove(ball) ?? ball.velocity;
        }
        ball.stunnedLeft = remaining;
        if (remaining > 0) ball.velocity = Offset.zero;
      }
      if (_cinematicFreezes.isEmpty) _otherStuns.clear();
      return;
    }
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

  /// Stable, obstacle-aware aimed target selection. All-blocked scenarios
  /// fall back to an opponent so the match cannot deadlock behind its wall.
  SimulationBall? _nearestTarget(SimulationBall ball) {
    final previous = _aimedTargets[ball];
    final selected = CombatTargeting.select(
      origin: ball.position,
      candidates: match.state.balls,
      owner: ball,
      previous: previous,
      isEligible: _alive,
      obstacle: match.centerObstacle,
      obstacleExtent: match.arenaRadius * match.centerObstacleScale,
    );
    if (selected == null) {
      _aimedTargets.remove(ball);
    } else {
      if (previous != null && !identical(previous, selected)) {
        targetSwitchCount++;
      }
      _aimedTargets[ball] = selected;
      if (match.centerObstacle != CenterObstacle.none &&
          CombatTargeting.centerObstacleBlocks(
            ball.position,
            selected.position,
            match.centerObstacle,
            match.arenaRadius * match.centerObstacleScale,
          )) {
        blockedTargetFallbackCount++;
      }
    }
    return selected;
  }

  Offset _chosenDirection(SimulationBall owner, [SimulationBall? primary]) {
    if (owner.velocity.distance > 0.001) {
      return owner.velocity / owner.velocity.distance;
    }
    if (primary != null) {
      final delta = primary.position - owner.position;
      if (delta.distance > 0.001) return delta / delta.distance;
    }
    return const Offset(1, 0);
  }

  SimulationBall? _targetInChosenDirection(
    SimulationBall owner,
    SimulationBall? primary,
  ) {
    final direction = _chosenDirection(owner, primary);
    SimulationBall? best;
    var bestScore = -double.infinity;
    for (final target in match.state.balls) {
      if (identical(target, owner) || !_alive(target) || target.isGhost) {
        continue;
      }
      final delta = target.position - owner.position;
      if (delta.distance <= 0.001) continue;
      final unit = delta / delta.distance;
      final alignment = unit.dx * direction.dx + unit.dy * direction.dy;
      if (alignment < 0.5) continue;
      final score = alignment * 100000 - delta.distanceSquared;
      if (score > bestScore) {
        best = target;
        bestScore = score;
      }
    }
    return best;
  }

  SimulationBall? _targetNearArenaLocation(
    SimulationBall owner,
    SimulationBall? primary,
  ) {
    final direction = _chosenDirection(owner, primary);
    final location = direction * match.arenaRadius * 0.72;
    SimulationBall? best;
    var bestDistance = double.infinity;
    for (final target in match.state.balls) {
      if (identical(target, owner) || !_alive(target) || target.isGhost) {
        continue;
      }
      final distance = (target.position - location).distanceSquared;
      if (distance < bestDistance) {
        best = target;
        bestDistance = distance;
      }
    }
    return best;
  }

  List<SimulationBall> _filterDeliveryTargets(
    SimulationBall owner,
    List<SimulationBall> targets,
    SkillDefinition skill,
  ) {
    switch (skill.delivery) {
      case SkillDelivery.aura:
        final radius =
            match.arenaRadius * (skill.areaRadiusRatio ?? skill.range);
        return targets
            .where(
              (target) =>
                  identical(target, owner) ||
                  (target.position - owner.position).distance <= radius,
            )
            .toList();
      case SkillDelivery.orbit:
        final radius =
            match.arenaRadius * (skill.areaRadiusRatio ?? skill.range);
        return targets
            .where(
              (target) =>
                  identical(target, owner) ||
                  (target.position - owner.position).distance <= radius,
            )
            .toList();
      case SkillDelivery.boundaryHazard:
        final bandWidth = match.arenaRadius * skill.range.clamp(0, 1);
        return targets
            .where(
              (target) => inArenaBoundaryBand(
                target.position,
                match.arenaRadius,
                bandWidth,
                match.arenaShape,
              ),
            )
            .toList();
      case SkillDelivery.beam:
        final direction = _chosenDirection(owner, targets.firstOrNull);
        final width = match.arenaRadius * skill.range;
        return targets.where((target) {
          if (identical(target, owner)) return false;
          final delta = target.position - owner.position;
          final along = delta.dx * direction.dx + delta.dy * direction.dy;
          final across = (delta.dx * direction.dy - delta.dy * direction.dx)
              .abs();
          return along > 0 && across <= width;
        }).toList();
      case SkillDelivery.area:
        if (skill.areaRadiusRatio == null) return targets;
        return targets
            .where(
              (target) =>
                  identical(target, owner) ||
                  (target.position - owner.position).distance <=
                      match.arenaRadius * skill.areaRadiusRatio!,
            )
            .toList();
      case SkillDelivery.instant:
      case SkillDelivery.projectile:
      case null:
        return targets;
    }
  }

  /// Fires [skill]. With a [payload] (the skill it fires, from [SkillLibrary.resolvePayload]) every shot
  /// is that skill's projectile: its damage, flight, return, explosion, knockback, size, tint and sound
  /// travel with the shot ([_composedProjectiles]), while [skill] decides how many shots and their spread.
  bool _launchComposed(
    SimulationBall owner,
    SimulationBall target,
    SkillDefinition skill, {
    SkillDefinition? payload,
  }) {
    if (!_allowsSkillActivation(skill) ||
        (payload != null && !_allowsSkillActivation(payload))) {
      return false;
    }
    if (payload != null || skill.delivery == SkillDelivery.projectile) {
      final shotSkill = payload ?? skill;
      final delta = target.position - owner.position;
      final baseDirection = delta.distance == 0
          ? const Offset(1, 0)
          : delta / delta.distance;
      final count = (skill.projectileCount ?? 1).clamp(1, 100);
      final admitted = SkillProjectileBudget.admitted(
        active: _composedProjectiles.length,
        requested: count,
        limit: maxComposedProjectiles,
      );
      if (admitted == 0) return false;
      final spread = skill.spreadDegrees ?? 0;
      var launched = 0;
      for (var index = 0; index < admitted; index++) {
        // One casing per volley (with its first shot, so a capped volley drops none), and only when
        // the firing skill switches shells on (as before: none).
        if (index == 0 && skill.dropsShells) {
          _ejectShellCasing(owner, baseDirection, skill);
        }
        final offset = SkillProjectileBudget.spreadOffset(
          index: index,
          admitted: admitted,
          spreadDegrees: spread,
        );
        final radians =
            math.atan2(baseDirection.dy, baseDirection.dx) +
            offset * math.pi / 180;
        final direction = Offset(math.cos(radians), math.sin(radians));
        final shot = Projectile(
          owner: owner,
          kind: shotSkill.baseKind,
          position: projectileOrigin(
            owner,
            skill.projectileOriginForward != null ? skill : shotSkill,
            (skill.projectileOriginForward != null ||
                    shotSkill.projectileOriginForward != null)
                ? baseDirection
                : direction,
          ),
          velocity:
              direction *
              match.arenaRadius *
              (shotSkill.projectileSpeed ?? _t.bulletSpeedRatio),
          target: shotSkill.homing ? target : null,
          homing: shotSkill.homing,
          returnTo: shotSkill.returnsToOrigin
              ? ((skill.projectileOriginForward != null ||
                        shotSkill.projectileOriginForward != null)
                    ? projectileOrigin(
                        owner,
                        skill.projectileOriginForward != null
                            ? skill
                            : shotSkill,
                        baseDirection,
                      )
                    : owner.position)
              : null,
          renderScale: shotSkill.projectileSize,
          spinDegreesPerSecond: shotSkill.projectileSpin,
        );
        projectiles.add(shot);
        _composedProjectiles[shot] = shotSkill;
        if (payload != null) _composedIssuers[shot] = skill;
        shots++;
        launched++;
      }
      if (launched == 0) return false;
      _announceSkill(owner, skill);
      return true;
    }
    return _executeComposed(owner, skill, primary: target);
  }

  /// Returns true only when an activation was accepted (applied or queued).
  /// Callers that consume a pickup or weapon must honor this result.
  bool _executeComposed(
    SimulationBall owner,
    SkillDefinition skill, {
    SimulationBall? primary,
    List<SimulationBall>? affectedTargets,
    bool projectileImpact = false,
  }) {
    if (!_allowsSkillActivation(skill)) return false;
    final cooldownKey = (owner, skill.id);
    if (!projectileImpact &&
        !SkillActivationGate.isReady(
          match.stepCount,
          _composedCooldownUntil[cooldownKey],
        )) {
      return false;
    }
    var targets = switch (skill.targeting) {
      SkillTargeting.self => [owner],
      SkillTargeting.nearestOpponent => [
        ?primary != null && _alive(primary) ? primary : _nearestTarget(owner),
      ],
      SkillTargeting.allOpponents => [
        for (final target in match.state.balls)
          if (!identical(target, owner) && _alive(target)) target,
      ],
      SkillTargeting.chosenDirection => [
        ?_targetInChosenDirection(owner, primary),
      ],
      SkillTargeting.arenaLocation => [
        ?_targetNearArenaLocation(owner, primary),
      ],
      null => const <SimulationBall>[],
    };
    targets = affectedTargets ?? _filterDeliveryTargets(owner, targets, skill);
    final hasTargetsOrIndependentEffects =
        targets.isNotEmpty ||
        skill.effectSteps.any(
          (step) => step.target != EffectStepTarget.affected,
        );
    final repeatCount =
        match.mayhem &&
            (skill.targeting == SkillTargeting.allOpponents ||
                skill.effectSteps.any(
                  (step) => step.target == EffectStepTarget.allOpponents,
                ))
        ? math.min(skill.repeatCount, maxMayhemAllOpponentRepeats)
        : skill.repeatCount;
    // Reserve repeat capacity before applying the first hit. Otherwise a
    // full queue silently turns a repeating skill into a single-hit skill.
    final needsSchedule = skill.startDelaySeconds > 0 || repeatCount > 1;
    final hasScheduleCapacity =
        !needsSchedule ||
        _scheduledComposedEffects.length < maxScheduledCustomEffects;
    final admitted = projectileImpact
        ? SkillActivationGate.canResolveProjectileImpact(
            hasTargetsOrIndependentEffects: hasTargetsOrIndependentEffects,
            hasScheduleCapacity: hasScheduleCapacity,
          )
        : SkillActivationGate.canActivate(
            currentStep: match.stepCount,
            readyStep: _composedCooldownUntil[cooldownKey],
            hasTargetsOrIndependentEffects: hasTargetsOrIndependentEffects,
            hasScheduleCapacity: hasScheduleCapacity,
          );
    if (!admitted) {
      if (!hasScheduleCapacity) _compositionLimit(owner);
      return false;
    }
    if (skill.startDelaySeconds > 0) {
      if (!projectileImpact && skill.cooldownSeconds > 0) {
        _composedCooldownUntil[cooldownKey] = SkillActivationGate.nextReadyStep(
          match.stepCount,
          skill.cooldownSeconds,
        );
      }
      _scheduledComposedEffects.add(
        _ScheduledComposedEffect(
          owner: owner,
          targets: List.unmodifiable(targets),
          skill: skill,
          repeatsLeft: repeatCount,
          stepsLeft: (skill.startDelaySeconds * 60).round(),
          announceOnNext: true,
          creditSkill: _creditSkill,
        ),
      );
      return true;
    }
    if (!projectileImpact && skill.cooldownSeconds > 0) {
      _composedCooldownUntil[cooldownKey] = SkillActivationGate.nextReadyStep(
        match.stepCount,
        skill.cooldownSeconds,
      );
    }
    _applyComposedEffects(owner, targets, skill);
    if (repeatCount > 1) {
      _scheduledComposedEffects.add(
        _ScheduledComposedEffect(
          owner: owner,
          targets: List.unmodifiable(targets),
          skill: skill,
          repeatsLeft: repeatCount - 1,
          creditSkill: _creditSkill,
          stepsLeft: (skill.repeatIntervalSeconds * 60).round(),
        ),
      );
    }
    _announceSkill(owner, skill);
    return true;
  }

  void _applyComposedEffects(
    SimulationBall owner,
    Iterable<SimulationBall> targets,
    SkillDefinition skill,
  ) {
    if (skill.effectSteps.isNotEmpty) {
      _startEffectSteps(owner, targets.toList(), skill);
      return;
    }
    if ({SkillDelivery.area, SkillDelivery.aura}.contains(skill.delivery)) {
      persistentEffects.area(
        owner,
        skill,
        owner.position,
        match.arenaRadius * (skill.areaRadiusRatio ?? skill.range),
      );
    }
    for (final target in targets) {
      if (!_alive(target)) continue;
      _applyComposedEffect(owner, target, skill, skill.effectType);
      if (skill.secondaryEffectType != null) {
        _applyComposedEffect(
          owner,
          skill.secondaryEffectType == SkillEffectType.heal ? owner : target,
          skill,
          skill.secondaryEffectType,
        );
      }
      // Knockback is an impact parameter, not a standalone effect requirement.
      // Custom/composed skills (including duplicates of built-ins) must honour a
      // configured value even when their primary effect is damage.
      if (skill.knockback > 0 &&
          (skill.effectType == SkillEffectType.damage ||
              skill.effectType == SkillEffectType.damageOverTime ||
              skill.secondaryEffectType == SkillEffectType.damage ||
              skill.secondaryEffectType == SkillEffectType.damageOverTime) &&
          skill.effectType != SkillEffectType.knockback &&
          skill.secondaryEffectType != SkillEffectType.knockback) {
        _applyComposedEffect(owner, target, skill, SkillEffectType.knockback);
      }
      match.state.particles.spawnImpact(
        origin: target.position,
        rng: rng,
        color: Color(skill.effectColor),
        accent: const Color(0xFFFFFFFF),
        count: 7 + (match.skillLibrary.screenShakeFor(skill) * 10).round(),
        displayScale: effectDisplayScaleOf(skill),
      );
      if (match.skillLibrary.screenShakeFor(skill) > 0 ||
          skill.impactSpriteId != null ||
          skill.visualBindings.containsKey(SkillVisualRole.impact)) {
        _recordWeaponImpact(
          WeaponImpact(
            position: target.position,
            target: target,
            direction: target.position - owner.position,
            strength: match.skillLibrary.screenShakeFor(skill),
            kind: skill.baseKind,
            skillId: skill.id,
          ),
        );
      }
    }
  }

  void _compositionLimit(SimulationBall owner) {
    compositionLimitHits++;
    _yell(owner, 'EFFECT LIMIT');
  }

  void _startEffectSteps(
    SimulationBall owner,
    List<SimulationBall> targets,
    SkillDefinition skill,
  ) {
    if (!_alive(owner) || !_allowsSkillActivation(skill)) return;
    final steps = skill.effectSteps;
    var pending = 0;
    var offset = 0;
    for (final step in steps) {
      offset += (step.delaySeconds * 60).round();
      if (offset > 0) pending++;
    }
    if (steps.length > SkillDefinition.maxEffectSteps ||
        _effectStepQueue.length + pending > maxScheduledEffectSteps) {
      _compositionLimit(owner);
      return;
    }
    var delay = 0;
    for (final step in steps) {
      delay += (step.delaySeconds * 60).round();
      final event = _ScheduledEffectStep(
        owner,
        List.unmodifiable(targets),
        skill,
        step,
        match.stepCount + delay,
        _creditSkill,
      );
      if (delay == 0) {
        _runEffectStep(event);
      } else {
        _effectStepQueue.add(event);
      }
    }
  }

  void _updateEffectSteps() {
    for (final event in _effectStepQueue.toList()) {
      if (!_allowsSkillActivation(event.skill)) {
        _effectStepQueue.remove(event);
      } else if (!_alive(event.owner)) {
        _effectStepQueue.remove(event);
      } else if (event.dueStep <= match.stepCount + 1) {
        _effectStepQueue.remove(event);
        _runEffectStep(event);
      }
    }
  }

  void _runEffectStep(_ScheduledEffectStep event) {
    final owner = event.owner;
    // Recheck at execution, including zero-delay steps and policy changes.
    if (!_alive(owner) || !_allowsSkillActivation(event.skill)) return;
    final step = event.step;
    final candidates = switch (step.target) {
      EffectStepTarget.self => [owner],
      EffectStepTarget.affected => event.targets,
      EffectStepTarget.nearestOpponent => [?_nearestTarget(owner)],
      EffectStepTarget.allOpponents => [
        for (final ball in match.state.balls)
          if (!identical(owner, ball)) ball,
      ],
    };
    final targets = candidates
        .where(
          (target) =>
              _alive(target) &&
              (identical(owner, target) || !target.isGhost) &&
              (step.targetRangeRatio == null ||
                  (target.position - owner.position).distance <=
                      match.arenaRadius * step.targetRangeRatio! +
                          target.radius),
        )
        .toSet();
    final previousCredit = _creditSkill;
    _creditSkill = event.creditSkill ?? event.skill;
    try {
      var parameters = step.applyTo(event.skill);
      if ((step.type == SkillEffectType.damage ||
              step.type == SkillEffectType.damageOverTime) &&
          step.knockback == null &&
          event.skill.mechanicalEffects.contains(SkillEffectType.knockback)) {
        parameters = parameters.copyWith(knockback: 0);
      }
      _applyComposedEffects(owner, targets, parameters);
    } finally {
      _creditSkill = previousCredit;
    }
  }

  void _updateScheduledComposedEffects() {
    for (final scheduled in _scheduledComposedEffects.toList()) {
      if (!_allowsSkillActivation(scheduled.skill)) {
        _scheduledComposedEffects.remove(scheduled);
        continue;
      }
      if (!_alive(scheduled.owner)) {
        _scheduledComposedEffects.remove(scheduled);
        continue;
      }
      scheduled.stepsLeft--;
      if (scheduled.stepsLeft > 0) continue;
      final previousCredit = _creditSkill;
      _creditSkill = scheduled.creditSkill;
      _applyComposedEffects(
        scheduled.owner,
        scheduled.targets,
        scheduled.skill,
      );
      _creditSkill = previousCredit;
      if (scheduled.announceOnNext) {
        _announceSkill(scheduled.owner, scheduled.skill);
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
      if (!_allowsSkillActivation(effect.skill)) {
        _customDamageOverTime.remove(effect);
        continue;
      }
      if (!_alive(effect.owner) || !_alive(effect.target)) {
        _customDamageOverTime.remove(effect);
        continue;
      }
      effect.stepsLeft--;
      effect.stepsUntilTick--;
      if (effect.stepsUntilTick <= 0) {
        final previousCredit = _creditSkill;
        _creditSkill = effect.creditSkill;
        _applyComposedEffect(
          effect.owner,
          effect.target,
          effect.skill,
          SkillEffectType.damage,
          dotTick: true,
        );
        _creditSkill = previousCredit;
        effect.stepsUntilTick = (effect.skill.tickIntervalSeconds * 60).round();
      }
      if (effect.stepsLeft <= 0) _customDamageOverTime.remove(effect);
    }
  }

  void _applyComposedEffect(
    SimulationBall owner,
    SimulationBall target,
    SkillDefinition skill,
    SkillEffectType? effect, {
    bool dotTick = false,
  }) {
    final artworkKind = switch (effect) {
      SkillEffectType.speed => PowerUpKind.speed,
      SkillEffectType.freeze => PowerUpKind.freeze,
      SkillEffectType.shield => PowerUpKind.goldenArmor,
      _ => null,
    };
    if (artworkKind != null) {
      target.activeEffectSkillIds[artworkKind] = skill.id;
    }
    if (effect == SkillEffectType.stun) {
      persistentEffects.watch(
        target,
        skill,
        SkillVisualRole.targetStatus,
        () => target.stunnedLeft > 0,
      );
    }
    switch (effect) {
      case SkillEffectType.damage:
        if (match.mode == MatchMode.arsenal) {
          final dealt = match.damage(
            target,
            dotTick
                ? (skill.dotArsenalDamage ?? skill.arsenalDamage ?? 0)
                : (skill.arsenalDamage ?? 0),
            move: (_creditSkill ?? skill).name,
            moveSkill: _creditSkill ?? skill,
            attacker: owner,
          );
          _showDamage(target, target.position, dealt, 0);
        } else {
          final cut = match.cutThreads(
            target,
            dotTick
                ? (skill.dotAllOutDamage ?? skill.allOutDamage ?? 0)
                : (skill.allOutDamage ?? 0),
            near: target.position,
            move: (_creditSkill ?? skill).name,
            moveSkill: _creditSkill ?? skill,
            attacker: owner,
          );
          _showDamage(target, target.position, cut, 0);
        }
      case SkillEffectType.damageOverTime:
        if (_customDamageOverTime.length >= maxCustomDamageOverTimeEffects) {
          _compositionLimit(owner);
          break;
        }
        persistentEffects.watch(
          target,
          skill,
          SkillVisualRole.targetStatus,
          () => _customDamageOverTime.any(
            (e) =>
                identical(e.target, target) &&
                e.skill.id == skill.id &&
                e.stepsLeft > 0,
          ),
        );
        _customDamageOverTime.add(
          _CustomDamageOverTime(
            owner: owner,
            target: target,
            skill: skill,
            creditSkill: _creditSkill,
            stepsLeft: ((skill.durationSeconds ?? 2) * 60).round(),
            stepsUntilTick: (skill.tickIntervalSeconds * 60).round(),
          ),
        );
      case SkillEffectType.heal:
        if (match.mode == MatchMode.arsenal) {
          target.life = math.min(_t.arenaMaxLife, target.life + skill.healing);
        } else {
          match.claimFreeSlots(target, skill.healing.round());
        }
      case SkillEffectType.shield:
        target.goldenArmorHits = math.max(
          target.goldenArmorHits,
          skill.shieldHits,
        );
      case SkillEffectType.freeze:
        target.frozenDamageMultiplierOverride = skill.frozenDamageMultiplier;
        target.frozenCollisionDamageOverride = skill.frozenCollisionDamage;
        if (target.frozenLeft == 0) _frozenVelocity[target] = target.velocity;
        target.frozenLeft = ((skill.durationSeconds ?? 2) * 60).round();
        target.velocity = Offset.zero;
      case SkillEffectType.stun:
        if (target.stunnedLeft == 0) {
          _stunnedVelocity[target] = target.velocity;
        }
        target.stunnedLeft = ((skill.durationSeconds ?? 2) * 60).round();
        if (match.simulationRevision >= 2 && _cinematicFreezes.isNotEmpty) {
          _otherStuns[target] = target.stunnedLeft;
        }
        target.velocity = Offset.zero;
      case SkillEffectType.speed:
        target
          ..speedLeft = ((skill.durationSeconds ?? 2) * 60).round()
          ..speedFactor = skill.effectStrength;
      case SkillEffectType.pull:
        final toward = owner.position - target.position;
        if (toward.distance > 0) {
          target.velocity =
              toward /
              toward.distance *
              match.arenaRadius *
              skill.knockback *
              skill.effectStrength;
        }
      case SkillEffectType.knockback:
        final away = target.position - owner.position;
        if (away.distance > 0) {
          target.velocity =
              away /
              away.distance *
              match.arenaRadius *
              skill.knockback *
              skill.effectStrength;
        }
      case SkillEffectType.teleport:
        _teleport(target, target.position);
      case SkillEffectType.equipCarrier:
        if (skill.baseKind.isWeapon) {
          target.equipWeapon(
            skill.baseKind,
            dualWield: match.dualWield,
            twoHanded: _twoHandedOverride(skill),
            skillId: skill.id,
          );
        }
      case SkillEffectType.disarm:
        target
          ..held = null
          ..heldSecondary = null
          ..heldSkillId = null
          ..heldSecondarySkillId = null
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
          _melee(
            attacker,
            PowerUpKind.orbitingFlail,
            target,
            [...target.equippedWeapons],
            skillId: _equippedSkillId(attacker, PowerUpKind.orbitingFlail),
          );
          break;
        }
      }
    }
  }

  /// Whether [weapon] (resolved as [skill]) strikes on contact: a collision skill, a blade, the
  /// orbiting flail or a shield bash.
  static bool _strikesOnContact(PowerUpKind weapon, SkillDefinition skill) =>
      SkillHybridContactPolicy.usesComposedContact(skill) ||
      weapon.isBlade ||
      weapon == PowerUpKind.orbitingFlail ||
      weapon == PowerUpKind.shield;

  /// Contact weapons with a [SkillDefinition.meleeReach] strike without a bump: once per step, each held
  /// one hits the nearest opponent whose center is within both radii plus that many of the holder's
  /// radii (ties go to the earlier ball), exactly as a bump would ([_melee] uses it up, and a shield
  /// still bashes only an unarmed ball). Like a bump, every strike is chosen from the balls as they
  /// stood before any of them landed, so two balls in each other's reach both hit whatever their order.
  /// Ghosts neither strike nor get struck. A weapon that already struck on a bump this step is gone.
  /// Draws nothing from the RNG.
  void _strikeWithMeleeReach() {
    final standing = [
      for (final ball in match.state.balls)
        if (_alive(ball) && !ball.isGhost) ball,
    ];
    final strikes =
        <
          (
            SimulationBall attacker,
            PowerUpKind weapon,
            String? skillId,
            SimulationBall target,
          )
        >[];
    for (final attacker in standing) {
      final slots = [
        if (attacker.held case final weapon?) (weapon, attacker.heldSkillId),
        if (attacker.heldSecondary case final weapon?)
          (weapon, attacker.heldSecondarySkillId),
      ];
      for (final (weapon, skillId) in slots) {
        final skill = _skillForId(weapon, skillId);
        if (skill.meleeReach <= 0 || !_strikesOnContact(weapon, skill)) {
          continue;
        }
        SimulationBall? nearest;
        var best = double.infinity;
        for (final target in standing) {
          if (identical(attacker, target)) continue;
          final distance = (target.position - attacker.position).distance;
          final reach =
              attacker.radius +
              target.radius +
              skill.meleeReach * attacker.radius;
          if (distance <= reach && distance < best) {
            best = distance;
            nearest = target;
          }
        }
        if (nearest != null) strikes.add((attacker, weapon, skillId, nearest));
      }
    }
    if (strikes.isEmpty) return;
    final heldBefore = {
      for (final ball in standing) ball: [...ball.equippedWeapons],
    };
    for (final (attacker, weapon, skillId, target) in strikes) {
      if (!attacker.equippedWeapons.contains(weapon)) continue;
      _melee(attacker, weapon, target, heldBefore[target]!, skillId: skillId);
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
      final equipped = <({PowerUpKind kind, String? skillId})>[
        if (ball.held != null) (kind: ball.held!, skillId: ball.heldSkillId),
        if (ball.heldSecondary != null)
          (kind: ball.heldSecondary!, skillId: ball.heldSecondarySkillId),
      ];
      final guns = equipped.where((entry) {
        final weapon = entry.kind;
        final skill = _skillForId(weapon, entry.skillId);
        // Composed aimed shots must honor the same per-owner cooldown as
        // composed instant effects. Check before starting the aiming cycle.
        if (skill.isComposed &&
            skill.trigger == SkillTrigger.aimedFire &&
            !SkillActivationGate.isReady(
              match.stepCount,
              _composedCooldownUntil[(ball, skill.id)],
            )) {
          return false;
        }
        final canAim = skill.isComposed
            ? skill.trigger == SkillTrigger.aimedFire
            : weapon.isGun;
        return canAim &&
            (weapon != PowerUpKind.energyWave || energyWaveAttacks.isEmpty) &&
            firedWeaponHoldLeft(ball, weapon, skillId: entry.skillId) == 0;
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
          shellSkill: _burstShellSkill[ball],
        );
        gatlingShots++;
        ball.burstLeft--;
      } else {
        for (final entry in guns) {
          final kind = entry.kind;
          final composed = _skillForId(kind, entry.skillId);
          // A skill that fires another skill (any combination) or a composed aimed skill.
          final payload = match.skillLibrary.resolvePayload(composed, _t);
          if (payload != null ||
              (composed.isComposed &&
                  composed.trigger == SkillTrigger.aimedFire)) {
            // Only commit cooldown and weapon hold after a successful launch.
            // Instant/beam composed skills manage their own cooldown in
            // _executeComposed; pre-setting it would suppress the effect.
            if (_launchComposed(ball, target, composed, payload: payload)) {
              if (composed.isComposed &&
                  composed.trigger == SkillTrigger.aimedFire &&
                  (payload != null ||
                      composed.delivery == SkillDelivery.projectile)) {
                _composedCooldownUntil[(
                  ball,
                  composed.id,
                )] = SkillActivationGate.nextReadyStep(
                  match.stepCount,
                  composed.cooldownSeconds,
                );
              }
              _holdFiredWeapon(ball, kind, skillId: entry.skillId);
            }
            continue;
          }
          _holdFiredWeapon(ball, kind, skillId: entry.skillId);
          switch (kind) {
            case PowerUpKind.shotgun:
              _fireShotgun(ball, target, shellSkill: composed);
              _skillYell(ball, kind, 'BLAM!');
            case PowerUpKind.gatling:
              _burstVolley[ball] = ++_lastVolley;
              _burstShellSkill[ball] = composed;
              _fire(
                ball,
                target,
                kind,
                0,
                shellSkill: composed,
                volley: _lastVolley,
              );
              gatlingShots++;
              ball.burstLeft = _t.gatlingRounds - 1;
              _skillYell(ball, kind, 'RATATAT!');
            case PowerUpKind.freeze:
              _fire(ball, target, kind, 0, shellSkill: composed);
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
                shellSkill: composed,
              );
              _skillYell(ball, kind, 'COME OVER HERE!');
            case PowerUpKind.ricochetDisc:
              _fire(ball, target, kind, 0, shellSkill: composed);
              _skillYell(ball, kind, 'BANK SHOT!');
            case PowerUpKind.threadHarpoon:
              _fire(ball, target, kind, 0, shellSkill: composed);
              _skillYell(ball, kind, 'GIVE IT HERE!');
            case PowerUpKind.prismLaser:
              _fire(ball, target, kind, 0, shellSkill: composed);
              _skillYell(ball, kind, 'TASTE THE RAINBOW!');
            case PowerUpKind.swapCannon:
              _fire(ball, target, kind, 0, shellSkill: composed);
              _skillYell(ball, kind, 'SWAP INCOMING!');
            case PowerUpKind.bow:
              _fireBow(ball, target, shellSkill: composed);
              _skillYell(ball, kind, 'ARROWS, FLY!');
            case PowerUpKind.rocketLauncher:
              _fireRocket(ball, target);
              _skillYell(ball, kind, 'TARGET LOCKED!');
            case PowerUpKind.boomerang:
              _fire(
                ball,
                target,
                kind,
                0,
                shellSkill: composed,
                speedRatio: 0.72,
              );
              _skillYell(ball, kind, 'COMING BACK!');
            case PowerUpKind.fireWall:
              _raiseFireWall(ball, target);
              _skillYell(ball, kind, 'BURNING BARRIER!');
            case PowerUpKind.waterGun:
              _fire(
                ball,
                target,
                kind,
                0,
                shellSkill: composed,
                speedRatio: 1.55,
              );
              _skillYell(ball, kind, 'SPLASH!');
            case PowerUpKind.energyWave:
              _fireEnergyWave(ball, target);
              _skillYell(ball, kind, 'KA-ME-HA-ME-HAAA!');
            case PowerUpKind.flamethrower:
              _startFlamethrower(ball, target);
              _skillYell(ball, kind, 'BURN IT DOWN!');
            case PowerUpKind.sniperRifle:
              _fireSniper(ball, target);
            case PowerUpKind.busterSword:
              _startOmnislash(ball);
            default:
              _fire(ball, target, kind, 0, shellSkill: composed);
              _skillYell(ball, kind, 'BANG!');
          }
          // Guns that don't fire through _fire drop a casing only when their skill says so.
          if (const {
            PowerUpKind.grenade,
            PowerUpKind.molotov,
            PowerUpKind.rocketLauncher,
            PowerUpKind.fireWall,
            PowerUpKind.energyWave,
            PowerUpKind.flamethrower,
            PowerUpKind.sniperRifle,
            PowerUpKind.busterSword,
          }.contains(kind)) {
            _dropShellToward(ball, target, kind, shellSkill: composed);
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

  SkillDefinition _skillForId(PowerUpKind kind, String? id) {
    return id == null
        ? match.skillLibrary.builtIn(kind, _t)
        : match.skillLibrary.byId(id, _t) ??
              match.skillLibrary.builtIn(kind, _t);
  }

  /// A hook caught [target]: a held shield blocks it (and breaks); otherwise [owner] yells and starts
  /// reeling it in. A ball already on a hook isn't caught again.
  void _catch(SimulationBall owner, SimulationBall target) {
    if (!_alive(owner) || !_alive(target) || target.isGhost) return;
    if (target.equippedWeapons.contains(PowerUpKind.shield)) {
      persistentEffects.defense(target, PowerUpKind.shield, broken: true);
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
      slashMarks.add(
        SlashMark(position: at, angle: -math.pi / 2, kind: PowerUpKind.hook),
      );
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
  void _fireShotgun(
    SimulationBall ball,
    SimulationBall target, {
    SkillDefinition? shellSkill,
  }) {
    final count = _t.shotgunPellets;
    final spread = _t.shotgunSpreadRadians;
    final volley = ++_lastVolley;
    final sabotaged = _consumeGremlin(ball);
    _ejectVolleyShell(
      ball,
      target,
      PowerUpKind.shotgun,
      sabotaged,
      shellSkill: shellSkill,
    );
    for (var i = 0; i < count; i++) {
      final edge = i == 0 || i == count - 1;
      final jitter = edge
          ? 0.0
          : rng.nextDoubleRange(-_pelletJitter, _pelletJitter);
      _fire(
        ball,
        target,
        PowerUpKind.shotgun,
        (count == 1 ? 0 : -spread / 2 + spread * i / (count - 1)) + jitter,
        volley: volley,
        sabotaged: sabotaged,
        ejectsShell: false,
      );
    }
  }

  /// One ejection for a whole volley (shotgun, bow), using the held skill's casing count.
  void _ejectVolleyShell(
    SimulationBall ball,
    SimulationBall target,
    PowerUpKind kind,
    bool sabotaged, {
    SkillDefinition? shellSkill,
  }) {
    final skill = shellSkill ?? visualSkill(kind, ball: ball);
    if (!skill.dropsShells) return;
    final toTarget = target.position - ball.position;
    final angle =
        math.atan2(toTarget.dy, toTarget.dx) + (sabotaged ? math.pi : 0);
    _ejectShellCasing(ball, Offset(math.cos(angle), math.sin(angle)), skill);
  }

  void _fireBow(
    SimulationBall ball,
    SimulationBall target, {
    SkillDefinition? shellSkill,
  }) {
    final count = _t.bowArrows;
    final spread = PowerUpTuning.bowSpread(
      (target.position - ball.position).distance,
      match.arenaRadius,
    );
    final volley = ++_lastVolley;
    final sabotaged = _consumeGremlin(ball);
    _ejectVolleyShell(
      ball,
      target,
      PowerUpKind.bow,
      sabotaged,
      shellSkill: shellSkill,
    );
    for (var i = 0; i < count; i++) {
      _fire(
        ball,
        target,
        PowerUpKind.bow,
        count == 1 ? 0 : -spread / 2 + spread * i / (count - 1),
        volley: volley,
        sabotaged: sabotaged,
        ejectsShell: false,
      );
    }
  }

  /// Shared launch geometry for every flying native/composed projectile.
  Offset projectileOrigin(
    SimulationBall owner,
    SkillDefinition skill,
    Offset direction,
  ) {
    final unit = direction.distance == 0
        ? const Offset(1, 0)
        : direction / direction.distance;
    final point =
        owner.position +
        facingOffset(
          unit,
          owner.radius * (skill.projectileOriginForward ?? 1),
          owner.radius *
              (skill.projectileOriginForward == null
                  ? 0
                  : skill.projectileOriginSide),
          mirror: match.simulationRevision >= 4,
        );
    if (skill.projectileOriginForward == null) return point;
    return match.clampToArena(point, inset: 1);
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
        renderScale: visualSkill(
          PowerUpKind.grenade,
          ball: ball,
        ).projectileSize,
        position: projectileOrigin(
          ball,
          visualSkill(PowerUpKind.grenade, ball: ball),
          direction,
        ),
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
        renderScale: visualSkill(
          PowerUpKind.molotov,
          ball: ball,
        ).projectileSize,
        position: projectileOrigin(
          ball,
          visualSkill(PowerUpKind.molotov, ball: ball),
          direction,
        ),
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
        position: projectileOrigin(
          ball,
          visualSkill(PowerUpKind.rocketLauncher, ball: ball),
          direction,
        ),
        velocity: direction * (match.arenaRadius * _t.bulletSpeedRatio * 0.72),
        target: target,
        homing:
            visualSkill(PowerUpKind.rocketLauncher, ball: ball).homing &&
            !sabotaged,
        returnTo:
            visualSkill(PowerUpKind.rocketLauncher, ball: ball).returnsToOrigin
            ? ball.position
            : null,
        renderScale: visualSkill(
          PowerUpKind.rocketLauncher,
          ball: ball,
        ).projectileSize,
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
        _recordWeaponImpact(
          WeaponImpact(position: target.position, strength: 1),
        );
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

  /// Fires one projectile from [ball]'s edge toward [target], turned by [turn] radians. It drops a
  /// shell casing when the held skill does, unless [ejectsShell] is false (a volley ejects one itself,
  /// [_ejectVolleyShell]).
  void _fire(
    SimulationBall ball,
    SimulationBall target,
    PowerUpKind kind,
    double turn, {
    int volley = 0,
    double? speedRatio,
    bool? sabotaged,
    bool ejectsShell = true,
    SkillDefinition? shellSkill,
  }) {
    final toTarget = target.position - ball.position;
    final firesBackward = sabotaged ?? _consumeGremlin(ball);
    final angle =
        math.atan2(toTarget.dy, toTarget.dx) +
        turn +
        (firesBackward ? math.pi : 0);
    final direction = Offset(math.cos(angle), math.sin(angle));
    // The casing follows the firing slot's skill (two variants of one gun can differ).
    final skill = shellSkill ?? visualSkill(kind, ball: ball);
    if (ejectsShell && skill.dropsShells) {
      _ejectShellCasing(ball, direction, skill);
    }
    projectiles.add(
      Projectile(
        owner: ball,
        kind: kind,
        position: projectileOrigin(
          ball,
          skill,
          skill.projectileOriginForward != null
              ? Offset.fromDirection(angle - turn)
              : direction,
        ),
        velocity:
            direction *
            (match.arenaRadius * (speedRatio ?? _t.projectileSpeedRatio(kind))),
        volley: volley,
        target: visualSkill(kind, ball: ball).homing && !firesBackward
            ? target
            : null,
        homing: visualSkill(kind, ball: ball).homing && !firesBackward,
        returnTo: visualSkill(kind, ball: ball).returnsToOrigin
            ? (skill.projectileOriginForward != null
                  ? projectileOrigin(
                      ball,
                      skill,
                      Offset.fromDirection(angle - turn),
                    )
                  : ball.position)
            : null,
        renderScale: visualSkill(kind, ball: ball).projectileSize,
        spinDegreesPerSecond: visualSkill(kind, ball: ball).projectileSpin,
      ),
    );
    _skillSound(kind);
    shots++;
  }

  /// Ejects casings for a gun that doesn't fire through [_fire] (rocket, sniper, grenade and the
  /// like) when its skill switches shells on ([SkillDefinition.shellEnabled]); off by default.
  void _dropShellToward(
    SimulationBall ball,
    SimulationBall target,
    PowerUpKind kind, {
    SkillDefinition? shellSkill,
  }) {
    final skill = shellSkill ?? visualSkill(kind, ball: ball);
    if (!skill.dropsShells) return;
    final toward = target.position - ball.position;
    _ejectShellCasing(
      ball,
      toward.distance == 0 ? const Offset(1, 0) : toward / toward.distance,
      skill,
    );
  }

  /// The resting angle of casing number [sequence] with [SkillDefinition.shellRandomRest]: a pure
  /// integer hash (31-bit masks keep it the same on the web), never an RNG draw.
  static double shellRestAngle(int sequence) {
    var h = (sequence * 40503 + 12345) & 0x7FFFFFFF;
    h = (h ^ ((h & 0x3FFFF) << 13)) & 0x7FFFFFFF;
    h ^= h >> 17;
    h = (h ^ ((h & 0x3FFFFFF) << 5)) & 0x7FFFFFFF;
    h = (h ^ ((h & 0x3FFF) << 17)) & 0x7FFFFFFF;
    h ^= h >> 11;
    return h / 0x7FFFFFFF * 2 * math.pi;
  }

  void _ejectShellCasing(
    SimulationBall ball,
    Offset shotDirection,
    SkillDefinition skill,
  ) {
    final side = Offset(-shotDirection.dy, shotDirection.dx);
    for (var index = 0; index < skill.shellCount.clamp(1, 100); index++) {
      final sequence = _shellSequence++;
      // Preserve the first casing exactly. Extra casings fan out cosmetically,
      // using a stable hash rather than consuming simulation RNG draws.
      final phase = index == 0 ? 0.0 : shellRestAngle(sequence);
      final scatter = index == 0
          ? Offset.zero
          : Offset(math.cos(phase), math.sin(phase)) * ball.radius * .65;
      shellCasings.add(
        ShellCasing(
          position: ball.position + side * ball.radius * 0.55,
          velocity:
              side * ball.radius * 1.8 - Offset(0, ball.radius * 1.4) + scatter,
          angle: math.atan2(side.dy, side.dx) + (index == 0 ? 0 : phase * .15),
          spriteId: skill.shellSprite,
          size: skill.shellSize,
          randomRest: skill.shellRandomRest,
          sequence: sequence,
        ),
      );
    }
    if (shellCasings.length > maxShellCasings) {
      shellCasings.removeRange(0, shellCasings.length - maxShellCasings);
    }
  }

  void _updateShellCasings() {
    const dt = 1 / 60.0;
    final radius = match.arenaRadius;
    for (final casing in shellCasings) {
      // Settled casings must follow live arena-shape and radius changes too.
      // Otherwise a casing deposited on the circular rim remains on that arc
      // after the arena becomes square (and vice versa).
      if (!casing.settled) {
        casing.velocity += Offset(0, radius * 1.8 * dt);
        casing.position += casing.velocity * dt;
        casing.angle += 7.5 * dt;
      }
      final x = casing.position.dx.clamp(-radius + 2, radius - 2).toDouble();
      final floorY = match.arenaShape == ArenaShape.square
          ? radius - 2
          : math.sqrt(math.max(0, radius * radius - x * x)) - 2;
      if (casing.settled) {
        // Preserve its horizontal landing location and resting orientation.
        // Only its floor position changes with the arena geometry.
        casing.position = Offset(x, floorY);
      } else if (casing.position.dy >= floorY) {
        casing
          ..position = Offset(x, floorY)
          ..velocity = Offset.zero
          ..settled = true;
        if (casing.randomRest) {
          casing.angle = shellRestAngle(casing.sequence);
        }
      }
    }
  }

  // Compute a finite distance without squaring unscaled coordinates. This is
  // also used for homing target selection, where distanceSquared can overflow
  // even though both candidate coordinates are finite.
  static double _safeVectorLength(Offset vector) {
    final largest = math.max(vector.dx.abs(), vector.dy.abs());
    if (largest == 0) return 0;
    if (!largest.isFinite) return double.infinity;
    final x = vector.dx / largest;
    final y = vector.dy / largest;
    return largest * math.sqrt(x * x + y * y);
  }

  static Offset? _safeUnitVector(Offset vector) {
    final largest = math.max(vector.dx.abs(), vector.dy.abs());
    if (largest == 0 || !largest.isFinite) return null;
    final scaled = vector / largest;
    final length = math.sqrt(scaled.dx * scaled.dx + scaled.dy * scaled.dy);
    return scaled / length;
  }

  /// Moves every projectile one step. A projectile strikes the first ball (not its owner, not out, not a
  /// ghost) its path enters and is spent, or is spent at the rim. In All-Out it also cuts the opponent
  /// threads its path crosses on the way.
  void _moveProjectiles() {
    if (projectiles.isEmpty) {
      // Other systems may clear the collection without marking each projectile
      // spent. Do not retain dangling composed-skill metadata.
      _composedProjectiles.clear();
      _composedIssuers.clear();
      return;
    }
    final balls = match.state.balls;
    final allOut = match.mode == MatchMode.allOut;
    final spawned = <Projectile>[];
    for (final p in projectiles) {
      if (p.spent) continue;
      p.visualAge++;
      // A ricocheting or returning projectile can otherwise survive forever.
      // Invalid coordinates can also poison collision calculations and paints.
      // Mark these as spent here so the common cleanup prunes their skill and
      // issuer metadata at the end of this simulation step.
      if (p.visualAge > maxProjectileFlightSteps ||
          !p.position.dx.isFinite ||
          !p.position.dy.isFinite ||
          !p.velocity.dx.isFinite ||
          !p.velocity.dy.isFinite) {
        p.spent = true;
        continue;
      }
      final from = p.position;
      final composedSkill = _composedProjectiles[p];
      // A composed trap fired before a setting change must not remain an
      // invisible collision/cutting hazard. Retire the projectile and let
      // normal cleanup discard its associated skill/issuer metadata.
      // Ordinary weapon projectiles are deliberately unaffected.
      // The firing skill and the carried payload have independent trap
      // classifications. A non-trap payload fired by a trap issuer (or the
      // reverse) must not bypass a mid-match policy change.
      final issuerSkill = _composedIssuers[p];
      if ((composedSkill != null && !_allowsSkillActivation(composedSkill)) ||
          (issuerSkill != null && !_allowsSkillActivation(issuerSkill))) {
        p.spent = true;
        continue;
      }
      if (p.homing) {
        var target = p.target;
        // A persistent homing shot must not keep steering toward a ball it
        // already contacted. Select the nearest eligible opponent from the
        // projectile's current position, not the owner's position.
        if (target == null ||
            !_alive(target) ||
            target.isGhost ||
            identical(target, p.owner) ||
            p.hitTargets.contains(target) ||
            !target.position.dx.isFinite ||
            !target.position.dy.isFinite) {
          target = CombatTargeting.select(
            origin: from,
            candidates: balls,
            owner: p.owner,
            isEligible: _alive,
            excluded: p.hitTargets,
            // A projectile already in flight uses its current position;
            // avoid changing homing trajectory rules based on wall visibility.
            preferClearLine: false,
          );
          if (target != null) homingRetargetCount++;
          p.target = target;
        }
        if (target != null &&
            target.position.dx.isFinite &&
            target.position.dy.isFinite) {
          final toward = target.position - from;
          final direction = _safeUnitVector(toward);
          if (direction != null) {
            final speed =
                composedSkill != null && composedSkill.effectSteps.isNotEmpty
                ? _safeVectorLength(p.velocity)
                : match.arenaRadius * _t.bulletSpeedRatio * 0.72;
            // An overflowing speed is not a valid steering command. Leave the
            // original velocity to the existing invalid-state retirement path.
            if (speed.isFinite) p.velocity = direction * speed;
          }
        }
      }
      final returnsToOrigin =
          composedSkill?.returnsToOrigin ?? visualSkill(p.kind).returnsToOrigin;
      if (returnsToOrigin && p.returning) {
        final returnSpot = p.returnTo ?? p.owner.position;
        // Returning shots can cross very large finite coordinates. Ordinary
        // Offset.distance overflows while both components remain finite.
        // Reject invalid destinations and use scaled vector math for steering.
        if (!returnSpot.dx.isFinite || !returnSpot.dy.isFinite) {
          p.spent = true;
          continue;
        }
        final home = returnSpot - from;
        final homeDistance = _safeVectorLength(home);
        if (!homeDistance.isFinite) {
          p.spent = true;
          continue;
        }
        if (homeDistance <= p.owner.radius * 1.15) {
          p.position = returnSpot;
          p.spent = true;
          continue;
        }
        final direction = _safeUnitVector(home);
        if (direction == null) {
          p.spent = true;
          continue;
        }
        p.velocity =
            direction *
            (composedSkill != null && composedSkill.effectSteps.isNotEmpty
                ? match.arenaRadius *
                      (composedSkill.projectileSpeed ?? _t.bulletSpeedRatio)
                : match.arenaRadius * .72);
      }
      // Steering may replace the velocity (homing and returning shots).
      // Validate the resulting state before it enters swept collision math.
      if (!p.velocity.dx.isFinite ||
          !p.velocity.dy.isFinite ||
          !p.position.dx.isFinite ||
          !p.position.dy.isFinite) {
        p.spent = true;
        continue;
      }
      var projectileScale = 1.0;
      for (final ball in balls) {
        if (ball.timeBubbleLeft > 0 &&
            !identical(ball, p.owner) &&
            ball.position.dx.isFinite &&
            ball.position.dy.isFinite &&
            _safeVectorLength(from - ball.position) <
                ball.radius * _t.timeBubbleRange) {
          projectileScale = 0.35;
        }
      }
      final to =
          from +
          p.velocity *
              MatchSimulationController.fixedTimestep *
              projectileScale;

      // Even finite components can overflow during integration (for example,
      // a corrupted velocity near double.maxFinite). Retire only that shot;
      // never let a non-finite segment enter swept intersections or rendering.
      if (!to.dx.isFinite || !to.dy.isFinite) {
        p.spent = true;
        continue;
      }

      projectileSweepCount++;
      // Compute thrown-projectile landing time before any collision resolution.
      // A landing point in front of a center wall must detonate before that
      // wall, while a wall in front of the landing point must still block it.
      // This also prevents a target beyond the landing point from preempting
      // the intended landing event.
      final landAt = p.landAt;
      double? landingT;
      if (landAt != null) {
        if (!landAt.dx.isFinite || !landAt.dy.isFinite) {
          p.spent = true;
          continue;
        }
        landingT = _landingEntry(
          from,
          to,
          landAt,
          projectileCollisionRadius(p),
        );
      }

      // Find the first eligible ball along the swept segment before resolving
      // geometry. An obstacle must not steal an impact that occurs in front of
      // it, even when a fast projectile crosses both in one simulation step.
      SimulationBall? struck;
      var strikeAt = double.infinity;
      for (final ball in balls) {
        if (identical(ball, p.owner) ||
            ball.isEliminated ||
            ball.isGhost ||
            // Every projectile respects its per-flight hit history. This is
            // especially important after reflection: the new owner is marked
            // as already contacted, even for ordinary non-returning bullets.
            p.hitTargets.contains(ball) ||
            !ball.position.dx.isFinite ||
            !ball.position.dy.isFinite) {
          continue;
        }
        final t = _entry(
          from,
          to,
          ball.position,
          ball.magneticFieldLeft > 0 &&
                  !ball.magneticReflectedOwners.contains(p.owner)
              ? ball.radius * 2
              : ball.radius + projectileCollisionRadius(p),
        );
        // Resolve simultaneous/overlapping contacts by stable contestant ID,
        // not mutable list order. Strictly earlier contacts still win; do not
        // use an epsilon that could promote a physically later target.
        if (t != null &&
            (t < strikeAt ||
                (t == strikeAt &&
                    struck != null &&
                    ball.config.id.compareTo(struck.config.id) < 0))) {
          struck = ball;
          strikeAt = t;
        }
      }

      // The center wall blocks shots only when its entry precedes a ball hit.
      // Only outer-wall impacts can grant threads.
      final obstacle = match.centerObstacle;
      double? obstacleContactT;
      Offset? obstacleContactNormal;
      if (obstacle != CenterObstacle.none) {
        final extent = match.arenaRadius * match.centerObstacleScale;
        final delta = to - from;
        double? hitT;
        Offset? normal;
        if (obstacle == CenterObstacle.circle) {
          final bound = extent + projectileCollisionRadius(p);
          // Shots spawned inside the center obstacle must be allowed to exit;
          // treating their starting overlap as an incoming wall hit traps them.
          // A shot exactly on the rim only collides if it is travelling
          // inward. Outward-moving shots must be allowed to escape.
          // Compare lengths rather than squared coordinates: both the
          // projectile position and obstacle radius may be large but finite.
          // At the rim, only inward travel counts as a new wall impact.
          final startRadius = _safeVectorLength(from);
          final radialUnit = _safeUnitVector(from);
          final travelUnit = _safeUnitVector(delta);
          final inwardAtRim =
              radialUnit != null &&
              travelUnit != null &&
              radialUnit.dx * travelUnit.dx + radialUnit.dy * travelUnit.dy < 0;
          if (startRadius > bound || (startRadius == bound && inwardAtRim)) {
            hitT = _entry(from, to, Offset.zero, bound);
          }
          if (hitT != null) {
            final contact = from + delta * hitT;
            normal = _safeUnitVector(contact) ?? const Offset(1, 0);
          }
        } else {
          final bound = extent + projectileCollisionRadius(p);
          // Slab intersection finds the first entered face, including fast shots.
          var entry = 0.0;
          var exit = 1.0;
          Offset? entryNormal;
          var intersects = true;
          for (var axis = 0; axis < 2; axis++) {
            final start = axis == 0 ? from.dx : from.dy;
            final speed = axis == 0 ? delta.dx : delta.dy;
            if (speed.abs() < 1e-9) {
              if (start.abs() > bound) intersects = false;
              continue;
            }
            final t1 = (-bound - start) / speed;
            final t2 = (bound - start) / speed;
            final near = math.min(t1, t2);
            final far = math.max(t1, t2);
            // Starting exactly on a face and moving inward is a valid
            // t=0 collision. The previous strict comparison skipped it.
            // Keep outward and inside-origin shots free to leave.
            if (near > entry ||
                (near == entry &&
                    entryNormal == null &&
                    start.abs() >= bound &&
                    start * speed < 0)) {
              entry = near;
              entryNormal = axis == 0
                  ? Offset(speed > 0 ? -1 : 1, 0)
                  : Offset(0, speed > 0 ? -1 : 1);
            }
            exit = math.min(exit, far);
          }
          if (intersects &&
              entry <= exit &&
              entryNormal != null &&
              entry >= 0 &&
              entry <= 1) {
            hitT = entry;
            normal = entryNormal;
          }
        }
        obstacleContactT = hitT;
        obstacleContactNormal = normal;
        if (hitT != null &&
            normal != null &&
            hitT >= 0 &&
            hitT <= 1 &&
            hitT <= strikeAt &&
            (landingT == null || hitT <= landingT)) {
          p.position = from + delta * hitT + normal * 0.1;
          final dot = p.velocity.dx * normal.dx + p.velocity.dy * normal.dy;
          p.velocity -= normal * (2 * dot);
          p.wallBounces++;
          projectileCenterWallBounceCount++;
          // Avoid indefinite ricochets in enclosed geometries.
          if (p.wallBounces > 8) p.spent = true;
          continue;
        }
      }

      var end = struck == null ? to : Offset.lerp(from, to, strikeAt)!;
      if (landAt != null) {
        final landed = landingT != null && landingT <= strikeAt;
        if (landed) {
          struck = null;
          end = landAt;
        }
        if ((struck != null && !landed) ||
            landed ||
            match.touchesOuterBoundary(end)) {
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
              _cutLine(
                ball,
                line,
                move: skillName(p.kind),
                moveSkill: projectileVisualSkill(p),
                attacker: p.owner,
              );
            }
          }
        }
      }

      p.position = end;
      // Retain the original attacker to detect a reflection: subsequent
      // contacts must never be resolved on the reflected trajectory.
      final ownerAtContact = p.owner;
      if (struck != null) {
        if (struck.magneticFieldLeft > 0 &&
            struck.magneticReflectedOwners.contains(p.owner)) {
          p.spent = true;
          continue;
        }
        if (struck.magneticFieldLeft > 0 || struck.mirrorCharges > 0) {
          // A reflected shot has contacted this defender, but ownership
          // transfer resets the history to the new owner for the return leg.
          // Contact normals must remain finite even for very large coordinates.
          // At an exact center hit, use the incoming direction as the normal
          // so the reflected shot separates on the entry side of the defender.
          final normal = end - struck.position;
          final incoming = _safeUnitVector(p.velocity);
          final unit =
              _safeUnitVector(normal) ??
              (incoming == null ? const Offset(1, 0) : -incoming);
          final along = p.velocity.dx * unit.dx + p.velocity.dy * unit.dy;
          p.velocity = p.velocity - unit * (2 * along);
          p.position += unit * 2;
          if (struck.mirrorCharges > 0 && struck.magneticFieldLeft == 0) {
            persistentEffects.defense(
              struck,
              PowerUpKind.mirror,
              broken: struck.mirrorCharges == 1,
            );
            struck.mirrorCharges--;
          }
          if (struck.magneticFieldLeft > 0) {
            persistentEffects.defense(struck, PowerUpKind.magneticField);
            struck.magneticReflectedOwners.add(p.owner);
          }
          p.transferOwnership(struck, returnsToOrigin: returnsToOrigin);
          // The reflector is now the attacker. The original firing skill
          // must not receive credit for damage inflicted by the reflector.
          _composedIssuers.remove(p);
          _yell(struck, 'RETURN TO SENDER!');
          continue;
        }
        // Record every accepted physical contact, not only composed or
        // returning skills. This prevents a persistent or ricocheting shot
        // from re-damaging a target it has already passed through.
        p.hitTargets.add(struck);
        projectileContactCount++;
        final composed = _composedProjectiles[p];
        _creditSkill = _composedIssuers[p];
        p.spent = !returnsToOrigin;
        if (p.kind == PowerUpKind.hook &&
            (composed == null || composed.effectSteps.isEmpty)) {
          _catch(p.owner, struck);
        } else {
          if (composed != null) {
            // Resolve the skill before spending the projectile or creating
            // cosmetic explosions. A rejected activation must not consume a
            // composed weapon or produce a misleading impact effect.
            final blastRadius =
                match.arenaRadius *
                (composed.areaRadiusRatio ?? composed.range);
            final blastTargets = composed.explodesOnImpact
                ? balls
                      .where(
                        (ball) =>
                            !identical(ball, p.owner) &&
                            _alive(ball) &&
                            (ball.position - end).distance <=
                                blastRadius + ball.radius,
                      )
                      .toList()
                : null;
            final accepted = composed.explodesOnImpact
                ? _executeComposed(
                    p.owner,
                    composed,
                    affectedTargets: blastTargets,
                    projectileImpact: true,
                  )
                : _executeComposed(
                    p.owner,
                    composed,
                    primary: struck,
                    projectileImpact: true,
                  );
            if (!accepted) {
              p.spent = false;
              // Keep the projectile alive but ignore this target on future
              // steps; otherwise a stationary projectile can retry every frame.
              p.hitTargets.add(struck);
              p.position += p.velocity.distance == 0
                  ? Offset.zero
                  : p.velocity / p.velocity.distance * 2;
              _creditSkill = null;
              continue;
            }
            if (composed.explodesOnImpact) {
              blasts++;
              _sound(
                composed.soundCue == 'default' ? 'bomb' : composed.soundCue,
              );
              _recordExplosion(
                Explosion(
                  position: end,
                  direction: p.velocity,
                  radius: blastRadius,
                  kind: composed.baseKind,
                  skillId: composed.id,
                ),
              );
              final shake = match.skillLibrary.screenShakeFor(composed);
              if (shake > 0) {
                _recordWeaponImpact(
                  WeaponImpact(position: end, strength: shake),
                );
              }
            }
            p.hitTargets.add(struck);
            if (composed.returnsToOrigin) {
              p.returning = true;
              p.spent = false;
            } else {
              _composedProjectiles.remove(p);
              _composedIssuers.remove(p);
            }
          } else {
            if (visualSkill(p.kind).explodesOnImpact) {
              _explode(end, p.owner, p.kind);
              _sound(visualSkill(p.kind).soundCue);
            } else {
              _hit(
                struck,
                p.kind,
                at: end,
                hitDirection: p.velocity,
                from: p.owner,
                volley: p.volley,
              );
            }
          }
          _creditSkill = null;
          if (returnsToOrigin) {
            p.hitTargets.add(struck);
            // A stationary returning projectile has no valid direction to
            // separate along. Retire it instead of introducing NaN positions.
            final speed = p.velocity.distance;
            if (speed > 0 && speed.isFinite) {
              p.position += p.velocity / speed * 2;
            } else {
              p.spent = true;
            }
          }
          if (p.kind == PowerUpKind.rocketLauncher &&
              (composedSkill == null || composedSkill.effectSteps.isEmpty)) {
            _recordExplosion(
              Explosion(
                position: end,
                radius: match.arenaRadius * PowerUpTuning.blastRadiusRatio,
                kind: PowerUpKind.rocketLauncher,
                direction: p.velocity,
              ),
            );
          }
        }
        // Piercing policy: only shots explicitly configured to return to
        // their owner may contact further targets on this sweep. Ordinary
        // non-returning bullets stop at their first accepted target; bounce
        // count and visual effects do not imply target piercing.
        // A returning, non-explosive projectile is persistent. The first
        // contact above has already run its normal damage/skill/reflection
        // handling. Resolve further contacts in this same swept segment in
        // physical order, rather than deferring them to the next frame (when
        // the projectile may already have passed through those opponents).
        //
        // The center obstacle is a hard cutoff for subsequent contacts.
        // A contact before the wall is still valid; a target beyond the
        // wall must not receive damage during this step.
        if (returnsToOrigin &&
            !p.spent &&
            identical(ownerAtContact, p.owner) &&
            !(composedSkill?.explodesOnImpact ?? false) &&
            !visualSkill(p.kind).explodesOnImpact) {
          final remaining = <(double, SimulationBall)>[];
          for (final candidate in balls) {
            if (identical(candidate, p.owner) ||
                candidate.isEliminated ||
                candidate.isGhost ||
                p.hitTargets.contains(candidate) ||
                !candidate.position.dx.isFinite ||
                !candidate.position.dy.isFinite) {
              continue;
            }
            // Match the primary swept-contact geometry: an unused magnetic
            // field intercepts a shot at twice the defender radius. Without
            // this, a shielded second target could be skipped at high speed.
            final contactRadius =
                candidate.magneticFieldLeft > 0 &&
                    !candidate.magneticReflectedOwners.contains(p.owner)
                ? candidate.radius * 2
                : candidate.radius + projectileCollisionRadius(p);
            final t = _entry(from, to, candidate.position, contactRadius);
            // Equal-time contacts are legitimate: overlapping defenders can
            // share the exact first swept entry. The first defender has
            // already been recorded in hitTargets above, so accepting equality
            // here cannot damage it twice. Stable IDs order the remaining
            // simultaneous contacts independently of the contestants list.
            if (t != null &&
                t >= strikeAt &&
                t <= 1 &&
                (obstacleContactT == null || t < obstacleContactT)) {
              remaining.add((t, candidate));
            }
          }
          remaining.sort((a, b) {
            final byTime = a.$1.compareTo(b.$1);
            return byTime != 0
                ? byTime
                : a.$2.config.id.compareTo(b.$2.config.id);
          });
          // Each ball is considered once, and the number of contacts is
          // bounded by the number of contestants in this match.
          var blockedByDefense = false;
          // All-Out threads must be cut along the entire traversed sweep,
          // not just the initial segment ending at the first defender. Only
          // visit segments actually travelled: a reflector or center wall
          // terminates the outgoing path immediately.
          var lastThreadContact = end;
          void cutTraversedThreads(Offset next) {
            if (!allOut ||
                p.kind == PowerUpKind.hook ||
                _composedProjectiles.containsKey(p)) {
              return;
            }
            if (lastThreadContact == next) return;
            for (final threadOwner in balls) {
              if (identical(threadOwner, p.owner) ||
                  threadOwner.isEliminated ||
                  threadOwner.isGhost) {
                continue;
              }
              for (final line in List.of(threadOwner.fanLines)) {
                if (_crosses(
                  lastThreadContact,
                  next,
                  line.startPoint,
                  threadOwner.position,
                )) {
                  _cutLine(
                    threadOwner,
                    line,
                    move: skillName(p.kind),
                    moveSkill: projectileVisualSkill(p),
                    attacker: p.owner,
                  );
                }
              }
            }
            lastThreadContact = next;
          }

          for (final (t, candidate) in remaining) {
            if (p.spent || !identical(ownerAtContact, p.owner)) break;
            // Contacts are gathered before any damage is applied. Earlier
            // hits (including composed effects) can eliminate or otherwise
            // invalidate a later candidate during this same simulation step.
            // Recheck live state and history at dispatch time rather than
            // applying a stale contact from the initial swept snapshot.
            if (!_alive(candidate) ||
                candidate.isGhost ||
                identical(candidate, p.owner) ||
                p.hitTargets.contains(candidate) ||
                !candidate.position.dx.isFinite ||
                !candidate.position.dy.isFinite) {
              continue;
            }
            final contact = Offset.lerp(from, to, t)!;
            cutTraversedThreads(contact);
            if (candidate.magneticFieldLeft > 0 ||
                candidate.mirrorCharges > 0) {
              // Resolve defense at the actual swept contact, not in the next
              // frame: waiting lets the projectile move through the defender
              // or miss the reflection when the segment was very fast.
              p.position = contact;
              if (candidate.magneticFieldLeft > 0 &&
                  candidate.magneticReflectedOwners.contains(p.owner)) {
                p.spent = true;
              } else {
                final incoming = _safeUnitVector(p.velocity);
                final unit =
                    _safeUnitVector(contact - candidate.position) ??
                    (incoming == null ? const Offset(1, 0) : -incoming);
                final along = p.velocity.dx * unit.dx + p.velocity.dy * unit.dy;
                p.velocity -= unit * (2 * along);
                p.position += unit * 2;
                if (candidate.mirrorCharges > 0 &&
                    candidate.magneticFieldLeft == 0) {
                  persistentEffects.defense(
                    candidate,
                    PowerUpKind.mirror,
                    broken: candidate.mirrorCharges == 1,
                  );
                  candidate.mirrorCharges--;
                }
                if (candidate.magneticFieldLeft > 0) {
                  persistentEffects.defense(
                    candidate,
                    PowerUpKind.magneticField,
                  );
                  candidate.magneticReflectedOwners.add(p.owner);
                }
                p.transferOwnership(
                  candidate,
                  returnsToOrigin: returnsToOrigin,
                );
                _composedIssuers.remove(p);
                _yell(candidate, 'RETURN TO SENDER!');
              }
              blockedByDefense = true;
              break;
            }
            p.hitTargets.add(candidate);
            final composed = _composedProjectiles[p];
            if (composed != null) {
              _creditSkill = _composedIssuers[p];
              final accepted = _executeComposed(
                p.owner,
                composed,
                primary: candidate,
                projectileImpact: true,
              );
              _creditSkill = null;
              if (!accepted) continue;
            } else if (p.kind == PowerUpKind.hook) {
              _catch(p.owner, candidate);
            } else {
              _hit(
                candidate,
                p.kind,
                at: contact,
                hitDirection: p.velocity,
                from: p.owner,
                volley: p.volley,
              );
            }
          }
          if (!blockedByDefense && !p.spent) {
            // Do not cut threads beyond a center obstacle, even when a fast
            // projectile's nominal endpoint lies on the opposite side.
            final threadEnd =
                obstacleContactT != null &&
                    obstacleContactNormal != null &&
                    obstacleContactT > strikeAt &&
                    obstacleContactT <= 1
                ? Offset.lerp(from, to, obstacleContactT)!
                : to;
            cutTraversedThreads(threadEnd);
            if (obstacleContactT != null &&
                obstacleContactNormal != null &&
                obstacleContactT > strikeAt &&
                obstacleContactT <= 1) {
              final normal = obstacleContactNormal;
              p.position = from + (to - from) * obstacleContactT + normal * 0.1;
              final dot = p.velocity.dx * normal.dx + p.velocity.dy * normal.dy;
              p.velocity -= normal * (2 * dot);
              p.wallBounces++;
              projectileCenterWallBounceCount++;
              if (p.wallBounces > 8) p.spent = true;
              continue;
            }
            p.position = to;
            if (match.touchesOuterBoundary(to)) {
              p.position = match.clampToArena(to);
              p.returning = true;
            }
          }
        }
      } else if (match.touchesOuterBoundary(end) &&
          (p.kind != PowerUpKind.rocketLauncher || !p.homing)) {
        final composed = _composedProjectiles[p];
        if (returnsToOrigin) {
          p
            ..position = match.clampToArena(end)
            ..returning = true;
        } else if ((p.kind == PowerUpKind.ricochetDisc ||
                p.kind == PowerUpKind.prismLaser ||
                composed != null ||
                _t.maxBounces(p.kind) > 0) &&
            p.wallBounces < (composed?.maxBounces ?? _t.maxBounces(p.kind))) {
          final normal = match.outerWallNormal(end);
          final along = p.velocity.dx * normal.dx + p.velocity.dy * normal.dy;
          p
            ..position = match.clampToArena(end)
            ..velocity -= normal * (2 * along);
          p.wallBounces++;
          if (p.kind == PowerUpKind.prismLaser &&
              (composedSkill == null || composedSkill.effectSteps.isEmpty)) {
            for (final turn in [-0.32, 0.32]) {
              final angle = math.atan2(p.velocity.dy, p.velocity.dx) + turn;
              spawned.add(
                Projectile(
                  owner: p.owner,
                  kind: PowerUpKind.prismLaser,
                  renderScale: p.renderScale,
                  spinDegreesPerSecond: p.spinDegreesPerSecond,
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
    // A projectile can be removed by other systems without being marked spent.
    // Prune both maps against the actual live projectile collection.
    projectiles.removeWhere((p) => p.spent);
    final liveProjectiles = projectiles.toSet();
    _composedProjectiles.removeWhere(
      (projectile, _) => !liveProjectiles.contains(projectile),
    );
    _composedIssuers.removeWhere(
      (projectile, _) => !liveProjectiles.contains(projectile),
    );
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
    Offset? hitDirection,
    SimulationBall? from,
    int volley = 0,
    bool unavoidable = false,
    bool scaleForCrowd = true,
    String? skillId,
  }) {
    if (target.isGhost && !unavoidable) return;
    if (target.magneticFieldLeft > 0 && !unavoidable) {
      persistentEffects.defense(target, PowerUpKind.magneticField);
      _sound('repel');
      _yell(target, 'REPELLED!');
      return;
    }
    hits++;
    target.hurtFlashLeft = MatchSimulationController.hurtFlashSteps;
    final impact = at ?? target.position;
    final (_, impactAccent) = _impactColors(kind);
    final impactSkill = visualSkill(kind, ball: from, skillId: skillId);
    final creditedSkill = _creditSkill ?? impactSkill;
    // Physical melee reach is the carrier blade's contact attack, not the
    // separately configured aimed-fire projectile effect.
    final nativeReachStrike =
        kind.isBlade &&
        impactSkill.isComposed &&
        impactSkill.meleeReach > 0 &&
        impactSkill.trigger == SkillTrigger.aimedFire &&
        impactSkill.delivery == SkillDelivery.projectile;
    match.state.particles.spawnImpact(
      origin: impact,
      rng: rng,
      color: Color(impactSkill.effectColor),
      accent: impactAccent,
      count: 7 + (kind.impactWeight * 10).round(),
      displayScale: effectDisplayScaleOf(impactSkill),
    );
    _recordWeaponImpact(
      WeaponImpact(
        position: impact,
        target: target,
        direction:
            hitDirection ??
            target.position -
                (from?.position ?? at ?? target.position - const Offset(1, 0)),
        strength: match.skillLibrary.screenShakeFor(impactSkill),
        kind: kind,
        skillId: impactSkill.id,
      ),
    );
    var share = 1.0;
    final shielded = match.mode == MatchMode.arsenal
        ? 1 - _t.shieldBlock
        : _t.allOutShieldKeep;
    if (target.equippedWeapons.contains(PowerUpKind.shield)) {
      persistentEffects.defense(target, PowerUpKind.shield, broken: true);
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
      target.activeEffectSkillIds[PowerUpKind.freeze] = impactSkill.id;
      target.frozenDamageMultiplierOverride = null;
      target.frozenCollisionDamageOverride = null;
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
      portalFlashes.add(
        PortalFlash(from: oldPosition, to: from.position, swap: true),
      );
      _sound('warp');
      _yell(from, 'SWITCHEROO!');
      _yell(target, 'SWAPPED!');
    }
    final bash = kind == PowerUpKind.shield;
    if (match.mode == MatchMode.arsenal) {
      final power = (from?.overchargeLeft ?? 0) > 0
          ? _t.maximumPowerAmount
          : 1.0;
      final lost = match.damage(
        target,
        (bash
                ? _t.arenaShieldBash
                : skillId != null && !nativeReachStrike
                ? (impactSkill.arsenalDamage ?? _t.arenaDamage(kind))
                : _t.arenaDamage(kind)) *
            share *
            power,
        attacker: from,
        move: creditedSkill.name,
        moveSkill: creditedSkill,
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
        if (_cutLine(
          target,
          line,
          move: creditedSkill.name,
          moveSkill: creditedSkill,
          attacker: from,
        )) {
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
              moveSkill: visualSkill(PowerUpKind.sword),
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
    double durationSeconds = FloatingText.defaultLifespan,
  }) {
    match.state.floatingTexts.spawn(
      ball.position - Offset(0, ball.radius * 1.4),
      text,
      ball.config.primaryColor,
      callout: true,
      calloutStyle: calloutStyle,
      calloutBubble: calloutBubble,
      attachedTo: ball,
      lifespan: durationSeconds,
    );
  }

  /// Cuts [line] of [ball] (rim anchors are unique, so the thread nearest its own anchor is that thread)
  /// with a spark leaving the rim, like a body cut. False if it was already gone.
  bool _cutLine(
    SimulationBall ball,
    FanLine line, {
    String? move,
    SkillDefinition? moveSkill,
    SimulationBall? attacker,
  }) {
    if (match.cutThreads(
          ball,
          1,
          near: line.startPoint,
          move: move,
          moveSkill: moveSkill,
          attacker: attacker,
        ) ==
        0) {
      return false;
    }
    match.state.particles.spawnRimArcs(
      origin: line.startPoint,
      normal: arenaBoundaryNormal(line.startPoint, match.arenaShape),
      arenaRadius: match.arenaRadius,
      rng: rng,
      arenaShape: match.arenaShape,
    );
    return true;
  }

  /// Returns the point at which a thrown projectile reaches its intended
  /// landing plane, provided its path passes within [tolerance] of the point.
  /// Scaling the segment avoids overflow in dot products and squared lengths
  /// for otherwise finite, extremely fast throws.
  static double? _landingEntry(
    Offset from,
    Offset to,
    Offset landing,
    double tolerance,
  ) {
    final delta = to - from;
    final scale = math.max(delta.dx.abs(), delta.dy.abs());
    if (scale == 0) return from == landing ? 0 : null;
    if (!scale.isFinite || !tolerance.isFinite || tolerance < 0) {
      return null;
    }
    final scaled = delta / scale;
    final length = scaled.distance;
    if (length == 0 || !length.isFinite) return null;
    final unit = scaled / length;
    final relative = landing - from;
    if (!relative.dx.isFinite || !relative.dy.isFinite) return null;
    final along = relative.dx * unit.dx + relative.dy * unit.dy;
    if (!along.isFinite || along < 0) return null;
    final lateral = (relative.dx * unit.dy - relative.dy * unit.dx).abs();
    if (!lateral.isFinite || lateral > tolerance) return null;
    final t = (along / scale) / length;
    return t.isFinite && t >= 0 && t <= 1 ? t : null;
  }

  /// Where along the segment [from]-[to] (0..1) it first comes closer than [radius] to [center], or null
  /// if it never does.
  static double? _entry(Offset from, Offset to, Offset center, double radius) {
    final relative = center - from;
    // Preserve initial overlap semantics, including stationary projectiles.
    // Use hypot rather than squared distances: a finite, very fast shot can
    // overflow the quadratic coefficients even when its segment is valid.
    if (relative.distance < radius) return 0;
    final delta = to - from;
    // Offset.distance can overflow even when both endpoints and their
    // difference are finite. Normalize by the largest component first so
    // extremely fast, but finite, projectiles retain a usable direction.
    final scale = math.max(delta.dx.abs(), delta.dy.abs());
    if (scale == 0 || !scale.isFinite || !radius.isFinite) return null;
    final scaled = delta / scale;
    final normalizedLength = scaled.distance;
    if (normalizedLength == 0 || !normalizedLength.isFinite) return null;
    final direction = scaled / normalizedLength;
    final along = relative.dx * direction.dx + relative.dy * direction.dy;
    if (!along.isFinite || along < 0) return null;
    // The perpendicular distance uses a cross product of the unit direction
    // and relative offset. This avoids squaring the full travel distance.
    final perpendicular =
        (relative.dx * direction.dy - relative.dy * direction.dx).abs();
    if (!perpendicular.isFinite || perpendicular > radius) return null;
    final chord = math.sqrt(
      math.max(0, radius - perpendicular) * (radius + perpendicular),
    );
    // Divide in stages to avoid forming an overflowing full segment length.
    final entry = ((along - chord) / scale) / normalizedLength;
    return entry >= 0 && entry <= 1 ? entry : null;
  }

  /// True when the segments [p1]-[p2] and [q1]-[q2] properly cross.
  static bool _crosses(Offset p1, Offset p2, Offset q1, Offset q2) =>
      segmentsProperlyCross(p1, p2, q1, q2);
}

class MuzzleArtwork {
  MuzzleArtwork(
    this.owner,
    this.skill,
    this.direction,
    this.steps, {
    this.resolvedVisual,
  });
  final SimulationBall owner;
  final SkillDefinition skill;
  final Offset direction;
  final int steps;
  // Captured when the shot fires. Never re-resolve against edited library
  // bindings while this short-lived muzzle flash is on screen.
  final ResolvedSkillEffect? resolvedVisual;
  int age = 0;
}

class CastingArtwork {
  CastingArtwork(
    this.owner,
    this.skill,
    this.steps,
    this.active, {
    this.hasExplicitDuration = false,
    this.resolvedVisual,
  });
  final SimulationBall owner;
  final SkillDefinition skill;
  final int steps;
  final bool Function()? active;

  /// Whether an authored Visual Event duration caps an active-follow cast.
  /// Captured on creation so cleanup does not depend on mutable library state.
  final bool hasExplicitDuration;

  /// Immutable artwork settings captured at activation.
  final ResolvedSkillEffect? resolvedVisual;
  int age = 0;

  bool get isFinished => active == null
      ? age >= steps
      : !active!() || (hasExplicitDuration && age >= steps);
}

class _ScheduledComposedEffect {
  _ScheduledComposedEffect({
    required this.owner,
    required this.targets,
    required this.skill,
    required this.repeatsLeft,
    required this.stepsLeft,
    this.announceOnNext = false,
    this.creditSkill,
  });

  final SimulationBall owner;
  final List<SimulationBall> targets;
  final SkillDefinition skill;
  int repeatsLeft;
  int stepsLeft;
  bool announceOnNext;
  final SkillDefinition? creditSkill;
}

class _CustomDamageOverTime {
  _CustomDamageOverTime({
    required this.owner,
    required this.target,
    required this.skill,
    required this.stepsLeft,
    required this.stepsUntilTick,
    this.creditSkill,
  });

  final SimulationBall owner;
  final SimulationBall target;
  final SkillDefinition skill;
  int stepsLeft;
  int stepsUntilTick;
  final SkillDefinition? creditSkill;
}

class _ScheduledEffectStep {
  _ScheduledEffectStep(
    this.owner,
    this.targets,
    this.skill,
    this.step,
    this.dueStep,
    this.creditSkill,
  );
  final SimulationBall owner;
  final List<SimulationBall> targets;
  final SkillDefinition skill;
  final SkillEffectStep step;
  final int dueStep;
  final SkillDefinition? creditSkill;
}
