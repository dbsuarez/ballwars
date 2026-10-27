import 'package:flutter/painting.dart';

import '../../ball_management/domain/custom_ball.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../settings/domain/app_settings.dart';
import '../../skills/domain/skill_library.dart';

enum WinCondition { domination, timeAttack }

/// How big every ball in a match is, relative to today's (medium) size. All
/// balls share it, so it's fair; bigger balls cut more and end matches
/// sooner. It changes the match, so replay links carry it ([id]).
enum BallSize {
  smallest('xs', 'Smallest', 0.6),
  small('s', 'Small', 0.8),
  medium('m', 'Medium', 1.0),
  large('l', 'Large', 1.25);

  final String id;
  final String label;
  final double scale;

  const BallSize(this.id, this.label, this.scale);

  static BallSize? byId(String? id) =>
      values.where((s) => s.id == id).firstOrNull;
}

/// How a match is played. Threads is the original line-cutting game; the
/// others add power-ups. It changes the match, so replay links carry it ([id]).
enum MatchMode {
  threads('threads', 'Threads'),
  arsenal('arsenal', 'Arsenal'),
  allOut('allout', 'All-Out');

  final String id;
  final String label;

  const MatchMode(this.id, this.label);

  static MatchMode? byId(String? id) =>
      values.where((m) => m.id == id).firstOrNull;
}

/// How balls are drawn (cosmetic, not part of the match or of replay links): their pictures, or
/// smiley faces that follow the opponent and get hurt.
enum BallLook {
  pictures('Picture'),
  faces('Face'),
  both('Both');

  final String label;

  const BallLook(this.label);

  static BallLook? byName(String? name) =>
      values.where((l) => l.name == name).firstOrNull;
}

/// Cosmetic size of the sparks created when a ball hits the arena wall.
enum WallSparkSize {
  subtle('subtle', 'Subtle', 0.65),
  normal('normal', 'Normal', 1.0),
  large('large', 'Large', 1.5);

  final String id;
  final String label;
  final double scale;

  const WallSparkSize(this.id, this.label, this.scale);

  static WallSparkSize? byId(String? id) =>
      values.where((value) => value.id == id).firstOrNull;
}

class MatchConfig {
  final List<CustomBall> contestants;
  final double speedMultiplier;
  final bool automaticSpeedUp;

  /// Show sparks and particles (cosmetic; the match is the same either way).
  final bool showEffects;
  final double ballGlowWidth;
  final Color bloodColor;
  final WallSparkSize wallSparkSize;

  /// Round wins needed to take the series: 1 is a single round, 2 or 3 play
  /// rounds until one ball has that many wins.
  final int winsNeeded;
  final WinCondition winCondition;

  final BallSize ballSize;

  final MatchMode mode;

  final BallLook look;
  final bool handsOnPictures;
  final bool whitePickupBackgrounds;

  /// Power-up modes: the power-ups that can spawn; null for all of them.
  final Set<PowerUpKind>? powerUps;

  /// Whether balls can equip two weapons instead of one.
  final bool dualWield;

  /// Arsenal-only: eliminated balls respawn and the battle tracks knockouts.
  final bool endlessBattle;

  /// Arsenal-only six-ball timed knockout battle with respawns.
  final bool mayhem;
  final int mayhemSeconds;

  /// Gradually contracts the playable boundary during the match.
  final bool shrinkingArena;

  /// Smallest playable radius, as a fraction of the starting radius.
  final double minimumArenaScale;

  /// The player's arena choice for this match. Admin settings remain the default.
  final ArenaDecoration arenaDecoration;

  /// Power-up modes: the power-up numbers (the admin's settings, or a replay link's).
  final PowerUpConfig tuning;

  /// Active skill variants and their cosmetic/audio choices.
  final SkillLibrary skillLibrary;

  /// Yes or No: the question the match answers (shown instead of the headline), or null.
  final String? question;

  const MatchConfig({
    required this.contestants,
    this.speedMultiplier = 1.0,
    this.automaticSpeedUp = true,
    this.showEffects = true,
    this.ballGlowWidth = 4,
    this.bloodColor = const Color(0xFFD9152B),
    this.wallSparkSize = WallSparkSize.normal,
    this.winsNeeded = 1,
    this.winCondition = WinCondition.domination,
    this.ballSize = BallSize.medium,
    this.look = BallLook.pictures,
    this.handsOnPictures = false,
    this.whitePickupBackgrounds = true,
    this.question,
    this.powerUps,
    this.dualWield = false,
    this.endlessBattle = false,
    this.mayhem = false,
    this.mayhemSeconds = 120,
    this.shrinkingArena = false,
    this.minimumArenaScale = 0.60,
    this.arenaDecoration = ArenaDecoration.defaultArena,
    this.tuning = PowerUpConfig.defaults,
    this.skillLibrary = SkillLibrary.defaults,
    this.mode = MatchMode.threads,
  });
}
