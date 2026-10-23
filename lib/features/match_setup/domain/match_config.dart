import '../../ball_management/domain/custom_ball.dart';

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

  static BallSize? byId(String? id) => values.where((s) => s.id == id).firstOrNull;
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

  static MatchMode? byId(String? id) => values.where((m) => m.id == id).firstOrNull;
}

class MatchConfig {
  final List<CustomBall> contestants;
  final double speedMultiplier;

  /// Show sparks and particles (cosmetic; the match is the same either way).
  final bool showEffects;

  /// Round wins needed to take the series: 1 is a single round, 2 or 3 play
  /// rounds until one ball has that many wins.
  final int winsNeeded;
  final WinCondition winCondition;

  final BallSize ballSize;

  final MatchMode mode;

  const MatchConfig({
    required this.contestants,
    this.speedMultiplier = 1.0,
    this.showEffects = true,
    this.winsNeeded = 1,
    this.winCondition = WinCondition.domination,
    this.ballSize = BallSize.medium,
    this.mode = MatchMode.threads,
  });
}
