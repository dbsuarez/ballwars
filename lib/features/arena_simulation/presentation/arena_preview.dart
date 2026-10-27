import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/floating_text.dart';
import '../domain/particle_system.dart';
import '../domain/simulation_state.dart';
import 'arena_painter.dart';

/// A small static picture of an arena's floor and rim. No balls, no
/// simulation and no randomness.
class ArenaPreview extends StatelessWidget {
  final ArenaDecoration decoration;
  final double size;

  const ArenaPreview({super.key, required this.decoration, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final state = SimulationState(
      balls: const [],
      particles: ParticleSystem(),
      floatingTexts: FloatingTextManager(),
      status: MatchStatus.running,
      winnerId: null,
      arenaRadius: 200,
    );
    return SizedBox.square(
      dimension: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: ArenaPainter(
            state: state,
            arenaRadius: 200,
            rimAngle: 0,
            arenaTitle: '',
            arenaSubtitle: '',
            arenaDecoration: decoration,
            background: c.background,
            rimColor: c.text,
          ),
        ),
      ),
    );
  }
}
