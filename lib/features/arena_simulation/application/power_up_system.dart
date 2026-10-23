import '../../../core/utils/seeded_random.dart';
import '../domain/power_up.dart';
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

  /// Advances the power-ups by one simulation step.
  void step() {}
}
