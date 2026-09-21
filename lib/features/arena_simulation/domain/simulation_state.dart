import 'floating_text.dart';
import 'particle_system.dart';
import 'simulation_ball.dart';
import 'territory_engine.dart';

enum MatchStatus { running, slowMotion, finished }

class SimulationState {
  final List<SimulationBall> balls;
  final TerritoryEngine territory;
  final ParticleSystem particles;
  final FloatingTextManager floatingTexts;
  final MatchStatus status;
  final String? winnerId;

  const SimulationState({
    required this.balls,
    required this.territory,
    required this.particles,
    required this.floatingTexts,
    required this.status,
    required this.winnerId,
  });
}
