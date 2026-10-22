import '../../ball_management/domain/custom_ball.dart';

enum WinCondition { domination, timeAttack }

class MatchConfig {
  final List<CustomBall> contestants;
  final double speedMultiplier;

  /// Show sparks and particles (cosmetic; the match is the same either way).
  final bool showEffects;

  /// Round wins needed to take the series: 1 is a single round, 2 or 3 play
  /// rounds until one ball has that many wins.
  final int winsNeeded;
  final WinCondition winCondition;

  const MatchConfig({
    required this.contestants,
    this.speedMultiplier = 1.0,
    this.showEffects = true,
    this.winsNeeded = 1,
    this.winCondition = WinCondition.domination,
  });
}
