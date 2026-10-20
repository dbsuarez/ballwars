import 'package:flutter/material.dart';
import '../domain/simulation_state.dart';
import 'arena_painter.dart';

class ArenaCanvas extends StatelessWidget {
  final SimulationState state;
  final double arenaRadius;
  final double rimAngle;

  const ArenaCanvas({
    super.key,
    required this.state,
    required this.arenaRadius,
    required this.rimAngle,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: ArenaPainter(state: state, arenaRadius: arenaRadius, rimAngle: rimAngle),
        size: Size.infinite,
      ),
    );
  }
}
