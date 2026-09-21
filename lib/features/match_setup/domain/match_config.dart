import '../../ball_management/domain/custom_ball.dart';

enum WinCondition { domination, timeAttack }

class MatchConfig {
  final List<CustomBall> contestants;
  final double speedMultiplier;
  final WinCondition winCondition;

  const MatchConfig({
    required this.contestants,
    this.speedMultiplier = 1.0,
    this.winCondition = WinCondition.domination,
  });
}
