import 'dart:math' as math;
import 'dart:ui';

import '../../../core/utils/seeded_random.dart';
import '../../match_setup/domain/match_config.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import 'match_simulation_controller.dart';

/// Runs the power-ups of an Arsenal or All-Out match: spawning, pick-up, aiming, projectiles and bombs.
///
/// The controller creates one (never in Threads mode) and calls [step] once per simulation step, right
/// after the ball-ball collisions. All randomness comes from the match's [rng], drawn only inside [step].
class PowerUpSystem {
  PowerUpSystem(this.match, this.rng);

  /// The match this system belongs to (for [MatchSimulationController.damage] and
  /// [MatchSimulationController.cutThreads]).
  final MatchSimulationController match;

  /// The match's random source.
  final SeededRandom rng;

  /// Power-ups lying in the arena.
  final List<FieldPowerUp> field = [];

  /// Bullets and pellets in flight.
  final List<Projectile> projectiles = [];

  /// Dropped bombs waiting to explode.
  final List<PendingBomb> bombs = [];

  /// How many power-ups balls have picked up so far (the screen plays a sound when it goes up).
  int pickups = 0;

  /// Bullets, pellets and freeze shots fired so far (the screen plays a sound when it goes up).
  int shots = 0;

  /// Weapon hits landed on balls so far (the screen plays a sound when it goes up).
  int hits = 0;

  /// Velocity of each frozen ball from before it was frozen, given back when it thaws.
  final Map<SimulationBall, Offset> _frozenVelocity = {};

  /// Largest seeded turn of an inner shotgun pellet off its place in the fan, in radians.
  static const double _pelletJitter = 0.03;

  /// Pick-up radius of a field power-up.
  double get fieldRadius => match.arenaRadius * PowerUpTuning.fieldRadiusRatio;

  /// Advances the power-ups by one simulation step.
  void step() {
    _pickUpTouched();
    _updateFrozen();
    _moveProjectiles();
    _aimAndFire();
    // The controller counts a step after it ran, so this is the 1-based number of the running step.
    final number = match.stepCount + 1;
    if (number % PowerUpTuning.spawnIntervalSteps == 0) _spawn(number);
  }

  /// Gives [ball] the power-up [p] in place of whatever it held, and takes [p] off the field.
  void pickUp(SimulationBall ball, FieldPowerUp p) {
    ball.held = p.kind;
    // A new power-up starts its own aim (a gatling burst already firing finishes first).
    if (ball.burstLeft == 0) {
      ball
        ..aimLeft = 0
        ..aimTarget = null;
    }
    field.remove(p);
    pickups++;
  }

  void _pickUpTouched() {
    if (field.isEmpty) return;
    final radius = fieldRadius;
    for (final ball in match.state.balls) {
      if (ball.isEliminated) continue;
      // At most one per step, so a second one in reach is not used up unseen.
      for (final p in field) {
        if ((p.position - ball.position).distance < ball.radius + radius) {
          pickUp(ball, p);
          break;
        }
      }
    }
  }

  void _spawn(int number) {
    final kind = PowerUpKind.values[rng.nextInt(PowerUpKind.values.length)];
    final radius = fieldRadius;
    final reach = match.arenaRadius - radius;
    final balls = match.state.balls;
    for (var attempt = 0; attempt < 10; attempt++) {
      final angle = rng.nextDoubleRange(0, 2 * math.pi);
      final distance = reach * math.sqrt(rng.nextDouble());
      final spot = Offset(math.cos(angle) * distance, math.sin(angle) * distance);
      final clear = balls.every((b) => b.isEliminated || (b.position - spot).distance >= b.radius + radius) &&
          field.every((f) => (f.position - spot).distance >= 2 * radius);
      if (!clear) continue;
      field.add(FieldPowerUp(kind: kind, position: spot, spawnStep: number));
      if (field.length > PowerUpTuning.maxOnField) field.removeAt(0);
      return;
    }
  }

  /// Counts frozen balls down: they stay still (even after a bump) and get their old velocity back when
  /// the freeze runs out.
  void _updateFrozen() {
    for (final ball in match.state.balls) {
      if (ball.frozenLeft <= 0) continue;
      ball.frozenLeft--;
      if (ball.frozenLeft == 0) {
        ball.velocity = _frozenVelocity.remove(ball) ?? ball.velocity;
      } else {
        ball.velocity = Offset.zero;
      }
    }
  }

  /// The nearest opponent of [ball] a gun can aim at (not out, not a ghost), or null.
  SimulationBall? _nearestTarget(SimulationBall ball) {
    SimulationBall? best;
    var bestDistance = double.infinity;
    for (final other in match.state.balls) {
      if (identical(other, ball) || other.isEliminated || other.isGhost) continue;
      final distance = (other.position - ball.position).distanceSquared;
      if (distance < bestDistance) {
        best = other;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Guns aim at the nearest opponent for [PowerUpTuning.aimSteps] steps, then fire. A gatling then
  /// fires its other rounds one every [PowerUpTuning.gatlingIntervalSteps] steps. Balls that are out or
  /// frozen neither aim nor fire (bullets already in flight still fly).
  void _aimAndFire() {
    for (final ball in match.state.balls) {
      if (ball.isEliminated) {
        ball
          ..aimLeft = 0
          ..aimTarget = null
          ..burstLeft = 0;
        continue;
      }
      if (ball.frozenLeft > 0) continue;
      final bursting = ball.burstLeft > 0;
      if (!bursting && ball.held?.isGun != true) continue;
      final target = _nearestTarget(ball);
      ball.aimTarget = target;
      if (target == null) {
        // Nobody to aim at: a new aim starts over once someone is.
        if (!bursting) ball.aimLeft = 0;
        continue;
      }
      if (!bursting && ball.aimLeft == 0) ball.aimLeft = PowerUpTuning.aimSteps;
      ball.aimLeft--;
      if (ball.aimLeft > 0) continue;

      if (bursting) {
        _fire(ball, target, PowerUpKind.gatling, 0);
        ball.burstLeft--;
      } else {
        final kind = ball.held!;
        ball.held = null;
        switch (kind) {
          case PowerUpKind.shotgun:
            _fireShotgun(ball, target);
          case PowerUpKind.gatling:
            _fire(ball, target, kind, 0);
            ball.burstLeft = PowerUpTuning.gatlingRounds - 1;
          default:
            _fire(ball, target, kind, 0);
        }
      }
      if (ball.burstLeft > 0) {
        ball.aimLeft = PowerUpTuning.gatlingIntervalSteps;
      } else {
        ball.aimTarget = null;
      }
    }
  }

  /// Fans [PowerUpTuning.shotgunPellets] pellets evenly over [PowerUpTuning.shotgunSpread]. The inner
  /// pellets get a seeded jitter of up to [_pelletJitter]; the two outer ones mark the fan's edges.
  void _fireShotgun(SimulationBall ball, SimulationBall target) {
    const count = PowerUpTuning.shotgunPellets;
    const spread = PowerUpTuning.shotgunSpread;
    for (var i = 0; i < count; i++) {
      final edge = i == 0 || i == count - 1;
      final jitter = edge ? 0.0 : rng.nextDoubleRange(-_pelletJitter, _pelletJitter);
      _fire(ball, target, PowerUpKind.shotgun, -spread / 2 + spread * i / (count - 1) + jitter);
    }
  }

  /// Fires one projectile from [ball]'s edge toward [target], turned by [turn] radians.
  void _fire(SimulationBall ball, SimulationBall target, PowerUpKind kind, double turn) {
    final toTarget = target.position - ball.position;
    final angle = math.atan2(toTarget.dy, toTarget.dx) + turn;
    final direction = Offset(math.cos(angle), math.sin(angle));
    projectiles.add(Projectile(
      owner: ball,
      kind: kind,
      position: ball.position + direction * ball.radius,
      velocity: direction * (match.arenaRadius * PowerUpTuning.bulletSpeedRatio),
    ));
    shots++;
  }

  /// Moves every projectile one step. A projectile strikes the first ball (not its owner, not out, not a
  /// ghost) its path enters and is spent, or is spent at the rim. In All-Out it also cuts the opponent
  /// threads its path crosses on the way.
  void _moveProjectiles() {
    if (projectiles.isEmpty) return;
    final balls = match.state.balls;
    final allOut = match.mode == MatchMode.allOut;
    for (final p in projectiles) {
      if (p.spent) continue;
      final from = p.position;
      final to = from + p.velocity * MatchSimulationController.fixedTimestep;

      SimulationBall? struck;
      var strikeAt = double.infinity;
      for (final ball in balls) {
        if (identical(ball, p.owner) || ball.isEliminated || ball.isGhost) continue;
        final t = _entry(from, to, ball.position, ball.radius);
        if (t != null && t < strikeAt) {
          struck = ball;
          strikeAt = t;
        }
      }
      final end = struck == null ? to : Offset.lerp(from, to, strikeAt)!;

      if (allOut) {
        for (final ball in balls) {
          if (identical(ball, p.owner) || ball.isEliminated || ball.isGhost) continue;
          for (final line in List.of(ball.fanLines)) {
            // Rim anchors are unique, so the thread nearest a thread's own anchor is that thread.
            if (_crosses(from, end, line.startPoint, ball.position)) {
              match.cutThreads(ball, 1, near: line.startPoint);
            }
          }
        }
      }

      p.position = end;
      if (struck != null) {
        p.spent = true;
        _hit(struck, p.kind, at: end, from: p.owner);
      } else if (end.distance >= match.arenaRadius) {
        p.spent = true;
      }
    }
    projectiles.removeWhere((p) => p.spent);
  }

  /// Every weapon hit lands here. Arsenal takes life off [target], All-Out snaps its threads nearest the
  /// impact point [at]; both splash "blood" in the target's color. A freeze shot instead stops the target
  /// for [PowerUpTuning.freezeSteps] steps. [from] is the attacker.
  void _hit(SimulationBall target, PowerUpKind kind, {Offset? at, SimulationBall? from}) {
    hits++;
    final impact = at ?? target.position;
    if (kind == PowerUpKind.freeze) {
      if (target.frozenLeft == 0) _frozenVelocity[target] = target.velocity;
      target
        ..frozenLeft = PowerUpTuning.freezeSteps
        ..velocity = Offset.zero;
      return;
    }
    if (match.mode == MatchMode.arsenal) {
      match.damage(target, PowerUpTuning.arenaDamage[kind] ?? 0);
    } else {
      match.cutThreads(target, PowerUpTuning.allOutThreads[kind] ?? 0, near: impact);
    }
    match.state.particles.spawnBlood(
      origin: impact,
      direction: target.position - (from?.position ?? impact),
      color: target.config.primaryColor,
      rng: rng,
    );
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
    double side(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    return side(q1, q2, p1) * side(q1, q2, p2) < 0 && side(p1, p2, q1) * side(p1, p2, q2) < 0;
  }
}
