import 'dart:math' as math;
import 'package:flutter/foundation.dart' show mergeSort;
import 'package:flutter/material.dart';
import '../../../core/utils/ball_image_loader.dart';
import '../../../core/utils/math_utils.dart';
import '../../../core/utils/seeded_random.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../../skills/domain/skill_library.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/arena_physics_engine.dart';
import '../domain/fan_line.dart';
import '../domain/floating_text.dart';
import '../domain/match_colors.dart';
import '../domain/particle_system.dart';
import '../domain/power_up.dart';
import '../domain/power_up_config.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import 'power_up_system.dart';

/// Runs a match on the thread-cutting rules from the reference video:
///
/// - The rim is divided into [rimSlotCount] fixed anchor slots. Each slot is
///   free or owned by exactly one ball. Every owned slot is a line from the
///   rim anchor to the owner's center, so a ball's lines sweep as it moves.
/// - A line is cut the moment any opponent's body overlaps it. The line is
///   removed and its slot becomes free.
/// - When a ball hits the wall at a free slot, it claims the run of free
///   slots from the contact point up to its own nearest line ("+N LINES").
///   If an opponent's line comes first in a direction, nothing is claimed
///   that way.
/// - A ball with no lines left is eliminated; the last ball standing wins.
///
/// [mode] picks the match rules. [MatchMode.threads] is exactly the above. [MatchMode.allOut] keeps the
/// threads and adds power-ups ([powerUps]) whose hits cut threads ([cutThreads]). [MatchMode.arsenal] has
/// no threads at all: no starting slots, no claims on wall hits, no cutting; each ball has a life bar
/// ([SimulationBall.life], [damage]) and is out at 0.
class MatchSimulationController {
  static const double fixedTimestep = 1 / 60;
  static const int maxStepsPerFrame = 10;

  // Measured from the reference video: balls start at ~0.05 arena radii per
  // video frame; the video plays at 30fps, so that is ~0.025 per 60Hz step.
  // Collisions are fully elastic there (speed swaps between balls on contact,
  // and the average never decays). Ball radius is ~0.107 of the arena radius.
  // Played back about 20% slower than that, which looked better in the app.
  static const double cruiseRadiiPerStep = 0.02;
  static const double ballRadiusRatio = 0.107;
  // Reference start: balls ~0.47 arena radii from the center, launched at
  // ~45 degrees between "inward" and a shared sideways direction.
  // Each ball independently draws its start distance, speed and launch tilt
  // from these ranges, so every contestant has the same odds.
  static const double startRadiusMin = 0.40;
  static const double startRadiusMax = 0.55;
  static const double speedVariation = 0.10; // +/- 10%
  static const double launchTiltMax = 10 * math.pi / 180;
  // With 3+ balls a symmetric inward launch makes everyone hit the wall and
  // converge on the center together, wiping each other out in ~2s. Launching
  // along the tangent with a wider tilt desynchronizes them (measured over
  // 300 seeds: 3 balls median ~11s, 4 balls ~4s, wins even across starts).
  static const double multiBallTiltMax = 30 * math.pi / 180;
  // Fraction of the elastic speed exchange applied on ball-ball contact.
  // Fully elastic (1.0) nearly stops the struck-from ball, which felt wrong;
  // total kinetic energy is still conserved.
  static const double collisionSpeedTransfer = 0.25;
  // Slow motion kicks in when one of the last two balls has this many lines
  // or fewer (the default; the admin can change it, see [slowMotionLines]).
  static const int slowMotionLineThreshold = 10;
  static const double slowMotionTimeScale = 0.25;

  final double initialArenaRadius;
  final bool shrinkingArena;
  final double minimumArenaScale;
  final Color bloodColor;
  final ArenaDecoration arenaDecoration;

  static const int shrinkGraceSteps = 10 * 60;
  static const int shrinkDurationSteps = 120 * 60;
  double get arenaRadius {
    if (!shrinkingArena || _stepCount <= shrinkGraceSteps) {
      return initialArenaRadius;
    }
    final progress = ((_stepCount - shrinkGraceSteps) / shrinkDurationSteps)
        .clamp(0.0, 1.0);
    return initialArenaRadius * (1 - (1 - minimumArenaScale) * progress);
  }

  /// The seed this match runs on. Re-running the same contestants with this
  /// seed reproduces the match exactly (used for replays and video export).
  final int seed;
  final int rimSlotCount;
  late final SeededRandom _rng;
  late final ArenaPhysicsEngine _physics;
  final ParticleSystem _particles = ParticleSystem();
  final FloatingTextManager _floatingTexts = FloatingTextManager();
  late final List<SimulationBall> _balls;

  /// Owner of each rim slot, or null when the slot is free.
  late final List<SimulationBall?> _slotOwners;

  late final double _layoutRotation;

  double _accumulator = 0.0;
  int _stepCount = 0;

  /// Running totals of rim bounces and ball-ball hits, for sound effects
  /// (the screen plays one when they go up). They draw nothing from the RNG.
  int wallHits = 0;
  int ballHits = 0;
  int threadCuts = 0;
  int knockouts = 0;
  double _elapsedSeconds = 0.0;
  MatchStatus _status = MatchStatus.running;
  String? _winnerId;
  String? _lastEliminatedId;
  String? _winningMove;
  final Map<SimulationBall, String> _lastMove = {};
  final Map<String, int> eliminations = {};
  final Map<SimulationBall, SimulationBall> _lastDamageBy = {};

  /// [layoutRotation] fixes where ball 0 starts (radians); by default the
  /// whole starting layout is rotated by a seeded random angle.
  /// Slow motion starts when one of the last two balls is down to this many
  /// lines (0: never) and stays there until the end: thanks to the
  /// look-ahead, a ball that will recover never triggers it. It only changes
  /// playback speed, never the outcome.
  final int slowMotionLines;

  /// When set, slow motion instead starts this many seconds of game time
  /// before the winning cut.
  final double? slowMotionBeforeWinSeconds;

  /// The match is deterministic, so the constructor plays it through once
  /// off-screen (a few tens of ms) to learn when it ends and from which step
  /// the endgame is final. False skips that (used by the look-ahead itself).
  final bool lookAhead;

  /// Ball size relative to [ballRadiusRatio] (BallSize.scale); part of the
  /// match, like the seed.
  final double ballScale;

  /// The rules this match is played by.
  final MatchMode mode;

  /// The power-ups of an Arsenal or All-Out match; null in Threads mode.
  PowerUpSystem? get powerUps => _powerUps;
  PowerUpSystem? _powerUps;

  /// Seconds of game time before the win when slow motion starts, or null for the lines rule. Arsenal has
  /// no lines, so its "lines" setting means "before the win" ([arsenalBeforeWinSeconds] unless the admin
  /// set seconds); with slow motion off (no lines, no seconds) it stays off.
  double? get _beforeWinSeconds {
    if (mode != MatchMode.arsenal || slowMotionBeforeWinSeconds != null) {
      return slowMotionBeforeWinSeconds;
    }
    return slowMotionLines > 0 ? arsenalBeforeWinSeconds : null;
  }

  /// The power-ups that can spawn (Arsenal / All-Out); null for all of them. Part of the match, like
  /// the seed.
  final Set<PowerUpKind>? powerUpKinds;

  /// The power-up numbers (the admin's settings, or a replay link's). Part of the match, like the seed.
  final PowerUpConfig tuning;
  final SkillLibrary skillLibrary;
  final bool dualWield;
  final bool endlessBattle;
  final bool mayhem;
  static const double mayhemDurationSeconds = 120;
  final int mayhemSeconds;

  /// How long a "Faces" ball winces after a hit or a lost thread (cosmetic).
  static const int hurtFlashSteps = 18;

  /// Arsenal's slow motion when the admin chose the lines rule.
  static const double arsenalBeforeWinSeconds = 1.5;

  /// The step on which the match ends (null without a look-ahead, or if it
  /// hit its limit).
  int? get predictedFinishStep => _finishStep;
  int? _finishStep;

  // First step from which the lines condition holds until the end.
  int? _settledEndgameStep;

  // Look-ahead limit: ten minutes of game time.
  static const int _maxPredictedSteps = 60 * 60 * 10;

  MatchSimulationController(
    List<CustomBall> contestants, {
    required double arenaRadius,
    int? seed,
    double restitution = 1.0,
    this.rimSlotCount = kRimSlotCount,
    double? layoutRotation,
    Color arenaBackground = const Color(0xFF0A0A0B),
    this.slowMotionLines = slowMotionLineThreshold,
    this.slowMotionBeforeWinSeconds,
    this.lookAhead = true,
    this.ballScale = 1.0,
    this.mode = MatchMode.threads,
    this.powerUpKinds,
    this.tuning = PowerUpConfig.defaults,
    this.skillLibrary = SkillLibrary.defaults,
    this.dualWield = false,
    this.endlessBattle = false,
    this.mayhem = false,
    this.mayhemSeconds = 120,
    this.shrinkingArena = false,
    this.minimumArenaScale = 0.60,
    this.bloodColor = const Color(0xFFD9152B),
    this.arenaDecoration = ArenaDecoration.defaultArena,
  }) : initialArenaRadius = arenaRadius,
       seed = seed ?? DateTime.now().millisecondsSinceEpoch {
    if (!endlessBattle &&
        lookAhead &&
        (slowMotionBeforeWinSeconds != null || slowMotionLines > 0)) {
      // Same seed and setup: the steps are identical (slow motion only
      // changes playback), so its timeline is this match's.
      final ahead = MatchSimulationController(
        contestants,
        arenaRadius: arenaRadius,
        seed: this.seed,
        restitution: restitution,
        rimSlotCount: rimSlotCount,
        layoutRotation: layoutRotation,
        slowMotionLines: slowMotionLines,
        lookAhead: false,
        ballScale: ballScale,
        mode: mode,
        powerUpKinds: powerUpKinds,
        tuning: tuning,
        skillLibrary: skillLibrary,
        dualWield: dualWield,
        endlessBattle: endlessBattle,
        mayhem: mayhem,
        mayhemSeconds: mayhemSeconds,
        shrinkingArena: shrinkingArena,
        minimumArenaScale: minimumArenaScale,
        bloodColor: bloodColor,
        arenaDecoration: arenaDecoration,
      );
      var lastCalmStep = 0;
      while (ahead._status != MatchStatus.finished &&
          ahead._stepCount < _maxPredictedSteps) {
        ahead._stepPhysics(fixedTimestep);
        ahead._stepCount++;
        if (ahead._status == MatchStatus.running) {
          lastCalmStep = ahead._stepCount;
        }
      }
      if (ahead._status == MatchStatus.finished) {
        _finishStep = ahead._stepCount;
        _settledEndgameStep = lastCalmStep + 1;
      }
    }
    _rng = SeededRandom(this.seed);
    _physics = ArenaPhysicsEngine(arenaRadius, _rng, restitution: restitution);
    _slotOwners = List<SimulationBall?>.filled(rimSlotCount, null);
    _layoutRotation = layoutRotation ?? _rng.nextDoubleRange(0, 2 * math.pi);

    // Two balls launch as in the reference: ~45 degrees between "inward" and
    // a shared sideways direction picked by the seed, so they converge as
    // mirror images. Three or more launch along their own tangent with one
    // shared turning sense (see [multiBallTiltMax]). Both treat every start
    // position identically.
    final sense = _rng.nextDouble() < 0.5 ? 1.0 : -1.0;
    final count = contestants.length;

    final ballRadius = arenaRadius * ballRadiusRatio * ballScale;
    // Line colors that are visible on the arena and distinct per contestant
    // (cosmetic only: ids and physics settings are untouched).
    final lineColors = MatchColors.resolve([
      for (final c in contestants) c.primaryColor,
    ], background: arenaBackground);

    _balls = List.generate(count, (i) {
      final angle = _startAngle(i, count);
      final radial = Offset(math.cos(angle), math.sin(angle));
      final position =
          radial *
          (arenaRadius * _rng.nextDoubleRange(startRadiusMin, startRadiusMax));
      final speed =
          _cruiseSpeed(contestants[i]) *
          _crowdSpeedFactor(count) *
          _rng.nextDoubleRange(1 - speedVariation, 1 + speedVariation);

      final sideways = count == 2
          ? _tangent(_startAngle(0, count)) * sense
          : _tangent(angle) * sense;
      final inward = count == 2 ? math.pi / 4 : 0.0;
      final direction = sideways * math.cos(inward) - radial * math.sin(inward);
      final tiltMax = count == 2 ? launchTiltMax : multiBallTiltMax;
      final tilt = _rng.nextDoubleRange(-tiltMax, tiltMax);
      final heading = math.atan2(direction.dy, direction.dx) + tilt;
      final velocity = Offset(math.cos(heading), math.sin(heading)) * speed;
      return SimulationBall(
        config: lineColors[i] == contestants[i].primaryColor
            ? contestants[i]
            : contestants[i].copyWith(
                primaryColor: lineColors[i],
                glowColor: Color.lerp(lineColors[i], Colors.white, 0.35),
              ),
        position: position,
        velocity: velocity,
        radius: ballRadius,
        lineCount: 0,
      );
    });

    if (mode == MatchMode.arsenal) {
      for (final ball in _balls) {
        ball.life = PowerUpTuning.arenaLife;
      }
    } else {
      _assignStartingSlots();
      for (final ball in _balls) {
        ball.startLines = ball.fanLines.length;
      }
    }
    if (mode != MatchMode.threads) _powerUps = PowerUpSystem(this, _rng);
  }

  double _startAngle(int index, int count) =>
      _layoutRotation + (2 * math.pi / count) * index;

  Offset _tangent(double angle) => Offset(-math.sin(angle), math.cos(angle));

  /// More balls means more cutters and much shorter matches, so crowded
  /// matches start slower: 2 / ball count (3 balls 67%, 4 balls 50%).
  double _crowdSpeedFactor(int count) => count > 2 ? 2 / count : 1.0;

  /// Starting speed in px/s. [CustomBall.baseSpeed] scales it relative to
  /// the default ball, so the default matches the reference video.
  double _cruiseSpeed(CustomBall config) =>
      arenaRadius *
      cruiseRadiiPerStep /
      fixedTimestep *
      (config.baseSpeed / CustomBall.defaultBaseSpeed);

  double _slotAngle(int slot) => 2 * math.pi * slot / rimSlotCount;

  int _slotAt(double angle) {
    final index = (angle / (2 * math.pi) * rimSlotCount).round();
    return index % rimSlotCount;
  }

  /// Each ball starts owning the equal share of the rim centered on its
  /// starting direction (two balls: one half each).
  void _assignStartingSlots() {
    if (_balls.isEmpty) return;
    final share = 2 * math.pi / _balls.length;
    for (var slot = 0; slot < rimSlotCount; slot++) {
      // Shift by half a share so ball 0's arc is centered on its start angle.
      final shifted =
          (_slotAngle(slot) - _layoutRotation + share / 2) % (2 * math.pi);
      final owner = _balls[(shifted / share).floor() % _balls.length];
      _claimSlot(owner, slot);
    }
    for (final ball in _balls) {
      ball.lineCount = ball.fanLines.length;
    }
  }

  void _claimSlot(SimulationBall ball, int slot) {
    _slotOwners[slot] = ball;
    final angle = _slotAngle(slot);
    ball.fanLines.add(
      FanLine(
        ownerBallId: ball.config.id,
        slotIndex: slot,
        rimAngle: angle,
        startPoint: Offset(
          math.cos(angle) * arenaRadius,
          math.sin(angle) * arenaRadius,
        ),
        endPoint: ball.position,
      ),
    );
  }

  /// Number of rim slots no ball owns.
  int get freeSlotCount => _slotOwners.where((owner) => owner == null).length;

  /// Claims up to [count] free rim slots for [ball] (the All-Out apple), the ones nearest the ball's own
  /// direction from the center first. Returns how many were claimed: 0 when no slot is free.
  int claimFreeSlots(SimulationBall ball, int count) {
    if (count <= 0) return 0;
    final free = [
      for (var slot = 0; slot < rimSlotCount; slot++)
        if (_slotOwners[slot] == null) slot,
    ];
    if (free.isEmpty) return 0;
    final facing = math.atan2(ball.position.dy, ball.position.dx);
    double gap(int slot) {
      final d = (_slotAngle(slot) - facing).abs() % (2 * math.pi);
      return math.min(d, 2 * math.pi - d);
    }

    // Stable on equal gaps (slot order), so the result only depends on the match state.
    mergeSort(free, compare: (a, b) => gap(a).compareTo(gap(b)));
    final claimed = free.take(count).toList();
    for (final slot in claimed) {
      _claimSlot(ball, slot);
    }
    ball.lineCount = ball.fanLines.length;
    return claimed.length;
  }

  /// Arsenal: takes [amount] life off [ball], never below 0 (it is out at the next elimination check).
  /// Does nothing in the other modes, where the threads are the life (see [cutThreads]).
  ///
  /// Crowded matches hit harder (x (count / 2)^2: 3 balls 2.25, 4 balls 4), so the extra eliminations
  /// don't stretch them out: one spawn every 5 s has to feed every ball, and crowded balls move slower.
  ///
  /// Returns the life actually taken.
  double damage(
    SimulationBall ball,
    double amount, {
    SimulationBall? attacker,
    String? move,
    bool scaleForCrowd = true,
    bool applyFrozenMultiplier = true,
  }) {
    if (mode != MatchMode.arsenal) return 0;
    if (amount > 0 && _absorbWithGoldenArmor(ball)) return 0;
    final crowd = !scaleForCrowd
        ? 1.0
        : mayhem
        ? 0.85
        : _balls.length > 2
        ? math.pow(_balls.length / 2, 2).toDouble()
        : 1.0;
    final frozenMultiplier = applyFrozenMultiplier && ball.frozenLeft > 0
        ? tuning.frozenDamageMultiplier
        : 1.0;
    final before = ball.life;
    ball.life = math.max(0, ball.life - amount * crowd * frozenMultiplier);
    if (ball.life < before) {
      ball.hurtFlashLeft = hurtFlashSteps;
    }
    if (ball.life < before && attacker != null && !identical(ball, attacker)) {
      _lastDamageBy[ball] = attacker;
    }
    if (ball.life < before && move != null) _lastMove[ball] = move;
    return before - ball.life;
  }

  /// Cuts up to [count] of [ball]'s threads and frees their rim slots, the ones anchored nearest to
  /// [near] first when it is given (otherwise in the order the ball holds them). Returns how many were
  /// cut; a ball left with none is out at the next elimination check.
  int cutThreads(
    SimulationBall ball,
    int count, {
    Offset? near,
    String? move,
    SimulationBall? attacker,
  }) {
    if (count <= 0 || ball.fanLines.isEmpty) return 0;
    if (_absorbWithGoldenArmor(ball)) return 0;
    final candidates = [...ball.fanLines];
    if (near != null) {
      // Stable on equal distances, so the result only depends on the match state.
      final distance = {
        for (final line in candidates)
          line: (line.startPoint - near).distanceSquared,
      };
      mergeSort(
        candidates,
        compare: (a, b) => distance[a]!.compareTo(distance[b]!),
      );
    }
    final cut = candidates.take(count).toSet();
    ball.fanLines.removeWhere((line) {
      if (!cut.contains(line)) return false;
      line.isActive = false;
      _freeSlot(line);
      return true;
    });
    ball.lineCount = ball.fanLines.length;
    if (cut.isNotEmpty && attacker != null && !identical(ball, attacker)) {
      _lastDamageBy[ball] = attacker;
    }
    if (cut.isNotEmpty) _lastMove[ball] = move ?? 'Thread cut';
    return cut.length;
  }

  bool _absorbWithGoldenArmor(SimulationBall ball) {
    if (ball.goldenArmorHits <= 0) return false;
    ball.goldenArmorHits--;
    state.floatingTexts.spawn(
      ball.position,
      ball.goldenArmorHits == 0 ? 'ARMOR BROKEN!' : 'CLANG!',
      const Color(0xFFFFD54F),
    );
    return true;
  }

  /// Simulated match time so far; stops advancing once the match is finished.
  /// The last ball knocked out (the runner-up), once a match is decided.
  String? get lastEliminatedId => _lastEliminatedId;
  String? get winningMove => _winningMove;

  /// How long the match has been playing, in the time passed to [tick]
  /// (so slow motion counts at the speed it is watched). Stops at the finish.
  double get elapsedSeconds => _elapsedSeconds;

  Future<void> preloadImages() async {
    for (final ball in _balls) {
      ball.cachedUiImage = await BallImageLoader.load(ball.config);
    }
  }

  /// Simulation steps taken so far (the screen repaints when it changes).
  int get stepCount => _stepCount;

  /// Playback gets [speedUpPerMinute] faster for every full minute of game time, up to [maxSpeedUp], so
  /// long matches don't drag. Playback only: the steps are the same, so the outcome and replays are too.
  /// Slow motion ignores it.
  static const double speedUpPerMinute = 0.25;
  static const double maxSpeedUp = 2.0;

  /// The current playback speed-up (1 in the first minute).
  double get playbackSpeedUp => math.min(
    maxSpeedUp,
    1 + speedUpPerMinute * (_stepCount * fixedTimestep / 60).floor(),
  );

  SimulationState get state => SimulationState(
    balls: _balls,
    particles: _particles,
    floatingTexts: _floatingTexts,
    status: _status,
    winnerId: _winnerId,
    powerUps: _powerUps,
    step: _stepCount,
    arenaRadius: arenaRadius,
  );

  void tick(double realDeltaSeconds) {
    if (_status == MatchStatus.finished) {
      // The match is over, but the last sparks and texts finish animating.
      _particles.update(realDeltaSeconds);
      _floatingTexts.update(realDeltaSeconds);
      return;
    }

    if (!realDeltaSeconds.isFinite || realDeltaSeconds <= 0) return;
    if (mayhem) {
      realDeltaSeconds = math.min(
        realDeltaSeconds,
        math.max(0.0, mayhemSeconds - _elapsedSeconds),
      );
    }
    _elapsedSeconds += realDeltaSeconds;
    if (mayhem && _elapsedSeconds >= mayhemSeconds) {
      _finishMayhem();
      _particles.update(realDeltaSeconds);
      _floatingTexts.update(realDeltaSeconds);
      return;
    }
    final timeScale = _status == MatchStatus.slowMotion
        ? slowMotionTimeScale
        : playbackSpeedUp;
    _accumulator += realDeltaSeconds * timeScale;

    // Cap accumulator to prevent spiral of death
    final maxAccumulator = fixedTimestep * maxStepsPerFrame;
    if (_accumulator > maxAccumulator) {
      _accumulator = maxAccumulator;
    }

    while (_accumulator >= fixedTimestep && _status != MatchStatus.finished) {
      _stepPhysics(fixedTimestep);
      _stepCount++;
      _accumulator -= fixedTimestep;
    }

    _particles.update(realDeltaSeconds);
    _floatingTexts.update(realDeltaSeconds);
  }

  void _finishMayhem() {
    if (_status == MatchStatus.finished || _balls.isEmpty) return;
    final ranked = [..._balls]
      ..sort((a, b) {
        final knockouts = (eliminations[b.config.id] ?? 0).compareTo(
          eliminations[a.config.id] ?? 0,
        );
        if (knockouts != 0) return knockouts;
        final life = b.life.compareTo(a.life);
        if (life != 0) return life;
        return _balls.indexOf(a).compareTo(_balls.indexOf(b));
      });
    _winnerId = ranked.first.config.id;
    // The visual loser must match the bottom of the final KO/life tally.
    _lastEliminatedId = ranked.length > 1 ? ranked.last.config.id : null;
    _winningMove = 'Knockout lead';
    _status = MatchStatus.finished;
  }

  // Used only by the admin test arena. Empty during ordinary matches.
  final Map<SimulationBall, Offset> _testPositions = {};
  final Map<SimulationBall, Offset> _testVelocities = {};

  void setTestBallPinned(SimulationBall ball, bool pinned) {
    if (pinned) {
      _testPositions.putIfAbsent(ball, () => ball.position);
      _testVelocities.putIfAbsent(ball, () => ball.velocity);
      ball.velocity = Offset.zero;
    } else {
      _testPositions.remove(ball);
      final velocity = _testVelocities.remove(ball);
      if (velocity != null) ball.velocity = velocity;
    }
  }

  void _restoreTestPositions() {
    for (final entry in _testPositions.entries) {
      entry.key.position = entry.value;
      entry.key.velocity = Offset.zero;
    }
  }

  void _stepPhysics(double dt) {
    _restoreTestPositions();
    _physics.arenaRadius = arenaRadius;
    // Lines deactivated from outside the step (e.g. tests) free their slots.
    _pruneInactiveLines();
    for (final ball in _balls) {
      if (ball.hurtFlashLeft > 0) {
        ball.hurtFlashLeft--; // Cosmetic ("Faces" wince), no effect on play.
      }
      if (ball.burningLeft > 0) ball.burningLeft--;
      if (ball.poisonLeft > 0) ball.poisonLeft--;
    }
    final linesAtStart = {
      for (final ball in _balls) ball: ball.fanLines.length,
    };
    final arsenal = mode == MatchMode.arsenal;
    final lifeAtStart = arsenal
        ? {for (final ball in _balls) ball: ball.life}
        : null;

    // Who goes first rotates every step, so no contestant always wins ties
    // (e.g. two wall hits racing for the same free run).
    final order = [
      for (var k = 0; k < _balls.length; k++)
        _balls[(k + _stepCount) % _balls.length],
    ];

    // 1. Physics update & wall collision (wall hits claim free rim slots)
    for (final ball in order) {
      if (ball.isEliminated) continue;

      final previousPosition = ball.position;
      final slowedByBubble = order.any(
        (other) =>
            !identical(other, ball) &&
            other.timeBubbleLeft > 0 &&
            (ball.position - other.position).distance < other.radius * 3,
      );
      final move = ball.velocity * dt * (slowedByBubble ? 0.35 : 1.0);
      // A speed boost moves the ball faster without changing its stored velocity, so it ends cleanly.
      ball.position += ball.speedLeft > 0
          ? move * PowerUpTuning.speedFactor
          : move;
      final collision = _physics.resolveWallCollision(
        ball,
        previousPosition: previousPosition,
      );
      if (collision != null) {
        wallHits++;
        _particles.spawnBurst(
          origin: collision.contactPoint,
          normal: collision.normal,
          color: ball.config.primaryColor,
          rng: _rng,
        );

        // Update ball rotation from collision
        ball.rotation += collision.normal.dx * 0.1;

        if (!arsenal) {
          final claimed = _claimFromWallHit(ball, collision.contactPoint);
          if (claimed > 0) {
            _floatingTexts.spawn(
              collision.contactPoint,
              '+$claimed LINES',
              ball.config.primaryColor,
            );
          }
        }
      }
    }

    // 2. Ball-ball collisions
    for (var i = 0; i < order.length; i++) {
      for (var j = i + 1; j < order.length; j++) {
        final a = order[i];
        final b = order[j];
        if (a.isEliminated || b.isEliminated) continue;
        // A ghost passes straight through other balls.
        if (a.isGhost || b.isGhost) continue;

        final fieldA = a.magneticFieldLeft > 0;
        final fieldB = b.magneticFieldLeft > 0;
        if (fieldA || fieldB) {
          final delta = b.position - a.position;
          final distance = delta.distance;
          final reach =
              (fieldA ? a.radius * 2 : a.radius) +
              (fieldB ? b.radius * 2 : b.radius);
          if (distance < reach) {
            final normal = distance == 0
                ? const Offset(1, 0)
                : delta / distance;
            final speedA = math.max(a.velocity.distance, arenaRadius * 0.7);
            final speedB = math.max(b.velocity.distance, arenaRadius * 0.7);
            a
              ..position -= normal * ((reach - distance) / 2)
              ..velocity = -normal * speedA;
            b
              ..position += normal * ((reach - distance) / 2)
              ..velocity = normal * speedB;
            ballHits++;
            damage(a, _bodyCollisionDamage(b), attacker: b, move: 'Collision');
            damage(b, _bodyCollisionDamage(a), attacker: a, move: 'Collision');
            _floatingTexts.spawn(
              (a.position + b.position) / 2,
              'MAGNETIC BOUNCE!',
              const Color(0xFFB04CFF),
            );
            continue;
          }
        }

        final velocityA = a.velocity;
        final velocityB = b.velocity;
        final result = _physics.resolveBallCollision(a, b);
        if (result != null) {
          ballHits++;
          _dampSpeedTransfer(a, b, velocityA, velocityB, result.normal);
          _particles.spawnBurst(
            origin: result.contactPoint,
            normal: result.normal,
            color: a.config.primaryColor,
            rng: _rng,
          );

          // Add rotation from collision
          final impactAngle = math.atan2(result.normal.dy, result.normal.dx);
          a.rotation += impactAngle * 0.05;
          b.rotation -= impactAngle * 0.05;

          // In Arsenal, every genuine ball-to-ball bounce hurts both balls.
          damage(a, _bodyCollisionDamage(b), attacker: b, move: 'Collision');
          damage(b, _bodyCollisionDamage(a), attacker: a, move: 'Collision');
          if (a.frozenLeft > 0) {
            damage(
              a,
              tuning.frozenCollisionDamage,
              attacker: b,
              move: 'Frozen collision',
              applyFrozenMultiplier: false,
            );
          }
          if (b.frozenLeft > 0) {
            damage(
              b,
              tuning.frozenCollisionDamage,
              attacker: a,
              move: 'Frozen collision',
              applyFrozenMultiplier: false,
            );
          }

          // Melee power-ups (knife, shield bash) strike on contact.
          _powerUps?.onContact(a, b);
        }
      }
    }

    _restoreTestPositions();

    // Power-ups (Arsenal and All-Out): spawn, pick up, aim, fire, hit.
    _powerUps?.step();
    _restoreTestPositions();

    // 3. Lines follow their owner
    for (final ball in _balls) {
      if (ball.isEliminated) continue;
      for (final line in ball.fanLines) {
        line.startPoint = line.rimPoint(arenaRadius);
        line.endPoint = ball.position;
      }
    }

    // 4. Cutting: any opponent body overlapping a line cuts it (Arsenal has no lines to cut). A ghost's
    // body cuts nothing and its own lines can't be cut.
    for (final cutter in arsenal ? const <SimulationBall>[] : _balls) {
      if (cutter.isEliminated || cutter.isGhost) continue;

      for (final target in _balls) {
        if (target.isEliminated || target.isGhost) continue;
        if (identical(target, cutter)) continue;

        final cut = _cutLinesCrossedBy(cutter, target);
        threadCuts += cut.length;
        if (cut.isEmpty) continue;
        _lastDamageBy[target] = cutter;
        _lastMove[target] = 'Thread cut';
        target.hurtFlashLeft = hurtFlashSteps;

        // Direction from cutter to target
        final offset = target.position - cutter.position;
        final cutNormal = offset.distance > 0
            ? offset / offset.distance
            : const Offset(1, 0);

        // Cut sparks - white dot burst at cut point
        _particles.spawnCutSparks(
          origin: cutter.position,
          normal: cutNormal,
          rng: _rng,
        );

        // Thin white arcs leaving the rim at the cut lines' anchors
        for (final line in cut) {
          _particles.spawnRimArcs(
            origin: line.startPoint,
            normal: Offset(math.cos(line.rimAngle), math.sin(line.rimAngle)),
            arenaRadius: arenaRadius,
            rng: _rng,
          );
        }
      }
    }

    // 5. Elimination check: ball eliminated when all its lines are cut (Arsenal: its life is gone)
    final eliminatedNow = <SimulationBall>[];
    for (final ball in _balls) {
      if (ball.isEliminated) continue;

      if (arsenal ? ball.life < 1 : ball.fanLines.isEmpty) {
        ball.isEliminated = true;
        knockouts++;
        eliminatedNow.add(ball);
        _floatingTexts.spawn(
          ball.position,
          'ELIMINATED',
          ball.config.primaryColor,
        );
      }
    }

    _powerUps?.onEliminations(eliminatedNow, _lastDamageBy);

    if (endlessBattle && eliminatedNow.isNotEmpty) {
      for (final ball in eliminatedNow) {
        final attacker = _lastDamageBy.remove(ball);
        if (attacker != null) {
          eliminations.update(
            attacker.config.id,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        _respawn(ball);
      }
      eliminatedNow.clear();
    }

    // 6. Win condition: last ball with >=1 line wins
    var activeBalls = _balls.where((b) => !b.isEliminated).toList();
    if (activeBalls.isEmpty && eliminatedNow.isNotEmpty && _balls.length > 1) {
      // Everyone left lost their last line in the same step: the one that
      // held the most lines at the start of the step survives (seeded coin
      // flip on a tie), so a match never ends without a winner. In Arsenal
      // it is the most life at the start of the step.
      final List<SimulationBall> tied;
      if (lifeAtStart != null) {
        final best = eliminatedNow.map((b) => lifeAtStart[b]!).reduce(math.max);
        tied = eliminatedNow.where((b) => lifeAtStart[b] == best).toList();
      } else {
        final best = eliminatedNow
            .map((b) => linesAtStart[b]!)
            .reduce(math.max);
        tied = eliminatedNow.where((b) => linesAtStart[b] == best).toList();
      }
      final survivor = tied[_rng.nextInt(tied.length)];
      survivor.isEliminated = false;
      // An Arsenal survivor keeps one point of life, so its life bar isn't empty.
      if (arsenal && survivor.life < 1) survivor.life = 1;
      activeBalls = [survivor];
    }
    final knockedOut = eliminatedNow.where((b) => b.isEliminated);
    if (knockedOut.isNotEmpty) {
      final last = knockedOut.last;
      _lastEliminatedId = last.config.id;
      _winningMove = _lastMove[last] ?? (arsenal ? 'Collision' : 'Thread cut');
    }
    if (activeBalls.length == 1 && _balls.length > 1) {
      _winnerId = activeBalls.first.config.id;
      _status = MatchStatus.finished;
    } else if (activeBalls.isEmpty) {
      _status = MatchStatus.finished;
    } else {
      // 7. Slow motion while the match is about to end: either the last
      // seconds before the (predicted) winning cut, or once the final two are
      // left and one of them is down to a handful of lines for good (the
      // look-ahead knows it won't recover; without one, normal speed returns
      // if it does).
      final finish = _finishStep;
      final beforeWin = _beforeWinSeconds;
      final bool endgame;
      if (beforeWin != null) {
        // The winning cut is known in advance (see the constructor).
        endgame =
            finish != null &&
            _stepCount + 1 >= finish - (beforeWin / fixedTimestep).round();
      } else if (_settledEndgameStep != null) {
        // From here the low ball stays low until it is knocked out.
        endgame = _stepCount + 1 >= _settledEndgameStep!;
      } else {
        // Arsenal has no lines (its slow motion is decided by the look-ahead).
        endgame =
            !arsenal &&
            activeBalls.length == 2 &&
            slowMotionLines > 0 &&
            activeBalls.any((b) => b.fanLines.length <= slowMotionLines);
      }
      _status = endgame ? MatchStatus.slowMotion : MatchStatus.running;
    }

    for (final ball in _balls) {
      ball.lineCount = ball.fanLines.length;
    }
  }

  void _respawn(SimulationBall ball) {
    _powerUps?.resetForRespawn(ball);
    final angle = _rng.nextDoubleRange(0, 2 * math.pi);
    final radial = Offset(math.cos(angle), math.sin(angle));
    final heading = angle + math.pi + _rng.nextDoubleRange(-0.4, 0.4);
    ball
      ..isEliminated = false
      ..life = PowerUpTuning.arenaLife
      ..ghostLeft = tuning.ghostSteps ~/ 2
      ..position = radial * (arenaRadius * startRadiusMax)
      ..velocity =
          Offset(math.cos(heading), math.sin(heading)) *
          _cruiseSpeed(ball.config) *
          _crowdSpeedFactor(_balls.length);
    _floatingTexts.spawn(ball.position, 'RESPAWN!', ball.config.primaryColor);
  }

  /// A ball without either equipped weapon uses the admin's unarmed damage.
  /// Buffs do not count as equipment. Ordinary armed bumps keep their base damage.
  double _bodyCollisionDamage(SimulationBall attacker) =>
      attacker.held == null && attacker.heldSecondary == null
      ? tuning.unarmedCollisionDamage
      : PowerUpTuning.arenaCollisionDamage;

  /// Keeps the bounce directions from the elastic collision but applies only
  /// [collisionSpeedTransfer] of its speed exchange, then rescales both balls
  /// so their total kinetic energy is unchanged. [normal] points from a to b.
  void _dampSpeedTransfer(
    SimulationBall a,
    SimulationBall b,
    Offset velocityA,
    Offset velocityB,
    Offset normal,
  ) {
    final speedA = velocityA.distance;
    final speedB = velocityB.distance;
    var newA = speedA + (a.velocity.distance - speedA) * collisionSpeedTransfer;
    var newB = speedB + (b.velocity.distance - speedB) * collisionSpeedTransfer;

    final energyBefore = speedA * speedA + speedB * speedB;
    final energyAfter = newA * newA + newB * newB;
    if (energyAfter > 0) {
      final scale = math.sqrt(energyBefore / energyAfter);
      newA *= scale;
      newB *= scale;
    }

    a.velocity = _directionAfterHit(a.velocity, velocityA, normal) * newA;
    b.velocity = _directionAfterHit(b.velocity, velocityB, -normal) * newB;

    // A ball must not keep moving into the other one (it would hit again
    // next step); mirror any such component, which keeps its speed.
    final intoB = a.velocity.dx * normal.dx + a.velocity.dy * normal.dy;
    if (intoB > 0) a.velocity -= normal * (2 * intoB);
    final intoA = -(b.velocity.dx * normal.dx + b.velocity.dy * normal.dy);
    if (intoA > 0) b.velocity += normal * (2 * intoA);
  }

  /// Unit direction for a ball after contact: the elastic result's direction,
  /// or (when the elastic result left it at rest) its incoming velocity
  /// mirrored off the contact, [towardOther] pointing at the other ball.
  Offset _directionAfterHit(
    Offset elastic,
    Offset incoming,
    Offset towardOther,
  ) {
    final elasticSpeed = elastic.distance;
    if (elasticSpeed > 1e-6) return elastic / elasticSpeed;
    final into = incoming.dx * towardOther.dx + incoming.dy * towardOther.dy;
    final mirrored = incoming - towardOther * (2 * into);
    final mirroredSpeed = mirrored.distance;
    return mirroredSpeed > 0 ? mirrored / mirroredSpeed : -towardOther;
  }

  void _pruneInactiveLines() {
    for (final ball in _balls) {
      ball.fanLines.removeWhere((line) {
        if (line.isActive) return false;
        _freeSlot(line);
        return true;
      });
    }
  }

  void _freeSlot(FanLine line) {
    if (_slotOwners[line.slotIndex]?.config.id == line.ownerBallId) {
      _slotOwners[line.slotIndex] = null;
    }
  }

  /// Cuts every line of [target] whose segment (rim anchor -> target center)
  /// passes through [cutter]'s body. Returns the cut lines.
  List<FanLine> _cutLinesCrossedBy(
    SimulationBall cutter,
    SimulationBall target,
  ) {
    final radiusSq = cutter.radius * cutter.radius;
    final cut = <FanLine>[];
    target.fanLines.removeWhere((line) {
      final distSq = MathUtils.distancePointToSegmentSquared(
        cutter.position,
        line.startPoint,
        target.position,
      );
      if (distSq > radiusSq) return false;
      line.isActive = false;
      _freeSlot(line);
      cut.add(line);
      return true;
    });
    return cut;
  }

  /// Claims free slots from the wall contact point toward [ball]'s own
  /// nearest line, walking both ways around the rim. A direction counts only
  /// if the free run ends at one of the ball's own slots. Returns how many
  /// slots were claimed.
  int _claimFromWallHit(SimulationBall ball, Offset contactPoint) {
    final contactSlot = _slotAt(math.atan2(contactPoint.dy, contactPoint.dx));
    if (_slotOwners[contactSlot] != null) return 0;

    final toClaim = <int>{};
    for (final step in const [1, -1]) {
      final run = <int>[];
      var slot = contactSlot;
      while (_slotOwners[slot] == null && run.length < rimSlotCount) {
        run.add(slot);
        slot = (slot + step) % rimSlotCount;
      }
      if (identical(_slotOwners[slot], ball)) toClaim.addAll(run);
    }

    for (final slot in toClaim) {
      _claimSlot(ball, slot);
    }
    return toClaim.length;
  }
}
