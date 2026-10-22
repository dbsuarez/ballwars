import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/simulation_state.dart';
import 'arena_painter.dart';

class ArenaCanvas extends StatelessWidget {
  final SimulationState state;
  final double arenaRadius;
  final double rimAngle;
  final bool showEffects;

  const ArenaCanvas({
    super.key,
    required this.state,
    required this.arenaRadius,
    required this.rimAngle,
    this.showEffects = true,
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
        ),
        size: Size.infinite,
      ),
    );
  }
}
