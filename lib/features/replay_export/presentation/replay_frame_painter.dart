import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../arena_simulation/domain/simulation_ball.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../arena_simulation/presentation/arena_painter.dart';

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
  static const Color _background = Color(0xFF000000);
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
    required double videoTime,
  }) {
    _withDesignSpace(canvas, size, videoTime, () {
      _paintHeader(canvas, dimmed: false);
      if (state.status == MatchStatus.slowMotion) _paintSlowMotionBadge(canvas);

      canvas.save();
      canvas.translate((designSize.width - _arenaSide) / 2, _arenaTop);
      ArenaPainter(state: state, arenaRadius: arenaRadius, rimAngle: 0)
          .paint(canvas, const Size(_arenaSide, _arenaSide));
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
  }) {
    _withDesignSpace(canvas, size, videoTime, () {
      _paintHeader(canvas, dimmed: true);

      const center = Offset(360, 560);
      const radius = 150.0;
      canvas.drawCircle(
        center,
        radius + 6,
        Paint()
          ..color = winner.config.glowColor.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18),
      );
      _paintBallFace(canvas, winner, center, radius);

      _paintText(canvas, winner.config.name.toUpperCase(), 64, FontWeight.w900, Colors.white,
          y: 760, letterSpacing: 2, maxWidth: 680);
      _paintText(canvas, String.fromCharCode(Icons.emoji_events.codePoint), 72, FontWeight.normal, _gold,
          y: 850, fontFamily: Icons.emoji_events.fontFamily);
      _paintText(canvas, 'MATCH TIME ${matchSeconds.toStringAsFixed(1)}s', 28, FontWeight.w600, Colors.white70,
          y: 950, letterSpacing: 1.5);
    });
  }

  static void _withDesignSpace(Canvas canvas, Size size, double videoTime, VoidCallback paint) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    canvas.save();
    canvas.scale(size.width / designSize.width, size.height / designSize.height);
    paint();
    _paintWatermark(canvas, videoTime);
    canvas.restore();
  }

  static TextPainter _watermarkText() =>
      _layout(watermark, 32, FontWeight.w800, Colors.white.withValues(alpha: 0.35), letterSpacing: 2);

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
      bounce(_watermarkStart.dx + videoTime * _watermarkVelocity.dx, designSize.width - textSize.width),
      bounce(_watermarkStart.dy + videoTime * _watermarkVelocity.dy, designSize.height - textSize.height),
    );
  }

  static void _paintHeader(Canvas canvas, {required bool dimmed}) {
    _paintText(canvas, 'WHO WINS?', 64, FontWeight.w900, Colors.white, y: 130, letterSpacing: 1);
    _paintText(canvas, 'ROUND 1', 30, FontWeight.bold, Colors.redAccent.withValues(alpha: dimmed ? 0.4 : 1),
        y: 210, letterSpacing: 1);
  }

  static void _paintSlowMotionBadge(Canvas canvas) {
    final label = _layout('SLOW MOTION', 22, FontWeight.bold, Colors.white, letterSpacing: 2);
    const dotGap = 22.0;
    final width = label.width + dotGap + 32;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(360, 275), width: width, height: 40),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.redAccent,
    );
    final left = rect.left + 16;
    canvas.drawCircle(Offset(left + 6, 275), 6, Paint()..color = Colors.redAccent);
    label.paint(canvas, Offset(left + dotGap, 275 - label.height / 2));
  }

  static void _paintBallFace(Canvas canvas, SimulationBall ball, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..color = ball.config.primaryColor);
    final image = ball.cachedUiImage;
    if (image != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      final initial = ball.config.name.isNotEmpty ? ball.config.name.substring(0, 1).toUpperCase() : '?';
      _paintText(canvas, initial, radius, FontWeight.bold, Colors.white, y: center.dy - radius * 0.6);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white,
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
          color: color,
          letterSpacing: letterSpacing,
          fontFamily: fontFamily,
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
    final painter = _layout(text, fontSize, weight, color,
        letterSpacing: letterSpacing, fontFamily: fontFamily, maxWidth: maxWidth);
    painter.paint(canvas, Offset(math.max(0, (designSize.width - painter.width) / 2), y));
  }
}
