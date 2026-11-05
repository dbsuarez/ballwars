import '../../arenas/domain/arena_definition.dart';
import '../../arenas/domain/arena_geometry.dart';
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
  final ArenaDefinition? arena;
  final ArenaShape shape;

  const ArenaPreview({super.key, required this.decoration, this.size = 96, this.arena, this.shape = ArenaShape.circle});

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final state = SimulationState(
      balls: const [],
      particles: ParticleSystem(),
      floatingTexts: FloatingTextManager(),
      status: MatchStatus.running,
      winnerId: null,
      arenaShape: arena?.shape ?? shape,
      centerObstacle: arena?.obstacle ?? CenterObstacle.none,
      centerObstacleScale: arena?.obstacleScale ?? .22,
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
            arenaPreset: arena,
            arenaDecoration: arena?.trapTheme ?? decoration,
            background: c.background,
            rimColor: c.text,
          ),
        ),
      ),
    );
  }
}
