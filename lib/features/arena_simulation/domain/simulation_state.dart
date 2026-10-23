import '../application/power_up_system.dart';
import 'floating_text.dart';
import 'particle_system.dart';
import 'simulation_ball.dart';
import 'fan_line.dart';

enum MatchStatus { running, slowMotion, beamAttack, finished }

class SimulationState {
  final List<SimulationBall> balls;
  final ParticleSystem particles;
  final FloatingTextManager floatingTexts;
  final MatchStatus status;
  final String? winnerId;

  // Beam attack state
  final SimulationBall? beamFirer;
  final SimulationBall? beamTarget;
  final int beamPhase; // 0=inactive, 1=solid, 2=dotted, 3=haze
  final double beamTimer;

  /// The match's power-ups (field, projectiles, bombs) for painting; null in Threads mode.
  final PowerUpSystem? powerUps;

  const SimulationState({
    required this.balls,
    required this.particles,
    required this.floatingTexts,
    required this.status,
    required this.winnerId,
    this.beamFirer,
    this.beamTarget,
    this.beamPhase = 0,
    this.beamTimer = 0.0,
    this.powerUps,
  });

  // All active fan lines across all balls (for rendering)
  List<FanLine> get allActiveFanLines {
    final lines = <FanLine>[];
    for (final ball in balls) {
      lines.addAll(ball.fanLines.where((l) => l.isActive));
    }
    return lines;
  }
}