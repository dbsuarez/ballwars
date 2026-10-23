import 'dart:math' as math;
import 'dart:ui';

import '../../../core/utils/math_utils.dart';
import '../../../core/utils/seeded_random.dart';
import '../../match_setup/domain/match_config.dart';
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
  PowerUpSystem(this.match, this.rng);

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

  /// Armed proximity mines waiting for an opponent of their owner.
  final List<ArmedMine> mines = [];

  /// Recent blasts, for drawing (removed after [PowerUpTuning.explosionShowSteps]).
  final List<Explosion> explosions = [];

  /// Recent portal exits and entries, retained briefly for the painter.
  final List<PortalFlash> portalFlashes = [];

  /// Portal openings at the arena edge. They are hazards, never pickups.
  final List<ArenaPortal> portals = [];

  /// Physical spike rows in the arena. They are hazards, never pickups.
  final List<SpikeWall> spikeWalls = [];

  /// Recent knife slashes, for drawing (removed after [PowerUpTuning.slashShowSteps]).
  final List<SlashMark> slashMarks = [];

  /// Balls being reeled in by a hook.
  final List<HookPull> pulls = [];

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

  /// Gatling rounds fired so far, also counted in [shots] (the screen plays the gatling sound for them).
  int gatlingShots = 0;

  /// Velocity of each frozen ball from before it was frozen, given back when it thaws.
  final Map<SimulationBall, Offset> _frozenVelocity = {};

  // Volleys: shots fired as one attack share an id; a shield that breaks on one of them softens the
  // rest of that volley too (see [_hit]).
  int _lastVolley = 0;
  final Map<SimulationBall, int> _burstVolley = {};
  final Map<SimulationBall, int> _shieldedVolley = {};

  // The damage label of the last volley that hit each ball, so a volley's hits add up in one label.
  final Map<SimulationBall, (int, FloatingText, num)> _volleyLabel = {};

  static const Color _damageColor = Color(0xFFFF6B6B);
  static const Color _blastColor = Color(0xFFFFB347);

  /// Fastest a held shield turns toward its threat, in radians per step.
  static const double _shieldTurnPerStep = 0.25;

  /// Largest seeded turn of an inner shotgun pellet off its place in the fan, in radians.
  static const double _pelletJitter = 0.03;

  /// Pick-up radius of a field power-up: a little smaller than the balls, so it follows the ball size.
  late final double fieldRadius =
      match.state.balls.first.radius * _t.fieldRadiusRatio;

  /// How many balls the match started with (spawn rate and field limit follow it).
  late final int _ballCount = match.state.balls.length;

  /// Advances the power-ups by one simulation step.
  ///
  /// Timers count down first, so an effect picked up in step N lasts its full count from step N + 1 on
  /// (a speed boost picked up in step N runs from step N + 1).
  void step() {
    _countDown();
    _triggerMines();
    _triggerPortals();
    _triggerSpikeWalls();
    _pickUpTouched();
    _sweep();
    _updateFrozen();
    _moveProjectiles();
    _reelIn();
    _aimAndFire();
    // The controller counts a step after it ran, so this is the 1-based number of the running step.
    final number = match.stepCount + 1;
    if (number >= _t.firstSpawnSteps &&
        (number - _t.firstSpawnSteps) % _t.spawnInterval(_ballCount) == 0) {
      _spawn(number);
    }
    _turnShields();
  }

  /// Gives [ball] the pickup [p] and takes [p] off the field. Power-ups apply
  /// without replacing equipment; a weapon replaces the one equipped weapon.
  void pickUp(SimulationBall ball, FieldPowerUp p) {
    field.remove(p);
    if (p.kind == PowerUpKind.mine || p.kind == PowerUpKind.phaseMine) {
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
        _yell(ball, 'YUM!');
      case PowerUpKind.speed:
        ball.speedLeft = _t.speedSteps;
        _yell(ball, 'ZOOM!');
      case PowerUpKind.ghost:
        ball.ghostLeft = _t.ghostSteps;
        _yell(ball, 'BOO!');
      case PowerUpKind.magnet:
        _pullNearest(ball);
        _yell(ball, 'MINE!');
      case PowerUpKind.repulsor:
        ball.repulsorLeft = PowerUpTuning.specialEffectSteps;
        _yell(ball, 'BACK OFF!');
      case PowerUpKind.timeBubble:
        ball.timeBubbleLeft = PowerUpTuning.specialEffectSteps;
        _yell(ball, 'TIME OUT!');
      case PowerUpKind.vampire:
        ball.vampireLeft = PowerUpTuning.specialEffectSteps;
        _yell(ball, 'I VANT YOUR POWER!');
      case PowerUpKind.mirror:
        ball.mirrorCharges++;
        _yell(ball, 'RETURN TO SENDER!');
      case PowerUpKind.overcharge:
        ball.overchargeLeft = PowerUpTuning.specialEffectSteps;
        _yell(ball, 'MAXIMUM POWER!');
      case PowerUpKind.gremlin:
        final target = _nearestTarget(ball);
        if (target != null) target.gremlinShots++;
        _yell(ball, 'CHAOS MODE!');
      case PowerUpKind.magneticField:
        ball.magneticFieldLeft = PowerUpTuning.specialEffectSteps;
        _yell(ball, 'NOTHING GETS THROUGH!');
      case PowerUpKind.goldenArmor:
        ball.goldenArmorHits = 2;
        _yell(ball, 'GOLDEN GUARD!');
      default:
        ball.equipWeapon(p.kind, dualWield: match.dualWield);
        // All-Out sword sweep: for a moment the new blade rakes through threads with a wider reach.
        if (p.kind.isBlade && match.mode == MatchMode.allOut) {
          ball.sweepLeft = PowerUpTuning.sweepSteps;
        }
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

  void _hitSpikes(SimulationBall ball, Offset at) {
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
      final damage = match.damage(ball, _t.arenaDamage(PowerUpKind.spikeWall));
      _showDamage(ball, at, damage, 0);
    } else {
      final cut = match.cutThreads(
        ball,
        _t.allOutThreads(PowerUpKind.spikeWall),
        near: at,
      );
      _showDamage(ball, at, cut, 0);
    }
    slashes++;
    _yell(ball, 'OUCH! SPIKES!');
  }

  void _triggerSpikeWalls() {
    if (spikeWalls.isEmpty) return;
    for (final wall in List<SpikeWall>.of(spikeWalls)) {
      final tangent = Offset(-math.sin(wall.angle), math.cos(wall.angle));
      final halfLength = fieldRadius * 0.48 * (wall.spikeCount - 1);
      final start = wall.position - tangent * halfLength;
      final end = wall.position + tangent * halfLength;
      for (final ball in match.state.balls) {
        if (!_alive(ball) || ball.isGhost) continue;
        final reach = ball.radius + fieldRadius * 0.48;
        if (MathUtils.distancePointToSegmentSquared(ball.position, start, end) >
            reach * reach) {
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
    final PowerUpKind kind;
    if (weapon.isBlade || weapon == PowerUpKind.orbitingFlail) {
      kind = weapon;
      slashes++;
      _yell(
        attacker,
        weapon == PowerUpKind.sword
            ? 'HIYAA!'
            : weapon == PowerUpKind.orbitingFlail
            ? 'WRECKING BALL!'
            : 'SLASH!',
      );
    } else if (weapon == PowerUpKind.shield && targetHeld.isEmpty) {
      kind = PowerUpKind.shield;
      _yell(attacker, 'SHIELD BASH!');
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
      if (ball.magneticFieldLeft > 0) ball.magneticFieldLeft--;
      if (!_alive(ball)) ball.magnetPending = false;
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
    explosions.add(Explosion(position: at, radius: radius));
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
            _cutLine(ball, line);
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
  void _spawn(int number) {
    // Uniform over the chosen kinds; with all of them chosen this draws exactly as with none chosen.
    final chosen = match.powerUpKinds;
    final kinds = chosen == null || chosen.length == PowerUpKind.values.length
        ? PowerUpKind.values
        : [
            for (final k in PowerUpKind.values)
              if (chosen.contains(k) || k.isTrap) k,
          ];
    if (kinds.isEmpty) return;
    final kind = kinds[rng.nextInt(kinds.length)];
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
      final distance = kind.isTrap
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

  /// Guns aim at the nearest opponent for [_t.aimSteps] steps, then fire. A gatling then
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
      // A frozen ball can't shoot; a ghost is purely defensive, so it holds its aim until it's solid.
      if (ball.frozenLeft > 0 || ball.isGhost) continue;
      final bursting = ball.burstLeft > 0;
      final guns = ball.equippedWeapons
          .where((weapon) => weapon.isGun)
          .toList();
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
          ball.removeWeapon(kind);
          switch (kind) {
            case PowerUpKind.shotgun:
              _fireShotgun(ball, target);
              _yell(ball, 'BLAM!');
            case PowerUpKind.gatling:
              _burstVolley[ball] = ++_lastVolley;
              _fire(ball, target, kind, 0, volley: _lastVolley);
              gatlingShots++;
              ball.burstLeft = _t.gatlingRounds - 1;
              _yell(ball, 'RATATAT!');
            case PowerUpKind.freeze:
              _fire(ball, target, kind, 0);
              _yell(ball, 'FREEZE!');
            case PowerUpKind.grenade:
              _throwGrenade(ball, target);
              _yell(ball, 'FIRE IN THE HOLE!');
            case PowerUpKind.hook:
              _fire(
                ball,
                target,
                kind,
                0,
                speedRatio: PowerUpTuning.hookSpeedRatio,
              );
              _yell(ball, 'COME OVER HERE!');
            case PowerUpKind.ricochetDisc:
              _fire(ball, target, kind, 0);
              _yell(ball, 'BANK SHOT!');
            case PowerUpKind.threadHarpoon:
              _fire(ball, target, kind, 0);
              _yell(ball, 'GIVE IT HERE!');
            case PowerUpKind.prismLaser:
              _fire(ball, target, kind, 0);
              _yell(ball, 'TASTE THE RAINBOW!');
            case PowerUpKind.swapCannon:
              _fire(ball, target, kind, 0);
              _yell(ball, 'SWAP INCOMING!');
            default:
              _fire(ball, target, kind, 0);
              _yell(ball, 'BANG!');
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
    const spread = PowerUpTuning.shotgunSpread;
    final volley = ++_lastVolley;
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
      );
    }
  }

  /// Throws a grenade from [ball]'s edge at where [target] is now; it explodes on the first opponent it
  /// meets or where it lands.
  void _throwGrenade(SimulationBall ball, SimulationBall target) {
    final toTarget = target.position - ball.position;
    final distance = toTarget.distance;
    final direction = distance == 0 ? const Offset(1, 0) : toTarget / distance;
    projectiles.add(
      Projectile(
        owner: ball,
        kind: PowerUpKind.grenade,
        position: ball.position + direction * ball.radius,
        velocity: direction * (match.arenaRadius * _t.grenadeSpeedRatio),
        landAt: target.position,
      ),
    );
    shots++;
  }

  /// Fires one projectile from [ball]'s edge toward [target], turned by [turn] radians.
  void _fire(
    SimulationBall ball,
    SimulationBall target,
    PowerUpKind kind,
    double turn, {
    int volley = 0,
    double? speedRatio,
  }) {
    final toTarget = target.position - ball.position;
    final sabotaged = ball.gremlinShots > 0;
    if (sabotaged) ball.gremlinShots--;
    final angle =
        math.atan2(toTarget.dy, toTarget.dx) + turn + (sabotaged ? math.pi : 0);
    final direction = Offset(math.cos(angle), math.sin(angle));
    projectiles.add(
      Projectile(
        owner: ball,
        kind: kind,
        position: ball.position + direction * ball.radius,
        velocity:
            direction *
            (match.arenaRadius * (speedRatio ?? _t.bulletSpeedRatio)),
        volley: volley,
      ),
    );
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
        if (identical(ball, p.owner) || ball.isEliminated || ball.isGhost) {
          continue;
        }
        final t = _entry(
          from,
          to,
          ball.position,
          ball.magneticFieldLeft > 0 ? ball.radius * 2 : ball.radius,
        );
        if (t != null && t < strikeAt) {
          struck = ball;
          strikeAt = t;
        }
      }
      var end = struck == null ? to : Offset.lerp(from, to, strikeAt)!;
      final landAt = p.landAt;
      if (landAt != null) {
        // A grenade flies over threads, and blows up on a ball or where it lands (or at the rim).
        final left = (landAt - from).distance;
        final landed = struck == null && (to - from).distance >= left;
        if (landed) end = landAt;
        if (struck != null || landed || end.distance >= match.arenaRadius) {
          p
            ..position = end
            ..spent = true;
          _explode(end, p.owner, PowerUpKind.grenade);
        } else {
          p.position = end;
        }
        continue;
      }

      // A hook's chain doesn't cut threads.
      if (allOut && p.kind != PowerUpKind.hook) {
        for (final ball in balls) {
          if (identical(ball, p.owner) || ball.isEliminated || ball.isGhost) {
            continue;
          }
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
          _yell(struck, 'RETURN TO SENDER!');
          continue;
        }
        p.spent = true;
        if (p.kind == PowerUpKind.hook) {
          _catch(p.owner, struck);
        } else {
          _hit(struck, p.kind, at: end, from: p.owner, volley: p.volley);
        }
      } else if (end.distance >= match.arenaRadius) {
        if ((p.kind == PowerUpKind.ricochetDisc ||
                p.kind == PowerUpKind.prismLaser) &&
            p.wallBounces == 0) {
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
    projectiles.removeWhere((p) => p.spent);
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
  }) {
    if (target.isGhost) return;
    if (target.magneticFieldLeft > 0) {
      _yell(target, 'REPELLED!');
      return;
    }
    hits++;
    target.hurtFlashLeft = MatchSimulationController.hurtFlashSteps;
    final impact = at ?? target.position;
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
      _yell(from, 'SWITCHEROO!');
    }
    final bash = kind == PowerUpKind.shield;
    if (match.mode == MatchMode.arsenal) {
      final power = (from?.overchargeLeft ?? 0) > 0 ? 1.5 : 1.0;
      final lost = match.damage(
        target,
        (bash ? _t.arenaShieldBash : _t.arenaDamage(kind)) * share * power,
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
        if (_cutLine(target, line)) cut++;
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
            _cutLine(target, line);
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
  void _yell(SimulationBall ball, String text) {
    match.state.floatingTexts.spawn(
      ball.position - Offset(0, ball.radius * 1.4),
      text,
      ball.config.primaryColor,
    );
  }

  /// Cuts [line] of [ball] (rim anchors are unique, so the thread nearest its own anchor is that thread)
  /// with a spark leaving the rim, like a body cut. False if it was already gone.
  bool _cutLine(SimulationBall ball, FanLine line) {
    if (match.cutThreads(ball, 1, near: line.startPoint) == 0) return false;
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
