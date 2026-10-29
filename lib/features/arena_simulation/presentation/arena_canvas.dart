import '../../settings/presentation/app_settings_scope.dart';
import '../../../core/sprites/visual_quality.dart';
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
  final Map<String, String> artworkRevisions;
  final bool showBallGlow;
  final double ballGlowWidth;
  final BallAppearance? ballAppearance;
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

  /// A thin HP bar above each ball (cosmetic).
  final bool showHpBars;

  const ArenaCanvas({
    super.key,
    required this.state,
    required this.arenaRadius,
    this.worldRadius,
    this.rimInset,
    required this.rimAngle,
    this.showEffects = true,
    this.artworkRevisions = const {},
    this.showBallGlow = true,
    this.ballGlowWidth = 4,
    this.ballAppearance,
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
    this.showHpBars = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: ValueListenableBuilder<EffectDensity>(
        valueListenable: VisualQuality.density,
        builder: (_, density, _) => CustomPaint(
          painter: ArenaPainter(
            state: state,
            visualDensity: density,
            arenaRadius: arenaRadius,
            worldRadius: worldRadius,
            rimInset: rimInset,
            rimAngle: rimAngle,
            showEffects: showEffects,
            artworkRevisions: artworkRevisions,
            showBallGlow: showBallGlow,
            ballGlowWidth: ballGlowWidth,
            ballAppearance:
                ballAppearance ?? AppSettingsScope.of(context).ballAppearance,
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
            showHpBars: showHpBars,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
