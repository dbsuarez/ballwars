import 'dart:math' as math;
import 'dart:ui';

import 'simulation_ball.dart';

/// The power-ups a ball can pick up in the Arsenal and All-Out match modes.
enum PowerUpKind {
  pistol('Pistol'),
  shotgun('Shotgun'),
  gatling('Gatling'),
  knife('Knife'),
  shield('Shield'),
  apple('Apple'),
  speed('Speed'),
  freeze('Freeze'),
  bomb('Bomb'),
  magnet('Magnet'),
  ghost('Ghost');

  const PowerUpKind(this.label);

  /// Name shown to the player.
  final String label;

  /// True for the kinds that aim at an opponent and shoot.
  bool get isGun => this == pistol || this == shotgun || this == gatling || this == freeze;
}

/// A power-up lying in the arena, waiting to be picked up.
class FieldPowerUp {
  FieldPowerUp({required this.kind, required this.position, required this.spawnStep});

  final PowerUpKind kind;
  Offset position;

  /// Simulation step at which it appeared.
  final int spawnStep;
}

/// A bullet or pellet in flight.
class Projectile {
  Projectile({
    required this.owner,
    required this.kind,
    required this.position,
    required this.velocity,
    this.volley = 0,
  });

  final SimulationBall owner;
  final PowerUpKind kind;
  Offset position;
  final Offset velocity;

  /// Shots fired as one attack (a shotgun blast, a gatling burst) share a non-zero id, so a shield
  /// that breaks on the first of them softens the rest too. 0: a single shot.
  final int volley;

  /// Set once it has hit something or left the arena.
  bool spent = false;
}

/// A bomb that went off, kept for [PowerUpTuning.explosionShowSteps] steps so it can be drawn.
class Explosion {
  Explosion({required this.position, required this.radius});

  final Offset position;
  final double radius;

  /// Steps since it went off.
  int age = 0;
}

/// A knife slash, kept for [PowerUpTuning.slashShowSteps] steps so it can be drawn.
class SlashMark {
  SlashMark({required this.position, required this.angle});

  final Offset position;

  /// Direction of the cut, in radians.
  final double angle;

  /// Steps since the cut.
  int age = 0;
}

/// A proximity bomb set by the first ball that touched it. It stays where it lay and goes off the moment
/// an opponent of [owner] touches it; [owner] never sets it off and is spared by its blast. Armed bombs
/// don't count toward the field limit.
class ArmedBomb {
  ArmedBomb({required this.owner, required this.position, required this.armedStep});

  final SimulationBall owner;
  final Offset position;

  /// Simulation step at which it was set (for the blinking light).
  final int armedStep;
}

/// Tunable numbers for the power-ups. Tests assert in terms of these, so they can be retuned freely.
class PowerUpTuning {
  PowerUpTuning._();

  /// Steps between two spawns with 2 balls (60 steps = 1 s); see [spawnInterval].
  static const int spawnIntervalSteps = 300;

  /// Steps between two spawns for [ballCount] balls: more balls, more often (2: 5 s, 3: 3.3 s, 4: 2.5 s).
  static int spawnInterval(int ballCount) => (spawnIntervalSteps * 2 / math.max(2, ballCount)).round();

  /// Most unclaimed power-ups lying on the field for [ballCount] balls (2: 3, 3: 4, 4: 5); a new one
  /// removes the oldest.
  static int maxOnField(int ballCount) => math.max(2, ballCount) + 1;

  /// The first power-up comes after 1 s (then one every [spawnIntervalSteps]), so even short matches see
  /// one (probe: with the first at 5 s only about half of All-Out matches did).
  static const int firstSpawnSteps = 60;

  /// Pick-up radius of a field power-up, as a fraction of the balls' radius (so it follows the chosen
  /// ball size, a little smaller than a ball).
  static const double fieldRadiusRatio = 0.7;

  /// Spawns keep away from the rim and the very center: between these fractions of the arena radius.
  static const double spawnMinDistance = 0.2;
  static const double spawnMaxDistance = 0.68;

  /// Starting life of a ball in Arsenal mode.
  static const double arenaLife = 100.0;

  /// Steps a gun aims at its target before firing (1 s).
  static const int aimSteps = 60;

  /// Bullet speed in arena radii per second.
  static const double bulletSpeedRatio = 1.2;
  static const int shotgunPellets = 10;

  /// Total spread of the shotgun fan, in radians.
  static const double shotgunSpread = 0.7;
  static const int gatlingRounds = 10;
  static const int gatlingIntervalSteps = 6;
  static const int speedSteps = 180;
  static const double speedFactor = 2.0;
  static const int freezeSteps = 120;
  static const int ghostSteps = 180;

  /// Bomb blast radius as a fraction of the arena radius.
  static const double bombRadiusRatio = 0.28;

  /// How long a blast stays on screen (steps).
  static const int explosionShowSteps = 30;

  /// How long a knife slash stays on screen (steps).
  static const int slashShowSteps = 14;

  /// All-Out sword sweep: steps after a knife pickup during which the holder cuts with a wider reach,
  /// [sweepReach] times its radius.
  static const int sweepSteps = 60;
  static const double sweepReach = 1.8;

  /// Share of a hit's damage a shield absorbs.
  static const double shieldBlock = 0.75;

  /// Arsenal mode: life lost per hit (shotgun per pellet, gatling per round).
  static const Map<PowerUpKind, double> arenaDamage = {
    PowerUpKind.pistol: 50,
    PowerUpKind.shotgun: 12,
    PowerUpKind.gatling: 15,
    PowerUpKind.knife: 70,
    PowerUpKind.bomb: 80,
  };
  static const double arenaShieldBash = 30;
  static const double arenaAppleHeal = 25;

  /// Arsenal: an apple at full life still counts, up to this much life (the extra shows as gold hearts).
  static const double arenaMaxLife = 150;

  /// All-Out mode: threads (rim slots) lost per hit.
  static const Map<PowerUpKind, int> allOutThreads = {
    PowerUpKind.pistol: 8,
    PowerUpKind.shotgun: 2,
    PowerUpKind.gatling: 3,
    PowerUpKind.knife: 15,
    PowerUpKind.bomb: 10,
  };
  static const int allOutShieldBash = 5;
  static const int allOutAppleSlots = 20;

  /// All-Out: share of the threads a hit would cut that are still lost when a shield takes it.
  static const double allOutShieldKeep = 0.5;
}

/// What [kind] does, with its numbers from [PowerUpTuning], for the weapons list in Match Setup.
/// [arsenal]: damage in life (Arsenal); otherwise in lines (All-Out). Damage is for 2 balls (see
/// [crowdNote]).
String powerUpDescription(PowerUpKind kind, {required bool arsenal}) {
  String secs(int steps) {
    final s = steps / 60;
    return s == s.roundToDouble() ? '${s.round()} s' : '${s.toStringAsFixed(1)} s';
  }

  String dmg(PowerUpKind k) => arsenal
      ? '${PowerUpTuning.arenaDamage[k]!.round()} damage'
      : '${PowerUpTuning.allOutThreads[k]} lines';
  final aim = 'Aims ${secs(PowerUpTuning.aimSteps)}, then';
  final block = (PowerUpTuning.shieldBlock * 100).round();
  return switch (kind) {
    PowerUpKind.pistol => '$aim fires one shot: ${dmg(kind)}.',
    PowerUpKind.shotgun => '$aim fires a fan of ${PowerUpTuning.shotgunPellets} pellets: ${dmg(kind)} each.',
    PowerUpKind.gatling => '$aim fires ${PowerUpTuning.gatlingRounds} rounds: ${dmg(kind)} each.',
    PowerUpKind.knife => 'Carried until it stabs the next ball it touches: ${dmg(kind)}.',
    PowerUpKind.shield => arsenal
        ? 'Blocks $block% of the next hit. Bashes an unarmed ball: '
            '${PowerUpTuning.arenaShieldBash.round()} damage.'
        : 'Halves the lines lost to the next hit. Bashes an unarmed ball: '
            '${PowerUpTuning.allOutShieldBash} lines.',
    PowerUpKind.apple => arsenal
        ? 'Heals ${PowerUpTuning.arenaAppleHeal.round()} life, even past full '
            '(up to ${PowerUpTuning.arenaMaxLife.round()}).'
        : 'Adds up to ${PowerUpTuning.allOutAppleSlots} lines from free rim spots.',
    PowerUpKind.speed => '${PowerUpTuning.speedFactor.round()}x speed for ${secs(PowerUpTuning.speedSteps)}.',
    PowerUpKind.freeze => '$aim freezes the target for ${secs(PowerUpTuning.freezeSteps)}. No damage.',
    PowerUpKind.bomb => 'The first ball to touch it sets it. It explodes when an opponent touches it: '
        '${dmg(kind)} to everyone nearby but its owner.',
    PowerUpKind.magnet => 'Pulls the nearest power-up (or the next one) straight to the ball.',
    PowerUpKind.ghost => 'For ${secs(PowerUpTuning.ghostSteps)} passes through balls and can\'t be hit.',
  };
}

/// Arsenal: how damage grows with more balls (matches [MatchSimulationController.damage]).
const String crowdNote = 'Damage is x2.25 with 3 balls and x4 with 4.';
