import '../../arenas/domain/arena_definition.dart';
import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../arena_simulation/domain/equipped_items.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../domain/video_visibility.dart';
import '../../arena_simulation/presentation/ball_face_expression.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../match_setup/domain/match_config.dart';
import '../../settings/domain/app_settings.dart';
import '../../arena_simulation/domain/simulation_ball.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../arena_simulation/presentation/arena_painter.dart';
import '../../arena_simulation/presentation/ball_face_painter.dart';
import '../../arena_simulation/presentation/confetti_painter.dart';
import '../../arena_simulation/presentation/harpoon_cinematic.dart';
import '../../skills/domain/skill_library.dart';

/// Draws one frame of the exported 9:16 replay video, laid out like the
/// reference: "WHO WINS?" / "ROUND 1" header, the arena, a slow-motion badge,
/// and a winner card at the end, with a moving [watermark] over everything.
/// Coordinates are in a 720x1280 design space scaled to the frame size.
/// [videoTime] is seconds since the start of the video; it drives the
/// watermark so the same replay always renders the same frames.
class ReplayFramePainter {
  static const Size designSize = Size(720, 1280);
  static const double _arenaSide = 680;
  static const double _arenaTop = 330;

  /// Look of the frames being drawn; set by each public paint call.
  static ReplayStyle _style = const ReplayStyle();
  static const Color _gold = Color(0xFFFFD700);

  static const String watermark = AppSettings.defaultExportWatermark;
  // Drifts diagonally and bounces off the frame edges (design px per second).
  static const Offset _watermarkVelocity = Offset(95, 70);
  static const Offset _watermarkStart = Offset(40, 300);

  /// A frame of the match in progress.
  static void paintMatch(
    Canvas canvas,
    Size size,
    SimulationState state,
    double arenaRadius, {
    double? worldRadius,
    ArenaDecoration? arenaDecoration,
    MatchSimulationController? controller,
    required double videoTime,
    bool showEffects = true,
    ReplayStyle style = const ReplayStyle(),
  }) {
    _style = style;
    _withDesignSpace(canvas, size, videoTime, () {
      if (!_style.visibility.watchingLayout) {
        _paintHeader(canvas, dimmed: false);
      }
      if (state.status == MatchStatus.slowMotion) {
        _paintSlowMotionBadge(
          canvas,
          y: _style.visibility.watchingLayout ? 20 : 275,
        );
      }

      canvas.save();
      final details =
          _style.visibility.shows(VideoLayer.stats) ||
          _style.visibility.shows(VideoLayer.equipment);
      final metadataRows = (state.balls.length / 2).ceil();
      final side = _style.visibility.watchingLayout
          ? 720.0
          : details
          ? math.min(_arenaSide, 1240 - _arenaTop - metadataRows * 96 - 64)
          : _arenaSide;
      final top = _style.visibility.watchingLayout ? 40.0 : _arenaTop;
      canvas.translate((designSize.width - side) / 2, top);
      ArenaPainter(
        state: state,
        artworkRevisions: _style.artworkRevisions,
        arenaRadius: arenaRadius,
        worldRadius: worldRadius,
        rimAngle: 0,
        showEffects: showEffects,
        projectileRenderMode: _style.effectRenderMode,
        explosionRenderMode: _style.effectRenderMode,
        freezeRenderMode: _style.effectRenderMode,
        showBallGlow: _style.ballGlowEnabled,
        ballGlowWidth: _style.ballGlowWidth,
        ballAppearance: _style.ballAppearance,
        arenaTitle: _style.visibility.shows(VideoLayer.arenaText)
            ? _style.arenaTitle
            : '',
        arenaSubtitle: _style.visibility.shows(VideoLayer.arenaText)
            ? _style.arenaSubtitle
            : '',
        arenaPreset: _style.arenaPreset,
        arenaDecoration: arenaDecoration ?? _style.arenaDecoration,
        background: _style.background,
        rimColor: _style.text,
        look: _style.visibility.shows(VideoLayer.pictures)
            ? (_style.look == BallLook.faces ? BallLook.pictures : _style.look)
            : BallLook.faces,
        showHpBars: _style.visibility.shows(VideoLayer.health),
        showCallouts: _style.visibility.shows(VideoLayer.callouts),
        showInitials: _style.visibility.shows(VideoLayer.names),
      ).paint(canvas, Size(side, side));
      canvas.restore();
      final untilChange = controller?.secondsUntilArenaRotation;
      if (_style.visibility.shows(VideoLayer.callouts) &&
          untilChange != null &&
          untilChange > 0 &&
          untilChange <= 3) {
        _paintText(
          canvas,
          'ARENA CHANGING IN ${untilChange.ceil()}',
          26,
          FontWeight.w800,
          _style.text,
          y: top + 44,
          maxWidth: 660,
        );
      }
      final flash = controller?.arenaTransitionFlash ?? 0;
      if (showEffects && flash > 0) {
        final rect = Rect.fromLTWH(
          (designSize.width - side) / 2,
          top,
          side,
          side,
        );
        if (state.arenaShape == ArenaShape.circle) {
          canvas.drawOval(
            rect,
            Paint()..color = Colors.white.withValues(alpha: flash * .12),
          );
        } else {
          canvas.drawRect(
            rect,
            Paint()..color = Colors.white.withValues(alpha: flash * .12),
          );
        }
      }
      _paintWatchingDetails(
        canvas,
        state,
        top + side + 28,
        controller: controller,
      );
    });
  }

  static void _paintWatchingDetails(
    Canvas canvas,
    SimulationState state,
    double top, {
    MatchSimulationController? controller,
  }) {
    final match = controller ?? state.powerUps?.match;
    final visible = [...state.balls];
    if (_style.visibility.shows(VideoLayer.stats)) {
      visible.sort((a, b) {
        final kills = (match?.eliminations[b.config.id] ?? 0).compareTo(
          match?.eliminations[a.config.id] ?? 0,
        );
        if (kills != 0) return kills;
        final deaths = (match?.deaths[a.config.id] ?? 0).compareTo(
          match?.deaths[b.config.id] ?? 0,
        );
        return deaths != 0 ? deaths : b.life.compareTo(a.life);
      });
      _paintText(
        canvas,
        '${(state.step / 60).toStringAsFixed(1)}s',
        24,
        FontWeight.bold,
        _style.text,
        y: top,
      );
      top += 36;
    }
    final options = _style.visibility;
    if (!options.shows(VideoLayer.names) &&
        !options.shows(VideoLayer.equipment) &&
        !options.shows(VideoLayer.stats)) {
      return;
    }
    final rows = (visible.length / 2).ceil();
    final rowHeight = math.min(96.0, (1240 - top) / math.max(1, rows));
    for (var i = 0; i < visible.length; i++) {
      final ball = visible[i];
      final x = 20.0 + (i % 2) * 350;
      final y = top + (i ~/ 2) * rowHeight;
      final rect = Rect.fromLTWH(x, y, 330, rowHeight - 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()..color = _style.text.withValues(alpha: .06),
      );
      canvas.drawCircle(
        Offset(x + 12, y + 12),
        4,
        Paint()..color = ball.config.primaryColor,
      );
      if (options.shows(VideoLayer.names)) {
        final name = _layout(
          ball.config.name,
          24,
          FontWeight.w700,
          _style.text,
          maxWidth: 300,
        );
        name.paint(canvas, Offset(x + 22, y + 4));
      }
      if (options.shows(VideoLayer.stats)) {
        final stats = match?.threadCutRace == true && match?.mode == MatchMode.threadGrowth ? '${ball.threadsCut}/${match!.neoThreadsTarget} cuts / ${match.deaths[ball.config.id] ?? 0} deaths' :
            '${match?.eliminations[ball.config.id] ?? 0} KO / ${match?.deaths[ball.config.id] ?? 0} deaths';
        final health = options.shows(VideoLayer.health)
            ? ' / ${match?.mode.isThreadOnly == true ? ball.lineCount : ball.life.ceil()} ${match?.mode.isThreadOnly == true ? 'lines' : 'HP'}'
            : '';
        final label = _layout(
          '$stats$health',
          20,
          FontWeight.w500,
          _style.text,
          maxWidth: 306,
        );
        label.paint(
          canvas,
          Offset(x + 12, y + (options.shows(VideoLayer.names) ? 32 : 6)),
        );
      }
      if (options.shows(VideoLayer.equipment)) {
        var itemX = x + 12;
        final items = equippedItems(ball).take(4);
        for (final kind in items) {
          final system = state.powerUps;
          final skill = system?.visualSkill(
            kind,
            skillId: kind == ball.held
                ? ball.heldSkillId
                : kind == ball.heldSecondary
                ? ball.heldSecondarySkillId
                : ball.activeEffectSkillIds[kind],
          );
          final image = SpriteRegistry.frame(
            skill?.iconSpriteId ?? PowerUpSprites.iconId(kind),
          );
          final target = Rect.fromLTWH(itemX, y + rowHeight - 24, 20, 20);
          if (image == null) {
            PowerUpSprites.paintIcon(canvas, kind, target);
          } else {
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(
                0,
                0,
                image.width.toDouble(),
                image.height.toDouble(),
              ),
              target,
              Paint()
                ..filterQuality = FilterQuality.low
                ..colorFilter = ColorFilter.mode(
                  Color(skill?.spriteTint ?? 0xffffffff),
                  BlendMode.modulate,
                ),
            );
          }
          itemX += 26;
        }
      }
    }
  }

  /// The closing winner card.
  static void paintWinnerCard(
    Canvas canvas,
    Size size,
    SimulationBall winner,
    double matchSeconds, {
    SimulationState? finalState,
    MatchSimulationController? controller,
    required double videoTime,
    ReplayStyle style = const ReplayStyle(),
  }) {
    _style = style;
    _withDesignSpace(canvas, size, videoTime, () {
      _paintHeader(canvas, dimmed: true);
      ConfettiPainter(videoTime).paint(canvas, designSize);
      if (_style.visibility.watchingLayout ||
          _style.visibility.shows(VideoLayer.stats)) {
        _paintBallFace(canvas, winner, const Offset(360, 310), 110);
        _paintText(
          canvas,
          _style.visibility.shows(VideoLayer.names)
              ? winner.config.name
              : 'WINNER',
          44,
          FontWeight.w900,
          _style.text,
          y: 470,
          maxWidth: 680,
        );
        _paintText(canvas, 'WINS!', 36, FontWeight.w800, _gold, y: 530);
        if (finalState != null) {
          _paintWatchingDetails(
            canvas,
            finalState,
            620,
            controller: controller,
          );
        }
        return;
      }

      const center = Offset(360, 560);
      const radius = 150.0;
      if (_style.ballGlowEnabled) {
        canvas.drawCircle(
          center,
          radius + 6,
          Paint()
            ..color = winner.config.glowColor.withValues(alpha: 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18),
        );
      }
      _paintBallFace(canvas, winner, center, radius);

      _paintText(
        canvas,
        _style.visibility.shows(VideoLayer.names)
            ? winner.config.name.toUpperCase()
            : 'WINNER',
        64,
        FontWeight.w900,
        _style.text,
        y: 760,
        letterSpacing: 2,
        maxWidth: 680,
      );
      _paintText(
        canvas,
        'WINS!',
        52,
        FontWeight.w900,
        _gold,
        y: 840,
        letterSpacing: 4,
      );
      _paintText(
        canvas,
        String.fromCharCode(Icons.emoji_events.codePoint),
        72,
        FontWeight.normal,
        _gold,
        y: 915,
        fontFamily: Icons.emoji_events.fontFamily,
      );
      _paintText(
        canvas,
        _style.visibility.shows(VideoLayer.stats)
            ? 'MATCH TIME ${matchSeconds.toStringAsFixed(1)}s'
            : '',
        28,
        FontWeight.w600,
        _style.muted,
        y: 1010,
        letterSpacing: 1.5,
      );
    });
  }

  /// Non-interactive rendering of the live finishing beat for video exports.
  static void paintFinisher(
    Canvas canvas,
    Size size,
    SimulationBall winner,
    SimulationBall loser,
    String move,
    double progress, {
    required double videoTime,
    ReplayStyle style = const ReplayStyle(),
    SkillDefinition? skill,
    SkillLibrary skillLibrary = SkillLibrary.defaults,
  }) {
    _style = style;
    _withDesignSpace(canvas, size, videoTime, () {
      _paintHeader(canvas, dimmed: true);
      canvas.save();
      canvas.translate(0, 300);
      canvas.clipRect(const Rect.fromLTWH(0, 0, 720, 480));
      HarpoonCinematic.paintFrame(
        canvas,
        const Size(720, 480),
        winner.config,
        loser.config,
        move,
        progress,
        skill: skill,
        library: skillLibrary,
        artworkRevisions: style.artworkRevisions,
        effectSprites:
            skill?.usesSpriteEffects(
              globalSprite: style.effectRenderMode == EffectRenderMode.sprite,
            ) ??
            true,
      );
      canvas.restore();
      _paintText(
        canvas,
        move.toUpperCase(),
        44,
        FontWeight.w900,
        _gold,
        y: 820,
        letterSpacing: 2,
        maxWidth: 650,
      );
      _paintText(
        canvas,
        _style.visibility.shows(VideoLayer.names)
            ? '${winner.config.name.toUpperCase()} FINISHES IT!'
            : 'FINISHING MOVE',
        26,
        FontWeight.w800,
        _style.text,
        y: 890,
        maxWidth: 650,
      );
    });
  }

  /// The final arena with the runner-up shown big at its center; [progress]
  /// 0..1 pops it in, holds it, then fades it out (as in the app).
  static void paintLoser(
    Canvas canvas,
    Size size,
    SimulationState state,
    double arenaRadius,
    SimulationBall loser,
    double progress, {
    double? worldRadius,
    ArenaDecoration? arenaDecoration,
    MatchSimulationController? controller,
    required double videoTime,
    bool showEffects = true,
    ReplayStyle style = const ReplayStyle(),
  }) {
    paintMatch(
      canvas,
      size,
      state,
      arenaRadius,
      worldRadius: worldRadius,
      arenaDecoration: arenaDecoration,
      controller: controller,
      videoTime: videoTime,
      showEffects: showEffects,
      style: style,
    );
    final double opacity;
    final double scale;
    if (progress < 0.2) {
      opacity = progress / 0.2;
      scale = 0.6 + 0.4 * Curves.easeOutBack.transform(progress / 0.2);
    } else if (progress < 0.7) {
      opacity = 1;
      scale = 1;
    } else {
      opacity = 1 - (progress - 0.7) / 0.3;
      scale = 1 + 0.3 * (progress - 0.7) / 0.3;
    }
    canvas.save();
    canvas.scale(
      size.width / designSize.width,
      size.height / designSize.height,
    );
    final center = Offset(designSize.width / 2, _arenaTop + _arenaSide / 2);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
    );
    _paintBallFace(canvas, loser, center, 150 * scale);
    paintLoserCross(canvas, center, 150 * scale, progress);
    canvas.restore();
    canvas.restore();
  }

  /// A red X stamped over the eliminated ball (radius [radius] at [center]),
  /// so the big ball reads as the loser, not the winner. It slams in just
  /// after the ball pops in ([progress] as in [paintLoser]).
  static void paintLoserCross(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final t = ((progress - 0.12) / 0.12).clamp(0.0, 1.0);
    if (t <= 0) return;
    final arm = radius * 0.62 * (1.5 - 0.5 * Curves.easeOut.transform(t));
    final path = Path()
      ..moveTo(center.dx - arm, center.dy - arm)
      ..lineTo(center.dx + arm, center.dy + arm)
      ..moveTo(center.dx + arm, center.dy - arm)
      ..lineTo(center.dx - arm, center.dy + arm);
    Paint stroke(Color color, double width) => Paint()
      ..color = color.withValues(alpha: color.a * t)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.35 * t),
    );
    canvas.drawPath(path, stroke(Colors.white, radius * 0.26));
    canvas.drawPath(path, stroke(const Color(0xFFE5484D), radius * 0.17));
  }

  static void _withDesignSpace(
    Canvas canvas,
    Size size,
    double videoTime,
    VoidCallback paint,
  ) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _style.background);
    canvas.save();
    canvas.scale(
      size.width / designSize.width,
      size.height / designSize.height,
    );
    paint();
    if (_style.visibility.shows(VideoLayer.watermark)) {
      _paintWatermark(canvas, videoTime);
    }
    canvas.restore();
  }

  static TextPainter _watermarkText() => _layout(
    _style.watermarkText,
    32,
    FontWeight.w800,
    _style.text.withValues(alpha: 0.35),
    letterSpacing: 2,
    maxWidth: 680,
  );

  static void _paintWatermark(Canvas canvas, double videoTime) {
    final text = _watermarkText();
    text.paint(canvas, watermarkPosition(videoTime, text.size));
  }

  /// Top-left of the watermark at [videoTime], bouncing inside the frame.
  static Offset watermarkPosition(double videoTime, Size textSize) {
    double bounce(double travelled, double range) {
      if (range <= 0) return 0;
      final p = travelled % (2 * range);
      return p <= range ? p : 2 * range - p;
    }

    return Offset(
      bounce(
        _watermarkStart.dx + videoTime * _watermarkVelocity.dx,
        designSize.width - textSize.width,
      ),
      bounce(
        _watermarkStart.dy + videoTime * _watermarkVelocity.dy,
        designSize.height - textSize.height,
      ),
    );
  }

  static void _paintHeader(Canvas canvas, {required bool dimmed}) {
    _paintText(
      canvas,
      _style.headline,
      64,
      FontWeight.w800,
      _style.text,
      y: 130,
      letterSpacing: 1,
      maxWidth: 680,
    );
    _paintText(
      canvas,
      'ROUND 1',
      30,
      FontWeight.bold,
      _style.muted.withValues(alpha: dimmed ? 0.4 : 1),
      y: 210,
      letterSpacing: 1,
    );
  }

  static void _paintSlowMotionBadge(Canvas canvas, {double y = 275}) {
    final label = _layout(
      'SLOW MOTION',
      22,
      FontWeight.w700,
      _style.text,
      letterSpacing: 2,
    );
    const dotGap = 22.0;
    final width = label.width + dotGap + 32;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(360, y), width: width, height: 40),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = Color.lerp(_style.background, _style.text, 0.09)!,
    );
    final left = rect.left + 16;
    canvas.drawCircle(
      Offset(left + 6, y),
      6,
      Paint()..color = const Color(0xFFFF7A59),
    );
    label.paint(canvas, Offset(left + dotGap, y - label.height / 2));
  }

  static void _paintBallFace(
    Canvas canvas,
    SimulationBall ball,
    Offset center,
    double radius,
  ) {
    if (!_style.visibility.shows(VideoLayer.pictures)) {
      paintSmiley(
        canvas,
        ball,
        faceHealth(ball),
        [ball],
        center: center,
        radius: radius,
        appearance: _style.ballAppearance,
      );
      return;
    }
    BallFacePainter.paint(
      canvas,
      center,
      radius,
      ball.config,
      ball.cachedUiImage,
      rimWidth: 4,
      showInitial: _style.visibility.shows(VideoLayer.names),
    );
  }

  static TextPainter _layout(
    String text,
    double fontSize,
    FontWeight weight,
    Color color, {
    double letterSpacing = 0,
    String? fontFamily,
    double maxWidth = double.infinity,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          // Manrope is a variable font: the weight goes on its wght axis.
          fontVariations: fontFamily == null
              ? [FontVariation('wght', weight.value.toDouble())]
              : null,
          color: color,
          letterSpacing: letterSpacing,
          fontFamily: fontFamily ?? 'Manrope',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  /// Paints [text] horizontally centered with its top at [y].
  static void _paintText(
    Canvas canvas,
    String text,
    double fontSize,
    FontWeight weight,
    Color color, {
    required double y,
    double letterSpacing = 0,
    String? fontFamily,
    double maxWidth = double.infinity,
  }) {
    final painter = _layout(
      text,
      fontSize,
      weight,
      color,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      maxWidth: maxWidth,
    );
    painter.paint(
      canvas,
      Offset(math.max(0, (designSize.width - painter.width) / 2), y),
    );
  }
}

/// The exported video's look: the app's headline and theme colors.
class ReplayStyle {
  final Map<String, String> artworkRevisions;
  final Map<String, Object> artworkFrames;
  final EffectRenderMode effectRenderMode;
  final String headline;
  final Color background;
  final Color text;
  final Color muted;
  final bool ballGlowEnabled;
  final double ballGlowWidth;
  final BallAppearance ballAppearance;
  final Color bloodColor;
  final String arenaTitle;
  final String arenaSubtitle;
  final ArenaDecoration arenaDecoration;
  final ArenaDefinition? arenaPreset;

  /// Ball look (pictures or faces), as in the app.
  final BallLook look;

  /// A thin HP bar above each ball, as in the app.
  final bool showHpBars;
  final VideoVisibility visibility;
  final String watermarkText;

  ReplayStyle forVideo(VideoVisibility options) => ReplayStyle(
    artworkRevisions: artworkRevisions,
    artworkFrames: artworkFrames,
    effectRenderMode: effectRenderMode,
    headline: headline,
    background: background,
    text: text,
    muted: muted,
    ballGlowEnabled: ballGlowEnabled,
    ballGlowWidth: ballGlowWidth,
    ballAppearance: ballAppearance,
    bloodColor: bloodColor,
    arenaTitle: arenaTitle,
    arenaSubtitle: arenaSubtitle,
    arenaPreset: arenaPreset,
    arenaDecoration: arenaDecoration,
    look: look,
    showHpBars: showHpBars,
    visibility: options,
    watermarkText: watermarkText,
  );

  const ReplayStyle({
    this.artworkRevisions = const {},
    this.artworkFrames = const {},
    this.effectRenderMode = EffectRenderMode.sprite,
    this.headline = 'WHO WINS?',
    this.background = const Color(0xFF0A0A0B),
    this.text = const Color(0xFFF2F2F0),
    this.muted = const Color(0xFF959596),
    this.ballGlowEnabled = true,
    this.ballGlowWidth = 4,
    this.ballAppearance = BallAppearance.defaults,
    this.bloodColor = const Color(0xFFD9152B),
    this.arenaTitle = 'dbsuarez',
    this.arenaSubtitle = 'bakbakan na',
    this.arenaDecoration = ArenaDecoration.defaultArena,
    this.arenaPreset,
    this.look = BallLook.pictures,
    this.showHpBars = false,
    this.visibility = const VideoVisibility(),
    this.watermarkText = AppSettings.defaultExportWatermark,
  });
}
