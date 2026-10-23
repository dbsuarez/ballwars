import 'dart:math' as math;
import 'dart:ui';

import '../../../core/utils/math_utils.dart';
import '../../../core/utils/seeded_random.dart';
import '../../match_setup/domain/match_config.dart';
import '../domain/fan_line.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import 'match_simulation_controller.dart';

/// Runs the power-ups of an Arsenal or All-Out match: spawning, pick-up, aiming, projectiles, bombs and
/// the personal effects (apple, speed, ghost, magnet, shield).
///
/// The controller creates one (never in Threads mode), calls [onContact] for every ball-ball bump and
/// [step] once per simulation step, right after the ball-ball collisions. All randomness comes from the
/// match's [rng], drawn only inside the simulation step.
///
/// Guns, the knife and the shield are held ([SimulationBall.held]) until used. Apple, speed, ghost, bomb
/// and magnet act at once. A ball never has two power-ups: any pickup drops the one it held.
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

  /// Recent blasts, for drawing (removed after [PowerUpTuning.explosionShowSteps]).
  final List<Explosion> explosions = [];

  /// How many power-ups balls have picked up so far (the screen plays a sound when it goes up).
  int pickups = 0;

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

  /// Velocity of each frozen ball from before it was frozen, given back when it thaws.
  final Map<SimulationBall, Offset> _frozenVelocity = {};

  /// Fastest a held shield turns toward its threat, in radians per step.
  static const double _shieldTurnPerStep = 0.25;

  /// Largest seeded turn of an inner shotgun pellet off its place in the fan, in radians.
  static const double _pelletJitter = 0.03;

  /// Pick-up radius of a field power-up.
  double get fieldRadius => match.arenaRadius * PowerUpTuning.fieldRadiusRatio;

  /// Advances the power-ups by one simulation step.
  ///
  /// Timers count down first, so an effect picked up in step N lasts its full count from step N + 1 on
  /// (a bomb picked up in step N explodes in step N + [PowerUpTuning.bombFuseSteps]).
  void step() {
    _countDown();
    _explodeBombs();
    _pickUpTouched();
    _sweep();
    _updateFrozen();
    _moveProjectiles();
    _aimAndFire();
    // The controller counts a step after it ran, so this is the 1-based number of the running step.
    final number = match.stepCount + 1;
    if (number >= PowerUpTuning.firstSpawnSteps &&
        (number - PowerUpTuning.firstSpawnSteps) % PowerUpTuning.spawnIntervalSteps == 0) {
      _spawn(number);
    }
    _turnShields();
  }

  /// Gives [ball] the power-up [p] and takes [p] off the field. Whatever [ball] held is dropped (a ball
  /// never has two power-ups); a held kind takes its place, the others act at once.
  void pickUp(SimulationBall ball, FieldPowerUp p) {
    field.remove(p);
    pickups++;
    ball.held = null;
    // A new power-up starts its own aim (a gatling burst already firing finishes first).
    if (ball.burstLeft == 0) {
      ball
        ..aimLeft = 0
        ..aimTarget = null;
    }
    switch (p.kind) {
      case PowerUpKind.apple:
        _eatApple(ball);
      case PowerUpKind.speed:
        ball.speedLeft = PowerUpTuning.speedSteps;
      case PowerUpKind.ghost:
        ball.ghostLeft = PowerUpTuning.ghostSteps;
      case PowerUpKind.bomb:
        bombs.add(PendingBomb(owner: ball, position: ball.position, fuseSteps: PowerUpTuning.bombFuseSteps));
      case PowerUpKind.magnet:
        _pullNearest(ball);
      default:
        ball.held = p.kind;
        // All-Out sword sweep: for a moment the new blade rakes through threads with a wider reach.
        if (p.kind == PowerUpKind.knife && match.mode == MatchMode.allOut) ball.sweepLeft = PowerUpTuning.sweepSteps;
    }
  }

  /// Melee on a bump between [a] and [b]: a knife hits the other ball and is used up; a shield bashes an
  /// unarmed other ball (one holding nothing) and breaks. Both sides strike with what they held when they
  /// touched, so two knives hit each other. Nothing happens if either is a ghost or already out.
  void onContact(SimulationBall a, SimulationBall b) {
    if (!_alive(a) || !_alive(b) || a.isGhost || b.isGhost) return;
    final heldA = a.held;
    final heldB = b.held;
    _melee(a, heldA, b, heldB);
    _melee(b, heldB, a, heldA);
  }

  void _melee(SimulationBall attacker, PowerUpKind? weapon, SimulationBall target, PowerUpKind? targetHeld) {
    final PowerUpKind kind;
    if (weapon == PowerUpKind.knife) {
      kind = PowerUpKind.knife;
      slashes++;
    } else if (weapon == PowerUpKind.shield && targetHeld == null) {
      kind = PowerUpKind.shield;
    } else {
      return;
    }
    if (attacker.held == weapon) attacker.held = null;
    final toAttacker = attacker.position - target.position;
    final distance = toAttacker.distance;
    final at = distance > 0 ? target.position + toAttacker * (target.radius / distance) : target.position;
    _hit(target, kind, at: at, from: attacker);
  }

  /// True while [ball] is still in the match: not eliminated, and not already at 0 life (Arsenal) or out
  /// of threads (All-Out) earlier in this step, before the elimination check has marked it.
  bool _alive(SimulationBall ball) =>
      !ball.isEliminated && (match.mode == MatchMode.arsenal ? ball.life > 0 : ball.fanLines.isNotEmpty);

  /// Counts the speed boosts, ghosts and sweeps down, ages blasts; a ball that is out drops its waiting
  /// magnet.
  void _countDown() {
    for (final e in explosions) {
      e.age++;
    }
    explosions.removeWhere((e) => e.age >= PowerUpTuning.explosionShowSteps);
    for (final ball in match.state.balls) {
      if (ball.speedLeft > 0) ball.speedLeft--;
      if (ball.ghostLeft > 0) ball.ghostLeft--;
      if (ball.sweepLeft > 0) ball.sweepLeft--;
      if (!_alive(ball)) ball.magnetPending = false;
    }
  }

  /// Arsenal: heals [PowerUpTuning.arenaAppleHeal], up to full life. All-Out: claims up to
  /// [PowerUpTuning.allOutAppleSlots] free rim slots with the "+N LINES" pop (none when none are free).
  /// Either way a green sparkle bursts from the ball.
  void _eatApple(SimulationBall ball) {
    if (match.mode == MatchMode.arsenal) {
      ball.life = math.min(PowerUpTuning.arenaLife, ball.life + PowerUpTuning.arenaAppleHeal);
    } else {
      final claimed = match.claimFreeSlots(ball, PowerUpTuning.allOutAppleSlots);
      if (claimed > 0) match.state.floatingTexts.spawn(ball.position, '+$claimed LINES', ball.config.primaryColor);
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

  /// Bombs burn down their fuse and explode, hitting every ball whose body is within
  /// [PowerUpTuning.bombRadiusRatio] arena radii of the bomb, its owner included (ghosts are spared).
  void _explodeBombs() {
    if (bombs.isEmpty) return;
    final radius = match.arenaRadius * PowerUpTuning.bombRadiusRatio;
    for (final bomb in List.of(bombs)) {
      if (--bomb.fuseSteps > 0) continue;
      bombs.remove(bomb);
      blasts++;
      explosions.add(Explosion(position: bomb.position, radius: radius));
      // All-Out bomb blast: every thread passing through the blast is cut, from every ball but ghosts.
      if (match.mode == MatchMode.allOut) {
        for (final ball in match.state.balls) {
          if (!_alive(ball) || ball.isGhost) continue;
          for (final line in List.of(ball.fanLines)) {
            if (MathUtils.distancePointToSegmentSquared(bomb.position, line.startPoint, ball.position) <=
                radius * radius) {
              _cutLine(ball, line);
            }
          }
        }
      }
      for (final ball in match.state.balls) {
        if (!_alive(ball)) continue;
        final offset = ball.position - bomb.position;
        final distance = offset.distance;
        if (distance - ball.radius > radius) continue;
        // The side of the ball facing the bomb, so the splash flies away from the blast.
        final at = distance > ball.radius
            ? bomb.position + offset * ((distance - ball.radius) / distance)
            : bomb.position;
        _hit(ball, PowerUpKind.bomb, at: at);
      }
    }
  }

  /// Turns every held shield toward its biggest threat: the nearest enemy projectile coming at it, else
  /// the nearest opponent. Only shows where it braces; a shield blocks from every side.
  void _turnShields() {
    for (final ball in match.state.balls) {
      if (ball.held != PowerUpKind.shield || !_alive(ball)) continue;
      final threat = _incoming(ball)?.position ?? _nearestTarget(ball)?.position;
      if (threat == null) continue;
      final toThreat = threat - ball.position;
      final want = math.atan2(toThreat.dy, toThreat.dx);
      final turn = _wrap(want - ball.shieldAngle).clamp(-_shieldTurnPerStep, _shieldTurnPerStep);
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
  static double _wrap(double angle) => (angle + math.pi) % (2 * math.pi) - math.pi;

  void _pickUpTouched() {
    if (field.isEmpty) return;
    final radius = fieldRadius;
    for (final ball in match.state.balls) {
      if (!_alive(ball)) continue;
      // At most one per step, so a second one in reach is not used up unseen. The index is found first,
      // so [field] is never changed while it is being walked.
      final index = field.indexWhere((p) => (p.position - ball.position).distance < ball.radius + radius);
      if (index >= 0) pickUp(ball, field[index]);
    }
  }

  void _spawn(int number) {
    // Uniform over the chosen kinds; with all of them chosen this draws exactly as before.
    final chosen = match.powerUpKinds;
    final kinds = chosen == null || chosen.length == PowerUpKind.values.length
        ? PowerUpKind.values
        : [for (final k in PowerUpKind.values) if (chosen.contains(k)) k];
    if (kinds.isEmpty) return;
    final kind = kinds[rng.nextInt(kinds.length)];
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
      final spawned = FieldPowerUp(kind: kind, position: spot, spawnStep: number);
      field.add(spawned);
      if (field.length > PowerUpTuning.maxOnField) field.removeAt(0);
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

  /// Guns aim at the nearest opponent for [PowerUpTuning.aimSteps] steps, then fire. A gatling then
  /// fires its other rounds one every [PowerUpTuning.gatlingIntervalSteps] steps. Balls that are out
  /// (or lost their last life or thread earlier this step) or frozen neither aim nor fire (bullets
  /// already in flight still fly).
  void _aimAndFire() {
    for (final ball in match.state.balls) {
      if (!_alive(ball)) {
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
              _cutLine(ball, line);
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

  /// Every weapon hit lands here (bullets, pellets, freeze shots, knife, shield bash, bomb). A ghost can't
  /// be hit at all. A held shield absorbs part of the hit, then breaks: [PowerUpTuning.shieldBlock] of it
  /// in Arsenal, while in All-Out only [PowerUpTuning.allOutShieldKeep] of the threads are lost. Arsenal
  /// takes life off [target], All-Out snaps its threads nearest the impact point [at]; both splash "blood"
  /// in the target's color. A freeze shot instead stops the target for [PowerUpTuning.freezeSteps] steps
  /// (shortened the same way by a shield). [kind] [PowerUpKind.shield] is a shield bash. [from] is the
  /// attacker (null for a bomb: the splash then flies away from [at]).
  void _hit(SimulationBall target, PowerUpKind kind, {Offset? at, SimulationBall? from}) {
    if (target.isGhost) return;
    hits++;
    target.hurtFlashLeft = MatchSimulationController.hurtFlashSteps;
    final impact = at ?? target.position;
    var share = 1.0;
    if (target.held == PowerUpKind.shield) {
      target.held = null;
      blocks++;
      share = match.mode == MatchMode.arsenal ? 1 - PowerUpTuning.shieldBlock : PowerUpTuning.allOutShieldKeep;
    }
    if (kind == PowerUpKind.freeze) {
      final steps = (PowerUpTuning.freezeSteps * share).round();
      if (steps > target.frozenLeft) {
        if (target.frozenLeft == 0) _frozenVelocity[target] = target.velocity;
        target.frozenLeft = steps;
      }
      if (target.frozenLeft > 0) target.velocity = Offset.zero;
      return;
    }
    final bash = kind == PowerUpKind.shield;
    if (match.mode == MatchMode.arsenal) {
      match.damage(target, (bash ? PowerUpTuning.arenaShieldBash : PowerUpTuning.arenaDamage[kind] ?? 0) * share);
    } else {
      // Thread snap: the threads nearest the impact break, each with its rim spark.
      final threads = ((bash ? PowerUpTuning.allOutShieldBash : PowerUpTuning.allOutThreads[kind] ?? 0) * share).round();
      final nearest = [...target.fanLines]
        ..sort((x, y) => (x.startPoint - impact).distanceSquared.compareTo((y.startPoint - impact).distanceSquared));
      for (final line in nearest.take(threads)) {
        _cutLine(target, line);
      }
    }
    match.state.particles.spawnBlood(
      origin: impact,
      direction: target.position - (from?.position ?? impact),
      color: target.config.primaryColor,
      rng: rng,
    );
  }

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
        if (identical(target, cutter) || !_alive(target) || target.isGhost) continue;
        for (final line in List.of(target.fanLines)) {
          if (MathUtils.distancePointToSegmentSquared(cutter.position, line.startPoint, target.position) <=
              reach * reach) {
            _cutLine(target, line);
          }
        }
      }
    }
  }

  /// Cuts [line] of [ball] (rim anchors are unique, so the thread nearest its own anchor is that thread)
  /// with a spark leaving the rim, like a body cut.
  void _cutLine(SimulationBall ball, FanLine line) {
    if (match.cutThreads(ball, 1, near: line.startPoint) == 0) return;
    match.state.particles.spawnRimArcs(
      origin: line.startPoint,
      normal: Offset(math.cos(line.rimAngle), math.sin(line.rimAngle)),
      arenaRadius: match.arenaRadius,
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
