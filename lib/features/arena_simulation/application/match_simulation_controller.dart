import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/ball_image_loader.dart';
import '../../../core/utils/math_utils.dart';
import '../../../core/utils/seeded_random.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../domain/arena_physics_engine.dart';
import '../domain/fan_line.dart';
import '../domain/floating_text.dart';
import '../domain/match_colors.dart';
import '../domain/particle_system.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import '../domain/territory_engine.dart';

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
  // or fewer.
  static const int slowMotionLineThreshold = 10;
  static const double slowMotionTimeScale = 0.25;

  final double arenaRadius;

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
  double _elapsedSeconds = 0.0;
  MatchStatus _status = MatchStatus.running;
  String? _winnerId;
  String? _lastEliminatedId;

  /// [layoutRotation] fixes where ball 0 starts (radians); by default the
  /// whole starting layout is rotated by a seeded random angle.
  MatchSimulationController(
    List<CustomBall> contestants, {
    required this.arenaRadius,
    int? seed,
    double restitution = 1.0,
    this.rimSlotCount = kRimSlotCount,
    double? layoutRotation,
  }) : seed = seed ?? DateTime.now().millisecondsSinceEpoch {
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

    final ballRadius = arenaRadius * ballRadiusRatio;
    // Line colors that are visible on the arena and distinct per contestant
    // (cosmetic only: ids and physics settings are untouched).
    final lineColors = MatchColors.resolve([for (final c in contestants) c.primaryColor]);

    _balls = List.generate(count, (i) {
      final angle = _startAngle(i, count);
      final radial = Offset(math.cos(angle), math.sin(angle));
      final position = radial * (arenaRadius * _rng.nextDoubleRange(startRadiusMin, startRadiusMax));
      final speed = _cruiseSpeed(contestants[i]) *
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

    _assignStartingSlots();
  }

  double _startAngle(int index, int count) => _layoutRotation + (2 * math.pi / count) * index;

  Offset _tangent(double angle) => Offset(-math.sin(angle), math.cos(angle));

  /// More balls means more cutters and much shorter matches, so crowded
  /// matches start slower: 2 / ball count (3 balls 67%, 4 balls 50%).
  double _crowdSpeedFactor(int count) => count > 2 ? 2 / count : 1.0;

  /// Starting speed in px/s. [CustomBall.baseSpeed] scales it relative to
  /// the default ball, so the default matches the reference video.
  double _cruiseSpeed(CustomBall config) =>
      arenaRadius * cruiseRadiiPerStep / fixedTimestep * (config.baseSpeed / CustomBall.defaultBaseSpeed);

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
      final shifted = (_slotAngle(slot) - _layoutRotation + share / 2) % (2 * math.pi);
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
    ball.fanLines.add(FanLine(
      ownerBallId: ball.config.id,
      slotIndex: slot,
      rimAngle: angle,
      startPoint: Offset(math.cos(angle) * arenaRadius, math.sin(angle) * arenaRadius),
      endPoint: ball.position,
    ));
  }

  /// Simulated match time so far; stops advancing once the match is finished.
  /// The last ball knocked out (the runner-up), once a match is decided.
  String? get lastEliminatedId => _lastEliminatedId;

  /// How long the match has been playing, in the time passed to [tick]
  /// (so slow motion counts at the speed it is watched). Stops at the finish.
  double get elapsedSeconds => _elapsedSeconds;

  Future<void> preloadImages() async {
    for (final ball in _balls) {
      ball.cachedUiImage = await BallImageLoader.load(ball.config);
    }
  }

  SimulationState get state => SimulationState(
        balls: _balls,
        territory: _createLegacyTerritoryForCompat(),
        particles: _particles,
        floatingTexts: _floatingTexts,
        status: _status,
        winnerId: _winnerId,
      );

  // Legacy territory for test compatibility - maps active fan lines to sectors
  TerritoryEngine _createLegacyTerritoryForCompat() {
    final territory = TerritoryEngine();
    for (final ball in _balls) {
      for (final line in ball.fanLines) {
        if (line.isActive) {
          territory.claimSector(ball.config.id, _sectorIndexAt(line.rimAngle));
        }
      }
    }
    return territory;
  }

  void tick(double realDeltaSeconds) {
    if (_status == MatchStatus.finished) {
      // The match is over, but the last sparks and texts finish animating.
      _particles.update(realDeltaSeconds);
      _floatingTexts.update(realDeltaSeconds);
      return;
    }

    _elapsedSeconds += realDeltaSeconds;
    final timeScale = _status == MatchStatus.slowMotion ? slowMotionTimeScale : 1.0;
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

  void _stepPhysics(double dt) {
    // Lines deactivated from outside the step (e.g. tests) free their slots.
    _pruneInactiveLines();
    final linesAtStart = {for (final ball in _balls) ball: ball.fanLines.length};

    // Who goes first rotates every step, so no contestant always wins ties
    // (e.g. two wall hits racing for the same free run).
    final order = [
      for (var k = 0; k < _balls.length; k++) _balls[(k + _stepCount) % _balls.length],
    ];

    // 1. Physics update & wall collision (wall hits claim free rim slots)
    for (final ball in order) {
      if (ball.isEliminated) continue;

      final previousPosition = ball.position;
      ball.position += ball.velocity * dt;
      final collision = _physics.resolveWallCollision(ball, previousPosition: previousPosition);
      if (collision != null) {
        _particles.spawnBurst(
          origin: collision.contactPoint,
          normal: collision.normal,
          color: ball.config.primaryColor,
          rng: _rng,
        );

        // Update ball rotation from collision
        ball.rotation += collision.normal.dx * 0.1;

        final claimed = _claimFromWallHit(ball, collision.contactPoint);
        if (claimed > 0) {
          _floatingTexts.spawn(collision.contactPoint, '+$claimed LINES', ball.config.primaryColor);
        }
      }
    }

    // 2. Ball-ball collisions
    for (var i = 0; i < order.length; i++) {
      for (var j = i + 1; j < order.length; j++) {
        final a = order[i];
        final b = order[j];
        if (a.isEliminated || b.isEliminated) continue;

        final velocityA = a.velocity;
        final velocityB = b.velocity;
        final result = _physics.resolveBallCollision(a, b);
        if (result != null) {
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
        }
      }
    }

    // 3. Lines follow their owner
    for (final ball in _balls) {
      if (ball.isEliminated) continue;
      for (final line in ball.fanLines) {
        line.endPoint = ball.position;
      }
    }

    // 4. Cutting: any opponent body overlapping a line cuts it
    for (final cutter in _balls) {
      if (cutter.isEliminated) continue;

      for (final target in _balls) {
        if (target.isEliminated) continue;
        if (identical(target, cutter)) continue;

        final cut = _cutLinesCrossedBy(cutter, target);
        if (cut.isEmpty) continue;

        // Direction from cutter to target
        final offset = target.position - cutter.position;
        final cutNormal = offset.distance > 0 ? offset / offset.distance : const Offset(1, 0);

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

    // 5. Elimination check: ball eliminated when all its lines are cut
    final eliminatedNow = <SimulationBall>[];
    for (final ball in _balls) {
      if (ball.isEliminated) continue;

      if (ball.fanLines.isEmpty) {
        ball.isEliminated = true;
        eliminatedNow.add(ball);
        _floatingTexts.spawn(ball.position, 'ELIMINATED', ball.config.primaryColor);
      }
    }

    // 6. Win condition: last ball with >=1 line wins
    var activeBalls = _balls.where((b) => !b.isEliminated).toList();
    if (activeBalls.isEmpty && eliminatedNow.isNotEmpty && _balls.length > 1) {
      // Everyone left lost their last line in the same step: the one that
      // held the most lines at the start of the step survives (seeded coin
      // flip on a tie), so a match never ends without a winner.
      final best = eliminatedNow.map((b) => linesAtStart[b]!).reduce(math.max);
      final tied = eliminatedNow.where((b) => linesAtStart[b] == best).toList();
      final survivor = tied[_rng.nextInt(tied.length)];
      survivor.isEliminated = false;
      activeBalls = [survivor];
    }
    final knockedOut = eliminatedNow.where((b) => b.isEliminated);
    if (knockedOut.isNotEmpty) _lastEliminatedId = knockedOut.last.config.id;
    if (activeBalls.length == 1 && _balls.length > 1) {
      _winnerId = activeBalls.first.config.id;
      _status = MatchStatus.finished;
    } else if (activeBalls.isEmpty) {
      _status = MatchStatus.finished;
    } else {
      // 7. Slow motion while the match is about to end: the final two are
      // left and one of them is down to a handful of lines. Normal speed
      // returns if that ball recovers.
      final endgame = activeBalls.length == 2 &&
          activeBalls.any((b) => b.fanLines.length <= slowMotionLineThreshold);
      _status = endgame ? MatchStatus.slowMotion : MatchStatus.running;
    }

    for (final ball in _balls) {
      ball.lineCount = ball.fanLines.length;
    }
  }

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
  Offset _directionAfterHit(Offset elastic, Offset incoming, Offset towardOther) {
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
  List<FanLine> _cutLinesCrossedBy(SimulationBall cutter, SimulationBall target) {
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

  int _sectorIndexAt(double angle) {
    final normalized = angle < 0 ? angle + 2 * math.pi : angle;
    final total = TerritoryEngine.totalSectors;
    final index = (normalized / (2 * math.pi / total)).round();
    return index % total;
  }
}
