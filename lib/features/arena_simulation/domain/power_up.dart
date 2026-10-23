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
  Projectile({required this.owner, required this.kind, required this.position, required this.velocity});

  final SimulationBall owner;
  final PowerUpKind kind;
  Offset position;
  final Offset velocity;

  /// Set once it has hit something or left the arena.
  bool spent = false;
}

/// A bomb that has been dropped and will explode when its fuse runs out.
/// A bomb that went off, kept for [PowerUpTuning.explosionShowSteps] steps so it can be drawn.
class Explosion {
  Explosion({required this.position, required this.radius});

  final Offset position;
  final double radius;

  /// Steps since it went off.
  int age = 0;
}

class PendingBomb {
  PendingBomb({required this.owner, required this.position, required this.fuseSteps});

  final SimulationBall owner;
  final Offset position;
  int fuseSteps;
}

/// Tunable numbers for the power-ups. Tests assert in terms of these, so they can be retuned freely.
class PowerUpTuning {
  PowerUpTuning._();

  /// Steps between two spawns (60 steps = 1 s).
  static const int spawnIntervalSteps = 300;
  static const int maxOnField = 3;

  /// Pick-up radius of a field power-up, as a fraction of the arena radius.
  static const double fieldRadiusRatio = 0.045;

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
  static const int bombFuseSteps = 60;

  /// Bomb blast radius as a fraction of the arena radius.
  static const double bombRadiusRatio = 0.28;

  /// How long a blast stays on screen (steps).
  static const int explosionShowSteps = 30;

  /// All-Out sword sweep: steps after a knife pickup during which the holder cuts with a wider reach,
  /// [sweepReach] times its radius.
  static const int sweepSteps = 60;
  static const double sweepReach = 1.8;

  /// Share of a hit's damage a shield absorbs.
  static const double shieldBlock = 0.75;

  /// Arsenal mode: life lost per hit (shotgun per pellet, gatling per round).
  static const Map<PowerUpKind, double> arenaDamage = {
    PowerUpKind.pistol: 12,
    PowerUpKind.shotgun: 3,
    PowerUpKind.gatling: 4,
    PowerUpKind.knife: 25,
    PowerUpKind.bomb: 30,
  };
  static const double arenaShieldBash = 8;
  static const double arenaAppleHeal = 25;

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
