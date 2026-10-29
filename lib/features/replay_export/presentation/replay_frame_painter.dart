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

  static const String watermark = 'dbsuarez.github.io';
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
    required double videoTime,
    bool showEffects = true,
    ReplayStyle style = const ReplayStyle(),
  }) {
    _style = style;
    _withDesignSpace(canvas, size, videoTime, () {
      _paintHeader(canvas, dimmed: false);
      if (state.status == MatchStatus.slowMotion) _paintSlowMotionBadge(canvas);

      canvas.save();
      canvas.translate((designSize.width - _arenaSide) / 2, _arenaTop);
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
        arenaTitle: _style.arenaTitle,
        arenaSubtitle: _style.arenaSubtitle,
        arenaDecoration: _style.arenaDecoration,
        background: _style.background,
        rimColor: _style.text,
        look: _style.look,
        showHpBars: _style.showHpBars,
      ).paint(canvas, const Size(_arenaSide, _arenaSide));
      canvas.restore();
    });
  }

  /// The closing winner card.
  static void paintWinnerCard(
    Canvas canvas,
    Size size,
    SimulationBall winner,
    double matchSeconds, {
    required double videoTime,
    ReplayStyle style = const ReplayStyle(),
  }) {
    _style = style;
    _withDesignSpace(canvas, size, videoTime, () {
      _paintHeader(canvas, dimmed: true);
      ConfettiPainter(videoTime).paint(canvas, designSize);

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
        winner.config.name.toUpperCase(),
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
        'MATCH TIME ${matchSeconds.toStringAsFixed(1)}s',
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
        '${winner.config.name.toUpperCase()} FINISHES IT!',
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
    _paintWatermark(canvas, videoTime);
    canvas.restore();
  }

  static TextPainter _watermarkText() => _layout(
    watermark,
    32,
    FontWeight.w800,
    _style.text.withValues(alpha: 0.35),
    letterSpacing: 2,
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

  static void _paintSlowMotionBadge(Canvas canvas) {
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
      Rect.fromCenter(center: const Offset(360, 275), width: width, height: 40),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = Color.lerp(_style.background, _style.text, 0.09)!,
    );
    final left = rect.left + 16;
    canvas.drawCircle(
      Offset(left + 6, 275),
      6,
      Paint()..color = const Color(0xFFFF7A59),
    );
    label.paint(canvas, Offset(left + dotGap, 275 - label.height / 2));
  }

  static void _paintBallFace(
    Canvas canvas,
    SimulationBall ball,
    Offset center,
    double radius,
  ) {
    BallFacePainter.paint(
      canvas,
      center,
      radius,
      ball.config,
      ball.cachedUiImage,
      rimWidth: 4,
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
  final Color bloodColor;
  final String arenaTitle;
  final String arenaSubtitle;
  final ArenaDecoration arenaDecoration;

  /// Ball look (pictures or faces), as in the app.
  final BallLook look;

  /// A thin HP bar above each ball, as in the app.
  final bool showHpBars;

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
    this.bloodColor = const Color(0xFFD9152B),
    this.arenaTitle = 'dbsuarez',
    this.arenaSubtitle = 'bakbakan na',
    this.arenaDecoration = ArenaDecoration.defaultArena,
    this.look = BallLook.pictures,
    this.showHpBars = false,
  });
}
