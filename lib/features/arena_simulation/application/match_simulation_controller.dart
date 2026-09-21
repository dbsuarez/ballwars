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

  final double arenaRadius;
  late final SeededRandom _rng;
  late final ArenaPhysicsEngine _physics;
  late final TerritoryEngine _territory;
  final ParticleSystem _particles = ParticleSystem();
  final FloatingTextManager _floatingTexts = FloatingTextManager();
  late final List<SimulationBall> _balls;

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
    _territory.initializeSplit(contestants.map((c) => c.id).toList());

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
        lineCount: TerritoryEngine.totalSectors ~/ contestants.length,
      );
    });
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
      _physics.resolveWallCollision(ball);
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

    if (_territory.winnerId != null) {
      _status = MatchStatus.finished;
    } else if (_territory.isSlowMotion()) {
      _status = MatchStatus.slowMotion;
    }
  }

  /// Permanently claims any sector whose line a ball's body is currently
  /// touching, for every ball that doesn't already own it -- this is the
  /// core territory mechanic: cutting a line permanently transfers it.
  /// Each sector's line runs from the fixed arena center to its fixed rim
  /// point, so the line itself never moves regardless of where any ball is.
  void _resolveLineCrossings() {
    final owners = _territory.sectorOwners;
    const sectorAngleStep = 2 * math.pi / TerritoryEngine.totalSectors;

    for (final claimant in _balls) {
      for (var i = 0; i < TerritoryEngine.totalSectors; i++) {
        final ownerId = owners[i];
        if (ownerId.isEmpty || ownerId == claimant.config.id) continue;

        final theta = i * sectorAngleStep;
        final rimPoint = Offset(math.cos(theta), math.sin(theta)) * arenaRadius;

        final overlap = MathUtils.segmentCircleOverlapRange(
          Offset.zero,
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
