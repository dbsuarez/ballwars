import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/simulation_state.dart';
import 'arena_painter.dart';
import '../../match_setup/domain/match_config.dart';

class ArenaCanvas extends StatelessWidget {
  final SimulationState state;
  final double arenaRadius;
  final double rimAngle;
  final bool showEffects;

  /// Repaints the arena when it notifies, without rebuilding any widgets.
  final Listenable? repaint;

  final BallLook look;

  const ArenaCanvas({
    super.key,
    required this.state,
    required this.arenaRadius,
    required this.rimAngle,
    this.showEffects = true,
    this.repaint,
    this.look = BallLook.pictures,
  });

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: ArenaPainter(
          state: state,
          arenaRadius: arenaRadius,
          rimAngle: rimAngle,
          showEffects: showEffects,
          background: c.background,
          rimColor: c.text,
          repaint: repaint,
          look: look,
        ),
        size: Size.infinite,
      ),
    );
  }
}
