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
import '../domain/thread.dart';

class MatchSimulationController {
  static const double fixedTimestep = 1 / 60;
  static const int maxStepsPerFrame = 10;
  static const double cuttingTolerance = 8.0;

  final double arenaRadius;
  late final SeededRandom _rng;
  late final ArenaPhysicsEngine _physics;
  final ParticleSystem _particles = ParticleSystem();
  final FloatingTextManager _floatingTexts = FloatingTextManager();
  late final List<SimulationBall> _balls;
  final List<Thread> _threads = [];

  double _accumulator = 0.0;
  MatchStatus _status = MatchStatus.running;
  String? _winnerId;

  MatchSimulationController(
    List<CustomBall> contestants, {
    required this.arenaRadius,
    int? seed,
    double restitution = 0.85,
  }) {
    final resolvedSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    _rng = SeededRandom(resolvedSeed);
    _physics = ArenaPhysicsEngine(arenaRadius, _rng, restitution: restitution);

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
        lineCount: 1, // Each ball starts with one thread
      );
    });

    // Initialize threads: each ball gets a thread anchored at its
    // initial wall projection (direction from center through ball to wall).
    _initializeThreads();
  }

  void _initializeThreads() {
    _threads.clear();
    for (final ball in _balls) {
      // Initial thread anchor: project from center through ball to wall
      final direction = ball.position.distance == 0
          ? const Offset(1.0, 0.0)
          : ball.position / ball.position.distance;
      final startPoint = direction * arenaRadius;
      _threads.add(Thread(
        ownerBallId: ball.config.id,
        startPoint: startPoint,
        endPoint: ball.position,
      ));
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
        threads: List.unmodifiable(_threads),
        territory: _createLegacyTerritoryForCompat(),
        particles: _particles,
        floatingTexts: _floatingTexts,
        status: _status,
        winnerId: _winnerId,
      );

  // Legacy territory for test compatibility - maps active threads to sectors
  TerritoryEngine _createLegacyTerritoryForCompat() {
    final territory = TerritoryEngine();
    for (final thread in _threads) {
      if (thread.isActive) {
        final startSector = _sectorIndexAt(thread.startPoint);
        final endSector = _sectorIndexAt(thread.endPoint);
        _fillLegacyArc(territory, thread.ownerBallId, startSector, endSector);
      }
    }
    return territory;
  }

  void _fillLegacyArc(TerritoryEngine territory, String ballId, int fromSector, int toSector) {
    final int total = TerritoryEngine.totalSectors;
    final int forwardDistance = (toSector - fromSector + total) % total;
    final int backwardDistance = (fromSector - toSector + total) % total;

    var index = fromSector;
    if (forwardDistance <= backwardDistance) {
      while (true) {
        territory.claimSector(ballId, index);
        if (index == toSector) break;
        index = (index + 1) % total;
      }
    } else {
      while (true) {
        territory.claimSector(ballId, index);
        if (index == toSector) break;
        index = (index - 1 + total) % total;
      }
    }
  }

  void tick(double realDeltaSeconds) {
    if (_status == MatchStatus.finished) return;

    final timeScale = _status == MatchStatus.slowMotion ? 0.25 : 1.0;
    _accumulator += realDeltaSeconds * timeScale;

    // Cap accumulator to prevent spiral of death
    final maxAccumulator = fixedTimestep * maxStepsPerFrame;
    if (_accumulator > maxAccumulator) {
      _accumulator = maxAccumulator;
    }

    while (_accumulator >= fixedTimestep) {
      _stepPhysics(fixedTimestep);
      _accumulator -= fixedTimestep;
    }

    _particles.update(realDeltaSeconds);
    _floatingTexts.update(realDeltaSeconds);
  }

  void _stepPhysics(double dt) {
    // 1. Physics update & wall collision
    for (final ball in _balls) {
      if (ball.isEliminated) continue;

      ball.position += ball.velocity * dt;
      final collision = _physics.resolveWallCollision(ball);
      if (collision != null && collision.wallAnchorPoint != null) {
        // Re-anchor thread on wall bounce
        _reanchorThread(ball.config.id, collision.wallAnchorPoint!);
      }
    }

    // 2. Ball-ball collisions
    for (var i = 0; i < _balls.length; i++) {
      for (var j = i + 1; j < _balls.length; j++) {
        final a = _balls[i];
        final b = _balls[j];
        if (a.isEliminated || b.isEliminated) continue;

        final result = _physics.resolveBallCollision(a, b);
        if (result != null) {
          _particles.spawnBurst(
            origin: result.contactPoint,
            normal: result.normal,
            color: a.config.primaryColor,
            rng: _rng,
          );
        }
      }
    }

    // 3. Update thread endpoints (follow ball centers)
    for (final thread in _threads) {
      if (!thread.isActive) continue;
      final ball = _balls.firstWhere(
        (b) => b.config.id == thread.ownerBallId,
        orElse: () => throw StateError('Ball not found for thread ${thread.ownerBallId}'),
      );
      if (!ball.isEliminated) {
        thread.endPoint = ball.position;
      }
    }

    // 4. Thread cutting: other balls cut threads they don't own
    for (final ball in _balls) {
      if (ball.isEliminated) continue;

      for (final thread in _threads) {
        if (!thread.isActive) continue;
        if (thread.ownerBallId == ball.config.id) continue;

        final distSq = MathUtils.distancePointToSegmentSquared(
          ball.position,
          thread.startPoint,
          thread.endPoint,
        );
        final thresholdSq = (ball.radius + cuttingTolerance) * (ball.radius + cuttingTolerance);

        if (distSq <= thresholdSq) {
          thread.isActive = false;
          _particles.spawnBurst(
            origin: thread.endPoint,
            normal: (ball.position - thread.endPoint) / (ball.position - thread.endPoint).distance,
            color: ball.config.primaryColor,
            rng: _rng,
          );
          _floatingTexts.spawn(thread.endPoint, 'CUT!', ball.config.primaryColor);
          // TODO: Play snap audio via sound service interface
        }
      }
    }

    // 5. Elimination check
    for (final ball in _balls) {
      if (ball.isEliminated) continue;

      final activeThreadCount = _threads.where((t) =>
          t.ownerBallId == ball.config.id && t.isActive).length;

      if (activeThreadCount == 0) {
        ball.isEliminated = true;
        _floatingTexts.spawn(ball.position, 'ELIMINATED', ball.config.primaryColor);
      }
    }

    // 6. Win condition: last non-eliminated ball wins
    final activeBalls = _balls.where((b) => !b.isEliminated).toList();
    if (activeBalls.length == 1) {
      _winnerId = activeBalls.first.config.id;
      _status = MatchStatus.finished;
    } else if (activeBalls.isEmpty) {
      // All eliminated in same tick - draw, last one standing before this tick wins
      // For simplicity, treat as draw with no winner
      _status = MatchStatus.finished;
    }

    // Update lineCount for compatibility (count active threads)
    for (final ball in _balls) {
      ball.lineCount = _threads.where((t) =>
          t.ownerBallId == ball.config.id && t.isActive).length;
    }
  }

  int _sectorIndexAt(Offset position) {
    final angle = math.atan2(position.dy, position.dx);
    final normalized = angle < 0 ? angle + 2 * math.pi : angle;
    final total = TerritoryEngine.totalSectors;
    final index = (normalized / (2 * math.pi / total)).round();
    return index % total;
  }

  void _reanchorThread(String ballId, Offset newAnchor) {
    for (final thread in _threads) {
      if (thread.ownerBallId == ballId && thread.isActive) {
        thread.startPoint = newAnchor;
        break;
      }
    }
  }
}