import 'dart:math' as math;
import 'dart:ui';

import '../../../core/utils/seeded_random.dart';
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

  /// Pick-up radius of a field power-up.
  double get fieldRadius => match.arenaRadius * PowerUpTuning.fieldRadiusRatio;

  /// Advances the power-ups by one simulation step.
  void step() {
    _pickUpTouched();
    // The controller counts a step after it ran, so this is the 1-based number of the running step.
    final number = match.stepCount + 1;
    if (number % PowerUpTuning.spawnIntervalSteps == 0) _spawn(number);
  }

  /// Gives [ball] the power-up [p] in place of whatever it held, and takes [p] off the field.
  void pickUp(SimulationBall ball, FieldPowerUp p) {
    ball.held = p.kind;
    field.remove(p);
    pickups++;
  }

  void _pickUpTouched() {
    if (field.isEmpty) return;
    final radius = fieldRadius;
    for (final ball in match.state.balls) {
      if (ball.isEliminated) continue;
      for (final p in List<FieldPowerUp>.of(field)) {
        if ((p.position - ball.position).distance < ball.radius + radius) pickUp(ball, p);
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
}
