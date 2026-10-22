import '../../ball_management/domain/custom_ball.dart';

enum WinCondition { domination, timeAttack }

class MatchConfig {
  final List<CustomBall> contestants;
  final double speedMultiplier;

  /// Show sparks and particles (cosmetic; the match is the same either way).
  final bool showEffects;
  final WinCondition winCondition;

  const MatchConfig({
    required this.contestants,
    this.speedMultiplier = 1.0,
    this.showEffects = true,
    this.winCondition = WinCondition.domination,
  });
}
