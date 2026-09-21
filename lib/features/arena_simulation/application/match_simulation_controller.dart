import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/canvas_image_helper.dart';
import '../../../core/utils/math_utils.dart';
import '../../../core/utils/seeded_random.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../domain/arena_physics_engine.dart';
import '../domain/floating_text.dart';
import '../domain/particle_system.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import '../domain/territory_engine.dart';

class MatchSimulationController {
  static const double fixedTimestep = 1 / 60;

  /// How many sectors on either side of a ball's first rim touch get
  /// claimed as its small starting seed.
  static const int _seedHalfWidth = 3;

  final double arenaRadius;
  late final SeededRandom _rng;
  late final ArenaPhysicsEngine _physics;
  late final TerritoryEngine _territory;
  final ParticleSystem _particles = ParticleSystem();
  final FloatingTextManager _floatingTexts = FloatingTextManager();
  late final List<SimulationBall> _balls;

  /// Each ball's most recent rim-touch sector, used as the anchor for
  /// filling the arc to its next rim touch. Null until that ball has
  /// touched the rim for the first time.
  final Map<String, int?> _rimAnchor = {};

  double _accumulator = 0.0;
  MatchStatus _status = MatchStatus.running;

  MatchSimulationController(
    List<CustomBall> contestants, {
    required this.arenaRadius,
    int? seed,
  }) {
    final resolvedSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    _rng = SeededRandom(resolvedSeed);
    _physics = ArenaPhysicsEngine(arenaRadius, _rng);
    _territory = TerritoryEngine();

    final ballRadius = arenaRadius * 0.08;
    _balls = List.generate(contestants.length, (i) {
      final angle = (2 * math.pi / contestants.length) * i;
      final startRadius = arenaRadius * 0.4;
      final position = Offset(
        math.cos(angle) * startRadius,
        math.sin(angle) * startRadius,
      );
      final speed = contestants[i].baseSpeed;
      final velocity = Offset(math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2)) * speed;
      return SimulationBall(
        config: contestants[i],
        position: position,
        velocity: velocity,
        radius: ballRadius,
        lineCount: 0,
      );
    });

    for (final ball in _balls) {
      _rimAnchor[ball.config.id] = null;
    }
  }

  Future<void> preloadImages() async {
    for (final ball in _balls) {
      final bytes = ball.config.imageBytes;
      if (bytes == null) continue;
      ball.cachedUiImage = await CanvasImageHelper.decode(bytes);
    }
  }

  SimulationState get state => SimulationState(
        balls: _balls,
        territory: _territory,
        particles: _particles,
        floatingTexts: _floatingTexts,
        status: _status,
        winnerId: _territory.winnerId,
      );

  void tick(double realDeltaSeconds) {
    if (_status == MatchStatus.finished) return;

    final timeScale = _status == MatchStatus.slowMotion ? 0.25 : 1.0;
    _accumulator += realDeltaSeconds * timeScale;

    while (_accumulator >= fixedTimestep) {
      _stepPhysics(fixedTimestep);
      _accumulator -= fixedTimestep;
    }

    _particles.update(realDeltaSeconds);
    _floatingTexts.update(realDeltaSeconds);
  }

  void _stepPhysics(double dt) {
    for (final ball in _balls) {
      ball.position += ball.velocity * dt;
      final bounced = _physics.resolveWallCollision(ball);
      if (bounced) {
        _handleRimTouch(ball);
      }
    }

    for (var i = 0; i < _balls.length; i++) {
      for (var j = i + 1; j < _balls.length; j++) {
        final result = _physics.resolveBallCollision(_balls[i], _balls[j]);
        if (result != null) {
          _particles.spawnBurst(
            origin: result.contactPoint,
            normal: result.normal,
            color: _balls[i].config.primaryColor,
            rng: _rng,
          );
        }
      }
    }

    _resolveLineCrossings();

    for (final ball in _balls) {
      ball.lineCount = _territory.countSectors(ball.config.id);
    }

    final contestantIds = _balls.map((b) => b.config.id).toList();
    _territory.updatePeaks(contestantIds);

    final allContestantsStarted = _rimAnchor.values.every((anchor) => anchor != null);
    _territory.evaluateWinCondition(
      contestantIds,
      allContestantsStarted: allContestantsStarted,
    );

    if (_territory.winnerId != null) {
      _status = MatchStatus.finished;
    } else if (_territory.isSlowMotion()) {
      _status = MatchStatus.slowMotion;
    }
  }

  /// Handles a ball bouncing off the rim: its first touch ever claims a
  /// small seed of sectors around the touch point; every touch after that
  /// fills the whole arc between its previous touch and this one.
  void _handleRimTouch(SimulationBall ball) {
    final touchedSector = _sectorIndexAt(ball.position);
    final anchor = _rimAnchor[ball.config.id];

    if (anchor == null) {
      for (var offset = -_seedHalfWidth; offset <= _seedHalfWidth; offset++) {
        final index = (touchedSector + offset + TerritoryEngine.totalSectors) % TerritoryEngine.totalSectors;
        _territory.claimSector(ball.config.id, index);
      }
    } else {
      _fillArc(ball.config.id, anchor, touchedSector);
    }

    _rimAnchor[ball.config.id] = touchedSector;
  }

  /// Claims every sector along the shorter arc from [fromSector] to
  /// [toSector] (inclusive) for [ballId].
  void _fillArc(String ballId, int fromSector, int toSector) {
    final total = TerritoryEngine.totalSectors;
    final forwardDistance = (toSector - fromSector + total) % total;
    final backwardDistance = (fromSector - toSector + total) % total;

    var index = fromSector;
    if (forwardDistance <= backwardDistance) {
      while (true) {
        _territory.claimSector(ballId, index);
        if (index == toSector) break;
        index = (index + 1) % total;
      }
    } else {
      while (true) {
        _territory.claimSector(ballId, index);
        if (index == toSector) break;
        index = (index - 1 + total) % total;
      }
    }
  }

  int _sectorIndexAt(Offset position) {
    final angle = math.atan2(position.dy, position.dx);
    final normalized = angle < 0 ? angle + 2 * math.pi : angle;
    final index = (normalized / (2 * math.pi / TerritoryEngine.totalSectors)).round();
    return index % TerritoryEngine.totalSectors;
  }

  /// Permanently claims any sector whose line a ball's body is currently
  /// touching, for every ball that doesn't already own it -- this is the
  /// core territory mechanic: cutting a line permanently transfers it.
  void _resolveLineCrossings() {
    final owners = _territory.sectorOwners;
    const sectorAngleStep = 2 * math.pi / TerritoryEngine.totalSectors;

    for (final claimant in _balls) {
      for (var i = 0; i < TerritoryEngine.totalSectors; i++) {
        final ownerId = owners[i];
        if (ownerId.isEmpty || ownerId == claimant.config.id) continue;

        final ownerBall = _balls.where((b) => b.config.id == ownerId);
        if (ownerBall.isEmpty) continue;

        final theta = i * sectorAngleStep;
        final rimPoint = Offset(math.cos(theta), math.sin(theta)) * arenaRadius;

        final overlap = MathUtils.segmentCircleOverlapRange(
          ownerBall.first.position,
          rimPoint,
          claimant.position,
          claimant.radius,
        );
        if (overlap == null) continue;

        _territory.claimSector(claimant.config.id, i);
      }
    }
  }
}
