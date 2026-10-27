import 'package:flutter/painting.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';

/// The optional HP bar drawn above a ball (cosmetic): a dark track, a fill in green, amber or red, and in
/// Arsenal a gold segment for life past full (from apples) up to the match's max life.
class HpBar {
  static const Color green = Color(0xFF3DDC84);
  static const Color amber = Color(0xFFFFB300);
  static const Color red = Color(0xFFE53935);
  static const Color gold = Color(0xFFFFD54F);
  static const Color trackColor = Color(0xB3000000);

  /// The whole bar, centered above the ball.
  final Rect track;

  /// Health from 0 to 1 (life of full life in Arsenal, lines left of the starting lines otherwise).
  final double ratio;

  /// Arsenal life past full, from 0 (full or less) to 1 (the match's max life).
  final double overflow;

  final Color color;

  const HpBar(this.track, this.ratio, this.overflow, this.color);

  Rect get fill =>
      Rect.fromLTWH(track.left, track.top, track.width * ratio, track.height);

  Rect get goldRect => Rect.fromLTWH(
    track.left,
    track.top,
    track.width * overflow,
    track.height,
  );

  static final Paint _track = Paint()..color = trackColor;
  static final Paint _green = Paint()..color = green;
  static final Paint _amber = Paint()..color = amber;
  static final Paint _red = Paint()..color = red;
  static final Paint _gold = Paint()..color = gold;

  /// Draws the bars of every ball still in play, in one pass (call it after the balls so the bars sit
  /// on top). Plain rects, no text.
  static void paintAll(
    Canvas canvas,
    List<SimulationBall> balls, {
    required double maxLife,
  }) {
    for (final ball in balls) {
      final bar = hpBarFor(ball, maxLife: maxLife);
      if (bar == null) continue;
      canvas.drawRect(bar.track, _track);
      if (bar.ratio > 0) {
        canvas.drawRect(
          bar.fill,
          bar.color == green
              ? _green
              : bar.color == amber
              ? _amber
              : _red,
        );
      }
      if (bar.overflow > 0) canvas.drawRect(bar.goldRect, _gold);
    }
  }
}

/// The HP bar for [ball], or null when it is out. Line modes (Threads, All-Out) are told apart from
/// Arsenal by `startLines > 0`.
HpBar? hpBarFor(SimulationBall ball, {required double maxLife}) {
  if (ball.isEliminated) return null;
  final r = ball.radius;
  final width = r * 1.6;
  final height = r * 0.16 < 3 ? 3.0 : r * 0.16;
  final track = Rect.fromCenter(
    center: Offset(ball.position.dx, ball.position.dy - r * 1.35),
    width: width,
    height: height,
  );
  double ratio;
  var overflow = 0.0;
  if (ball.startLines > 0) {
    ratio = (ball.lineCount / ball.startLines).clamp(0.0, 1.0);
  } else {
    const full = PowerUpTuning.arenaLife;
    ratio = (ball.life / full).clamp(0.0, 1.0);
    if (maxLife > full && ball.life > full) {
      overflow = ((ball.life - full) / (maxLife - full)).clamp(0.0, 1.0);
    }
  }
  final color = ratio > 0.5
      ? HpBar.green
      : ratio > 0.25
      ? HpBar.amber
      : HpBar.red;
  return HpBar(track, ratio, overflow, color);
}
