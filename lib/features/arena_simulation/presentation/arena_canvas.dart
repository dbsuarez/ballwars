import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/simulation_state.dart';
import 'arena_painter.dart';
import '../../match_setup/domain/match_config.dart';
import '../../settings/domain/app_settings.dart';

class ArenaCanvas extends StatelessWidget {
  final SimulationState state;
  final double arenaRadius;
  final double? worldRadius;
  final double? rimInset;
  final double rimAngle;
  final bool showEffects;
  final bool showBallGlow;
  final double ballGlowWidth;
  final String arenaTitle;
  final String arenaSubtitle;
  final WallSparkSize wallSparkSize;
  final ArenaDecoration arenaDecoration;
  final bool handsOnPictures;
  final bool whitePickupBackgrounds;
  final EffectRenderMode projectileRenderMode;
  final EffectRenderMode explosionRenderMode;
  final EffectRenderMode freezeRenderMode;

  /// Repaints the arena when it notifies, without rebuilding any widgets.
  final Listenable? repaint;

  final BallLook look;

  const ArenaCanvas({
    super.key,
    required this.state,
    required this.arenaRadius,
    this.worldRadius,
    this.rimInset,
    required this.rimAngle,
    this.showEffects = true,
    this.showBallGlow = true,
    this.ballGlowWidth = 4,
    this.arenaTitle = 'dbsuarez',
    this.arenaSubtitle = 'bakbakan na',
    this.wallSparkSize = WallSparkSize.normal,
    this.arenaDecoration = ArenaDecoration.defaultArena,
    this.handsOnPictures = false,
    this.whitePickupBackgrounds = true,
    this.projectileRenderMode = EffectRenderMode.sprite,
    this.explosionRenderMode = EffectRenderMode.sprite,
    this.freezeRenderMode = EffectRenderMode.sprite,
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
          worldRadius: worldRadius,
          rimInset: rimInset,
          rimAngle: rimAngle,
          showEffects: showEffects,
          showBallGlow: showBallGlow,
          ballGlowWidth: ballGlowWidth,
          arenaTitle: arenaTitle,
          arenaSubtitle: arenaSubtitle,
          wallSparkSize: wallSparkSize,
          arenaDecoration: arenaDecoration,
          handsOnPictures: handsOnPictures,
          whitePickupBackgrounds: whitePickupBackgrounds,
          projectileRenderMode: projectileRenderMode,
          explosionRenderMode: explosionRenderMode,
          freezeRenderMode: freezeRenderMode,
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
