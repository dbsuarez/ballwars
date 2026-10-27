import 'dart:math' as math;
import 'dart:ui';

import 'power_up_config.dart';
import 'simulation_ball.dart';

enum PowerUpRarity {
  normal('Normal', Color(0xFFFFFFFF)),
  rare('Rare', Color(0xFF58A6FF)),
  epic('Epic', Color(0xFFB775FF)),
  special('Special', Color(0xFFFFD54F));

  const PowerUpRarity(this.label, this.color);
  final String label;
  final Color color;
}

enum ArenaThemeHazardKind { gravityWell, quicksand, vineSnare, laserGate }

class ArenaThemeHazard {
  ArenaThemeHazard({
    required this.kind,
    required this.position,
    required this.spawnStep,
    this.angle = 0,
  });

  final ArenaThemeHazardKind kind;
  final Offset position;
  final int spawnStep;
  final double angle;
  int age = 0;
  final Set<SimulationBall> affected = {};
}

/// Pickups a ball can collect in the Arsenal and All-Out match modes.
enum PowerUpKind {
  pistol('Pistol'),
  shotgun('Shotgun'),
  gatling('Gatling'),
  knife('Knife'),
  shield('Shield'),
  apple('Apple'),
  speed('Speed'),
  freeze('Freeze'),
  mine('Mine'),
  magnet('Magnet'),
  ghost('Ghost'),
  // New kinds go last: links store the chosen kinds as a bitmask of their index.
  grenade('Grenade'),
  sword('Sword'),
  hook('Hook'),
  ricochetDisc('Ricochet Disc'),
  orbitingFlail('Orbiting Flail'),
  threadHarpoon('Thread Harpoon'),
  prismLaser('Prism Laser'),
  swapCannon('Swap Cannon'),
  phaseMine('Phase Mine'),
  repulsor('Repulsor'),
  timeBubble('Time Bubble'),
  vampire('Vampire'),
  mirror('Mirror'),
  overcharge('Overcharge'),
  gremlin('Gremlin'),
  magneticField('Magnetic Force Field'),
  portal('Portal'),
  spikeWall('Spike Wall'),
  goldenArmor('Golden Armor'),
  bow('Bow'),
  stickyGoo('Sticky Goo'),
  molotov('Molotov'),
  rocketLauncher('Rocket Launcher'),
  omegaTendrils('Omega Tendrils'),
  boomerang('Boomerang'),
  fireWall('Fire Wall Magic'),
  poisonSwamp('Poison Swamp'),
  waterGun('Water Gun'),
  lightningStrikes('Lightning Strikes'),
  earthquake('Earthquake'),
  tornado('Tornado'),
  energyWave('Energy Wave'),
  flamethrower('Flamethrower'),
  friedChicken('Fried Chicken'),
  sniperRifle('Sniper Rifle'),
  busterSword('Buster Sword'),
  ragingDemon('Raging Demon');

  const PowerUpKind(this.label);

  /// Name shown to the player.
  final String label;

  /// True for the kinds that aim at an opponent and shoot.
  bool get isGun =>
      this == pistol ||
      this == shotgun ||
      this == gatling ||
      this == freeze ||
      this == grenade ||
      this == molotov ||
      this == hook ||
      this == ricochetDisc ||
      this == threadHarpoon ||
      this == prismLaser ||
      this == swapCannon ||
      this == bow ||
      this == rocketLauncher ||
      this == boomerang ||
      this == fireWall ||
      this == waterGun ||
      this == energyWave ||
      this == flamethrower ||
      this == sniperRifle ||
      this == busterSword;

  /// True for the melee kinds used up on the next ball they touch.
  bool get isBlade => this == knife || this == sword;

  /// Two-handed weapons cannot share the dual-wield loadout.
  bool get isTwoHanded =>
      this == rocketLauncher ||
      this == gatling ||
      this == bow ||
      this == threadHarpoon ||
      this == energyWave ||
      this == flamethrower ||
      this == sniperRifle ||
      this == busterSword;

  /// Camera emphasis for a successful hit; subtle shots stay crisp while
  /// heavyweight attacks move the whole arena.
  double get impactWeight => switch (this) {
    rocketLauncher || omegaTendrils || energyWave => 1.0,
    sniperRifle || busterSword || ragingDemon => 1.0,
    flamethrower => 0.72,
    grenade || mine || phaseMine || molotov || fireWall => 0.8,
    sword || orbitingFlail || spikeWall || threadHarpoon => 0.48,
    shotgun || bow || ricochetDisc || boomerang => 0.3,
    _ => 0.16,
  };

  /// Weapons occupy the ball's single equipment slot. Keeping this category
  /// explicit leaves room for a future multi-weapon loadout.
  bool get isWeapon =>
      this == pistol ||
      this == shotgun ||
      this == gatling ||
      this == knife ||
      this == shield ||
      this == freeze ||
      this == grenade ||
      this == molotov ||
      this == sword ||
      this == hook ||
      this == ricochetDisc ||
      this == orbitingFlail ||
      this == threadHarpoon ||
      this == prismLaser ||
      this == swapCannon ||
      this == bow ||
      this == rocketLauncher ||
      this == boomerang ||
      this == fireWall ||
      this == waterGun ||
      this == energyWave ||
      this == flamethrower ||
      this == sniperRifle ||
      this == busterSword;

  /// Traps spawn close to the arena boundary and arm when collected.
  bool get isTrap =>
      this == mine ||
      this == phaseMine ||
      this == portal ||
      this == spikeWall ||
      this == stickyGoo ||
      this == poisonSwamp;

  /// Power-ups apply immediately and never replace an equipped weapon.
  bool get isPowerUp => !isWeapon && !isTrap;

  /// Traps retain their separate spawn rules and have no rarity tier.
  PowerUpRarity? get rarity {
    if (isTrap) return null;
    return switch (this) {
      pistol ||
      knife ||
      apple ||
      speed ||
      magnet ||
      bow ||
      waterGun => PowerUpRarity.normal,
      sniperRifle || busterSword => PowerUpRarity.special,
      gatling ||
      threadHarpoon ||
      ghost ||
      overcharge ||
      goldenArmor ||
      rocketLauncher ||
      omegaTendrils ||
      fireWall ||
      lightningStrikes ||
      earthquake ||
      tornado ||
      energyWave ||
      flamethrower ||
      friedChicken ||
      ragingDemon => PowerUpRarity.epic,
      _ => PowerUpRarity.rare,
    };
  }

  /// Whether this item can directly remove life or threads and therefore be
  /// credited as a finishing move under [config]. Buffs that merely improve
  /// another weapon keep that weapon's name as the winning move.
  bool dealsDamage(PowerUpConfig config) =>
      config.arenaDamage(this) > 0 ||
      config.allOutThreads(this) > 0 ||
      (this == shield &&
          (config.arenaShieldBash > 0 || config.allOutShieldBash > 0));
}

/// A power-up lying in the arena, waiting to be picked up.
class FieldPowerUp {
  FieldPowerUp({
    required this.kind,
    required this.position,
    required this.spawnStep,
    this.skillId,
  });

  final PowerUpKind kind;
  final String? skillId;
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
    this.landAt,
    this.target,
    this.homing = true,
    this.returning = false,
    this.returnTo,
    this.renderScale = 1,
    this.spinDegreesPerSecond = 0,
  });

  /// A grenade's landing point (where its target was when thrown); null for bullets.
  final Offset? landAt;
  SimulationBall? target;
  final bool homing;

  SimulationBall owner;
  final PowerUpKind kind;
  Offset position;
  Offset velocity;
  int wallBounces = 0;
  bool returning;
  final Offset? returnTo;
  final double renderScale;
  final double spinDegreesPerSecond;
  final Set<SimulationBall> hitTargets = {};

  /// Shots fired as one attack (a shotgun blast, a gatling burst) share a non-zero id, so a shield
  /// that breaks on the first of them softens the rest too. 0: a single shot.
  final int volley;

  /// Set once it has hit something or left the arena.
  bool spent = false;
}

/// A spent firearm casing that falls under gravity and remains at the arena
/// floor. The simulation keeps only a capped number so long Mayhem matches do
/// not grow painting or update work without bound.
class ShellCasing {
  ShellCasing({
    required this.position,
    required this.velocity,
    required this.angle,
  });

  Offset position;
  Offset velocity;
  double angle;
  bool settled = false;
}

class SniperFlash {
  SniperFlash({required this.owner, required this.target});
  final SimulationBall owner;
  final SimulationBall target;
  int age = 0;
}

class OmnislashAttack {
  OmnislashAttack({required this.owner, required this.target});
  final SimulationBall owner;
  final SimulationBall target;
  int age = 0;
  int hitsShown = 0;
}

class RagingDemonAttack {
  RagingDemonAttack({
    required this.owner,
    required this.target,
    required this.totalHits,
  });
  final SimulationBall owner;
  final SimulationBall target;
  final int totalHits;
  int age = 0;
  int hitsShown = 0;
}

/// A bomb that went off, kept for [PowerUpTuning.explosionShowSteps] steps so it can be drawn.
class Explosion {
  Explosion({required this.position, required this.radius, this.kind});

  final Offset position;
  final double radius;
  final PowerUpKind? kind;

  /// Steps since it went off.
  int age = 0;
}

class WeaponImpact {
  WeaponImpact({required this.position, required this.strength});

  final Offset position;
  final double strength;
  int age = 0;
}

/// A Molotov fire left on the floor for three seconds.
class BurningZone {
  BurningZone({
    required this.owner,
    required this.position,
    required this.radius,
  });

  final SimulationBall owner;
  final Offset position;
  final double radius;
  int age = 0;
}

/// A short-lived pair of rings marking where a portal took a ball from and
/// where it reappeared.
class PortalFlash {
  PortalFlash({required this.from, required this.to, this.swap = false});

  final Offset from;
  final Offset to;
  final bool swap;
  int age = 0;
}

/// A portal opening embedded near the arena boundary. It is entered by
/// collision and never appears in the collectible field list.
class ArenaPortal {
  ArenaPortal({required this.position, required this.spawnStep});

  final Offset position;
  final int spawnStep;
}

/// A physical row of spikes placed near the arena boundary. Unlike pickup
/// tokens, balls collide with the row directly.
class SpikeWall {
  SpikeWall({
    required this.position,
    required this.angle,
    required this.spawnStep,
    this.spikeCount = 6,
  });

  final Offset position;
  final double angle;
  final int spawnStep;
  final int spikeCount;

  /// Positions each spike along the arena arc instead of a straight chord.
  List<Offset> spikePositions(double spacing) {
    final radius = position.distance;
    if (radius == 0) return List<Offset>.filled(spikeCount, Offset.zero);
    final centerAngle = math.atan2(position.dy, position.dx);
    final angleStep = spacing / radius;
    final start = -(spikeCount - 1) / 2;
    return [
      for (var i = 0; i < spikeCount; i++)
        Offset(
              math.cos(centerAngle + (start + i) * angleStep),
              math.sin(centerAngle + (start + i) * angleStep),
            ) *
            radius,
    ];
  }
}

class StickyGoo {
  const StickyGoo({required this.position, required this.spawnStep});

  final Offset position;
  final int spawnStep;

  /// Separate goo clumps distributed along the same curved rim as spike walls.
  List<Offset> blobPositions(double spacing, {int count = 15}) {
    final radius = position.distance;
    if (radius == 0) return List<Offset>.filled(count, Offset.zero);
    final centerAngle = math.atan2(position.dy, position.dx);
    final angleStep = spacing / radius;
    final start = -(count - 1) / 2;
    return [
      for (var i = 0; i < count; i++)
        Offset.fromDirection(centerAngle + (start + i) * angleStep, radius),
    ];
  }
}

class PoisonSwamp {
  const PoisonSwamp({required this.position, required this.spawnStep});

  final Offset position;
  final int spawnStep;

  List<Offset> samplePositions(double spacing, {int count = 15}) => StickyGoo(
    position: position,
    spawnStep: spawnStep,
  ).blobPositions(spacing, count: count);
}

class FireWall {
  FireWall({required this.owner, required this.center, required this.angle});

  final SimulationBall owner;
  final Offset center;
  final double angle;
  int age = 0;
}

class DamageOverTime {
  DamageOverTime({
    required this.target,
    required this.kind,
    this.owner,
    required this.stepsLeft,
  });

  final SimulationBall target;
  final SimulationBall? owner;
  final PowerUpKind kind;
  int stepsLeft;
  int age = 0;
}

class LightningStrike {
  LightningStrike({required this.owner, required this.target});

  final SimulationBall owner;
  final SimulationBall target;
  int strikesLeft = 3;
  int delay = 1;
  int flashLeft = 0;
}

class EarthquakePulse {
  EarthquakePulse({required this.owner});
  final SimulationBall owner;
  int pulsesLeft = 3;
  int delay = 1;
  int flashLeft = 0;
}

class Tornado {
  Tornado({
    required this.owner,
    required this.target,
    required this.position,
    this.aimSteps = 30,
  });
  final SimulationBall owner;
  final SimulationBall target;
  Offset position;
  int age = 0;
  final int aimSteps;
  bool get isAiming => age <= aimSteps;
}

class EnergyWave {
  EnergyWave({
    required this.owner,
    required this.start,
    required this.end,
    this.durationSteps = EnergyWaveAttack.beamSteps,
    this.sweepStartAngle,
    this.sweepEndAngle,
  });
  final SimulationBall owner;
  final Offset start;
  final Offset end;
  final int durationSteps;
  final double? sweepStartAngle;
  final double? sweepEndAngle;
  int age = 0;
}

class EnergyWaveAttack {
  EnergyWaveAttack({
    required this.owner,
    required this.targets,
    required this.direction,
  }) : savedOwnerVelocity = owner.velocity,
       savedOwnerPosition = owner.position,
       savedVelocities = {
         for (final target in targets) target: target.velocity,
       },
       savedPositions = {
         for (final target in targets) target: target.position,
       } {
    final bounds = sweepBounds(
      owner.position,
      targets.map((ball) => ball.position),
    );
    startAngle = bounds.$1;
    endAngle = bounds.$2;
  }

  static const int chargeSteps = 36;
  static const int hitIntervalSteps = 14;
  static const int beamSteps = 120;

  final SimulationBall owner;
  final List<SimulationBall> targets;
  final Offset direction;
  late final double startAngle;
  late final double endAngle;
  final Offset savedOwnerVelocity;
  final Offset savedOwnerPosition;
  final Map<SimulationBall, Offset> savedVelocities;
  final Map<SimulationBall, Offset> savedPositions;
  int age = 0;
  int currentIndex = -1;
  final Set<SimulationBall> hitTargets = {};
  bool fired = false;

  /// The smallest sector containing every opponent, as seen from the caster.
  /// Exclude the largest empty angular gap, handling the -pi/pi boundary.
  static (double, double) sweepBounds(Offset caster, Iterable<Offset> targets) {
    final angles = targets.map((target) {
      final delta = target - caster;
      return math.atan2(delta.dy, delta.dx) % (2 * math.pi);
    }).toList()..sort();
    if (angles.isEmpty) return (0, 0);
    var gap = -1.0;
    var startIndex = 0;
    for (var i = 0; i < angles.length; i++) {
      final next = i + 1 < angles.length
          ? angles[i + 1]
          : angles.first + 2 * math.pi;
      if (next - angles[i] > gap) {
        gap = next - angles[i];
        startIndex = (i + 1) % angles.length;
      }
    }
    final padding = math.min(0.15, gap / 4);
    final start = angles[startIndex] - padding;
    return (start, start + (2 * math.pi - gap) + 2 * padding);
  }

  static double sweepProgress(int beamAge) =>
      (beamAge / (beamSteps - 1)).clamp(0.0, 1.0);
}

class FlameCone {
  FlameCone({required this.owner, required this.angle});
  final SimulationBall owner;
  final double angle;
  int age = 0;
}

/// A hooked ball being reeled in by [owner]: it moves straight toward the owner until they touch (or
/// [stepsLeft] runs out), then takes the uppercut and is thrown off at [speed] in a random direction.
class HookPull {
  HookPull({
    required this.owner,
    required this.target,
    required this.speed,
    required this.stepsLeft,
  });

  final SimulationBall owner;
  final SimulationBall target;

  /// The target's speed before it was hooked (px/s), given back when it is thrown.
  final double speed;
  int stepsLeft;
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
/// an opponent of [owner] touches it; [owner] never sets it off and is spared by its blast. Armed mines
/// don't count toward the field limit.
class ArmedMine {
  ArmedMine({
    required this.owner,
    required this.position,
    required this.armedStep,
    this.kind = PowerUpKind.mine,
  });

  final SimulationBall owner;
  final Offset position;

  /// Simulation step at which it was set (for the blinking light).
  final int armedStep;
  final PowerUpKind kind;
}

/// Tunable numbers for the power-ups. Tests assert in terms of these, so they can be retuned freely.
class PowerUpTuning {
  PowerUpTuning._();

  /// Steps between two spawns with 2 balls (60 steps = 1 s); see [spawnInterval].
  static const int spawnIntervalSteps = 300;

  /// Steps between two spawns for [ballCount] balls: more balls, more often (2: 5 s, 3: 3.3 s, 4: 2.5 s).
  static int spawnInterval(int ballCount) =>
      (spawnIntervalSteps * 2 / math.max(2, ballCount)).round();

  /// Most unclaimed power-ups lying on the field for [ballCount] balls (2: 3, 3: 4, 4: 5); a new one
  /// removes the oldest.
  static int maxOnField(int ballCount) => math.max(2, ballCount) + 1;

  /// The first power-up comes after 1 s (then one every [spawnIntervalSteps]), so even short matches see
  /// one (probe: with the first at 5 s only about half of All-Out matches did).
  static const int firstSpawnSteps = 60;

  /// Traps do not enter the spawn pool until one minute into the match.
  static const int trapStartSteps = 60 * 60;

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

  /// Grenade speed in arena radii per second (slower than a bullet: it is thrown).
  static const double grenadeSpeedRatio = 0.7;

  /// Hook: chain speed out, and how fast a hooked ball is reeled in (arena radii per second).
  static const double hookSpeedRatio = 1.6;
  static const double hookPullRatio = 1.4;

  /// Hook: longest reel-in (steps) before the uppercut lands anyway, and how long the thrown ball flies
  /// at the speed boost's pace.
  static const int hookMaxPullSteps = 120;
  static const int hookThrowSteps = 40;
  static const int shotgunPellets = 10;

  /// Total spread of the shotgun fan, in radians.
  static const double shotgunSpread = 0.7;
  static const int bowArrows = 7;

  /// A bow volley spans twice the grenade blast's diameter at its target.
  static double bowSpread(double targetDistance, double arenaRadius) {
    final halfWidth = arenaRadius * blastRadiusRatio * 2;
    return (2 * math.atan2(halfWidth, math.max(1, targetDistance))).clamp(
      0.3,
      1.8,
    );
  }

  static const int gatlingRounds = 10;
  static const int gatlingIntervalSteps = 6;
  static const int speedSteps = 180;
  static const double speedFactor = 2.0;
  static const int freezeSteps = 120;
  static const int ghostSteps = 180;
  static const int specialEffectSteps = 180;
  static const int stickyGooSteps = 120;
  static const int molotovBurnSteps = 180;
  static const int molotovTickSteps = 30;
  static const int fireWallSteps = 240;
  static const int damageOverTimeSteps = 120;
  static const int damageOverTimeTickSteps = 30;
  static const int flamethrowerSteps = 90;
  static const int flamethrowerTickSteps = 15;

  /// Bomb blast radius as a fraction of the arena radius.
  static const double blastRadiusRatio = 0.28;

  /// How long a blast stays on screen (steps).
  static const int explosionShowSteps = 30;

  /// How long a knife slash stays on screen (steps).
  static const int slashShowSteps = 14;

  /// All-Out sword sweep: steps after a knife pickup during which the holder cuts with a wider reach,
  /// [sweepReach] times its radius.
  static const int sweepSteps = 60;
  static const double sweepReach = 1.8;

  /// Share of a hit's damage a shield absorbs.
  static const double shieldBlock = 0.25;

  /// Arsenal mode: life lost per hit (shotgun per pellet, gatling per round).
  static const Map<PowerUpKind, double> arenaDamage = {
    PowerUpKind.pistol: 10,
    PowerUpKind.shotgun: 10,
    PowerUpKind.gatling: 15,
    PowerUpKind.knife: 20,
    PowerUpKind.mine: 50,
    PowerUpKind.grenade: 50,
    PowerUpKind.sword: 40,
    PowerUpKind.hook: 30,
    PowerUpKind.ricochetDisc: 25,
    PowerUpKind.orbitingFlail: 20,
    PowerUpKind.threadHarpoon: 20,
    PowerUpKind.prismLaser: 18,
    PowerUpKind.swapCannon: 10,
    PowerUpKind.phaseMine: 40,
    PowerUpKind.spikeWall: 25,
    PowerUpKind.bow: 4,
    PowerUpKind.molotov: 6,
    PowerUpKind.rocketLauncher: 45,
    PowerUpKind.omegaTendrils: 12,
    PowerUpKind.boomerang: 18,
    PowerUpKind.fireWall: 5,
    PowerUpKind.poisonSwamp: 4,
    PowerUpKind.waterGun: 8,
    PowerUpKind.lightningStrikes: 6,
    PowerUpKind.earthquake: 5,
    PowerUpKind.tornado: 3,
    PowerUpKind.energyWave: 28,
    PowerUpKind.flamethrower: 3,
    PowerUpKind.busterSword: 3,
    PowerUpKind.ragingDemon: 1,
  };
  static const double arenaCollisionDamage = 5;
  static const double arenaShieldBash = 5;
  static const double arenaAppleHeal = 25;

  /// Arsenal: an apple at full life still counts, up to this much life (the extra shows as gold hearts).
  static const double arenaMaxLife = 150;

  /// All-Out mode: threads (rim slots) lost per hit.
  static const Map<PowerUpKind, int> allOutThreads = {
    PowerUpKind.pistol: 8,
    PowerUpKind.shotgun: 2,
    PowerUpKind.gatling: 3,
    PowerUpKind.knife: 15,
    PowerUpKind.mine: 10,
    PowerUpKind.grenade: 10,
    PowerUpKind.sword: 30,
    PowerUpKind.hook: 12,
    PowerUpKind.ricochetDisc: 10,
    PowerUpKind.orbitingFlail: 8,
    PowerUpKind.threadHarpoon: 12,
    PowerUpKind.prismLaser: 7,
    PowerUpKind.swapCannon: 4,
    PowerUpKind.phaseMine: 18,
    PowerUpKind.spikeWall: 10,
    PowerUpKind.bow: 1,
    PowerUpKind.molotov: 2,
    PowerUpKind.rocketLauncher: 16,
    PowerUpKind.omegaTendrils: 3,
    PowerUpKind.boomerang: 7,
    PowerUpKind.fireWall: 2,
    PowerUpKind.poisonSwamp: 1,
    PowerUpKind.waterGun: 3,
    PowerUpKind.lightningStrikes: 2,
    PowerUpKind.earthquake: 2,
    PowerUpKind.tornado: 1,
    PowerUpKind.energyWave: 12,
    PowerUpKind.flamethrower: 1,
    PowerUpKind.busterSword: 1,
    PowerUpKind.ragingDemon: 1,
  };
  static const int allOutShieldBash = 5;
  static const int allOutAppleSlots = 20;

  /// All-Out: share of the threads a hit would cut that are still lost when a shield takes it.
  static const double allOutShieldKeep = 0.5;
}

/// What [kind] does, with its numbers from [PowerUpTuning], for the weapons list in Match Setup.
/// [arsenal]: damage in life (Arsenal); otherwise in lines (All-Out), with [config]'s numbers. Damage is for
/// 2 balls (see [crowdNote]).
String powerUpDescription(
  PowerUpKind kind, {
  required bool arsenal,
  PowerUpConfig config = PowerUpConfig.defaults,
}) {
  String secs(int steps) {
    final s = steps / 60;
    return s == s.roundToDouble()
        ? '${s.round()} s'
        : '${s.toStringAsFixed(1)} s';
  }

  String dmg(PowerUpKind k) => arsenal
      ? '${config.arenaDamage(k).round()} damage'
      : '${config.allOutThreads(k)} lines';
  final aim = 'Aims ${secs(config.aimSteps)}, then';
  final block = (config.shieldBlock * 100).round();
  return switch (kind) {
    PowerUpKind.pistol => '$aim fires one shot: ${dmg(kind)}.',
    PowerUpKind.shotgun =>
      '$aim fires a fan of ${config.shotgunPellets} pellets: ${dmg(kind)} each.',
    PowerUpKind.gatling =>
      '$aim fires ${config.gatlingRounds} rounds: ${dmg(kind)} each.',
    PowerUpKind.knife =>
      'Carried until it stabs the next ball it touches: ${dmg(kind)}.',
    PowerUpKind.sword =>
      'Carried until it slashes the next ball it touches: ${dmg(kind)}.',
    PowerUpKind.grenade =>
      '$aim throws it where the target is: ${dmg(kind)} to everyone near where it '
          'blows up but the thrower.',
    PowerUpKind.molotov =>
      '$aim throws it where the target is. The area burns for 3 s, dealing ${dmg(kind)} every 0.5 s.',
    PowerUpKind.rocketLauncher =>
      '$aim fires one homing missile that pursues its target until it hits: ${dmg(kind)}.',
    PowerUpKind.omegaTendrils =>
      'Cheat power: unavoidable tendrils grab every opponent and slam them for ${dmg(kind)}.',
    PowerUpKind.boomerang =>
      '$aim throws once for ${dmg(kind)}, returns to its owner, then drops.',
    PowerUpKind.fireWall =>
      '$aim raises four flames. Crossing deals ${dmg(kind)} and burns for 2 s.',
    PowerUpKind.waterGun =>
      '$aim squirts a fast water jet that splashes for ${dmg(kind)}.',
    PowerUpKind.lightningStrikes =>
      'Calls three unavoidable lightning strikes on the nearest opponent: ${dmg(kind)} each.',
    PowerUpKind.earthquake =>
      'Shakes the arena with three unavoidable pulses: ${dmg(kind)} each to every opponent.',
    PowerUpKind.tornado =>
      'Summons a pursuing wind vortex for 3 s. It pulls nearby opponents inward and deals ${dmg(kind)} over time.',
    PowerUpKind.energyWave =>
      '$aim sweeps from the leftmost to the rightmost opponent over 2 s, hitting each opponent once for ${dmg(kind)} before knockback.',
    PowerUpKind.flamethrower =>
      '$aim sprays a sustained fire cone for 1.5 s: ${dmg(kind)} per pulse plus burn damage over time.',
    PowerUpKind.friedChicken =>
      arsenal
          ? 'Restores life to 100. Does nothing at 100 HP or above.'
          : 'Restores every missing thread. Does nothing when no threads are missing.',
    PowerUpKind.sniperRifle =>
      '$aim fires one unavoidable Special-tier shot that immediately knocks out its target.',
    PowerUpKind.busterSword =>
      '$aim freezes time, dashes to the farthest opponent, and slashes eight times for ${dmg(kind)} each.',
    PowerUpKind.ragingDemon =>
      'Dashes to the nearest opponent and lands ${config.ragingDemonHits} unavoidable hits for ${dmg(kind)} each.',
    PowerUpKind.shield =>
      arsenal
          ? 'Blocks $block% of the next hit. Bashes an unarmed ball: '
                '${config.arenaShieldBash.round()} damage.'
          : 'Keeps the lines lost to the next hit at ${(config.allOutShieldKeep * 100).round()}%. Bashes an unarmed ball: '
                '${config.allOutShieldBash} lines.',
    PowerUpKind.apple =>
      arsenal
          ? 'Heals ${config.arenaAppleHeal.round()} life, even past full '
                '(up to ${config.arenaMaxLife.round()}).'
          : 'Adds up to ${config.allOutAppleSlots} lines from free rim spots.',
    PowerUpKind.speed =>
      '${PowerUpTuning.speedFactor.round()}x speed for ${secs(config.speedSteps)}.',
    PowerUpKind.freeze =>
      '$aim freezes the target for ${secs(config.freezeSteps)}. No damage.',
    PowerUpKind.hook =>
      '$aim throws a hook on a chain. A hit pulls the opponent in ("COME OVER HERE!"), '
          'uppercuts it for ${dmg(kind)} and throws it away.',
    PowerUpKind.mine =>
      'The first ball to touch it sets it as a mine. It explodes when an opponent touches it: '
          '${dmg(kind)} to everyone nearby but its owner.',
    PowerUpKind.magnet =>
      'Pulls the nearest power-up (or the next one) straight to the ball.',
    PowerUpKind.ghost =>
      'For ${secs(config.ghostSteps)} passes through balls and can\'t be hit.',
    PowerUpKind.ricochetDisc =>
      '$aim fires a wall-bouncing disc: ${dmg(kind)}.',
    PowerUpKind.orbitingFlail => 'Smashes the next ball touched: ${dmg(kind)}.',
    PowerUpKind.threadHarpoon => '$aim steals threads or drains ${dmg(kind)}.',
    PowerUpKind.prismLaser =>
      '$aim fires a beam that splits after a wall bounce: ${dmg(kind)}.',
    PowerUpKind.swapCannon =>
      '$aim swaps positions with its target: ${dmg(kind)}.',
    PowerUpKind.phaseMine => 'Sets a hidden proximity mine: ${dmg(kind)}.',
    PowerUpKind.repulsor => 'Greatly repels balls on contact for 3 s.',
    PowerUpKind.timeBubble => 'Slows nearby opponents and projectiles for 3 s.',
    PowerUpKind.vampire =>
      'Converts part of dealt damage into health or threads for 3 s.',
    PowerUpKind.mirror => 'Reflects the next incoming projectile.',
    PowerUpKind.overcharge => 'Empowers both equipped weapons for 3 s.',
    PowerUpKind.gremlin =>
      'Makes the nearest opponent fire its next shot backward.',
    PowerUpKind.magneticField =>
      'A 2x purple force field repels balls and every attack for 3 s.',
    PowerUpKind.portal =>
      'An edge portal that teleports the ball entering it to a random side of the arena.',
    PowerUpKind.spikeWall =>
      'A row of 6 boundary spikes that deals ${dmg(kind)} and knocks the ball inward.',
    PowerUpKind.goldenArmor => 'Completely blocks the next two damaging hits.',
    PowerUpKind.bow =>
      '$aim fires a ${config.bowArrows}-arrow volley spanning twice a grenade blast: ${dmg(kind)} each.',
    PowerUpKind.stickyGoo =>
      'Holds the first ball that touches it in place for 2 s.',
    PowerUpKind.poisonSwamp =>
      'A toxic boundary swamp. Contact poisons a ball for 2 s: ${dmg(kind)} per tick.',
  };
}

class OmegaTendril {
  OmegaTendril({
    required this.owner,
    required this.target,
    required this.savedVelocity,
    this.stepsLeft = 36,
  });

  final SimulationBall owner;
  final SimulationBall target;
  final Offset savedVelocity;
  int stepsLeft;
}

/// Arsenal: how damage grows with more balls (matches [MatchSimulationController.damage]).
const String crowdNote = 'Damage is x2.25 with 3 balls and x4 with 4.';
