import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../match_setup/domain/match_config.dart';
import '../domain/fan_line.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';

/// One row per ball: name, lines held or life (and round wins in a series), and below it either a thin
/// bar of its share of the rim (Threads) or 10 hearts in the ball's color (Arsenal: life; All-Out: the
/// share of its starting threads left).
class ScoreboardOverlay extends StatelessWidget {
  final List<SimulationBall> balls;

  /// Round wins by ball id; null for a single-round match.
  final Map<String, int>? wins;

  final MatchMode mode;

  const ScoreboardOverlay({super.key, required this.balls, this.wins, this.mode = MatchMode.threads});

  /// Health as hearts out of 10, rounded to the nearest half heart. Arsenal life above full (from an
  /// apple) counts past 10.
  double _hearts(SimulationBall ball) {
    if (ball.isEliminated) return 0;
    final ratio = mode == MatchMode.arsenal
        ? (ball.life / PowerUpTuning.arenaLife).clamp(0.0, PowerUpTuning.arenaMaxLife / PowerUpTuning.arenaLife)
        : (ball.startLines == 0 ? 0.0 : ball.lineCount / ball.startLines).clamp(0.0, 1.0);
    return (ratio * 20).round() / 2;
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final ball in balls)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        ball.config.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(14, FontWeight.w700, color: ball.isEliminated ? c.muted : c.text),
                      ),
                    ),
                    Text(_detail(ball), style: AppText.mono(12, color: c.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                if (mode != MatchMode.threads)
                  HeartsRow(hearts: _hearts(ball), color: ball.config.primaryColor, empty: c.border)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ball.lineCount.clamp(0, kRimSlotCount) / kRimSlotCount,
                      color: ball.config.primaryColor,
                      backgroundColor: c.border,
                      minHeight: 4,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _detail(SimulationBall ball) {
    final lines = ball.isEliminated
        ? 'out'
        : mode == MatchMode.arsenal
        ? '${ball.life.round()} life'
        : '${ball.lineCount} lines';
    final w = wins;
    if (w == null) return lines;
    final n = w[ball.config.id] ?? 0;
    return '$lines · $n ${n == 1 ? 'win' : 'wins'}';
  }
}

/// 10 hearts in [color], [hearts] of them filled (halves allowed), the rest as outlines; they empty from
/// the right. Hearts past 10 (extra life from an apple) turn the first hearts gold.
class HeartsRow extends StatelessWidget {
  final double hearts;
  final Color color;
  final Color empty;

  const HeartsRow({super.key, required this.hearts, required this.color, required this.empty});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: CustomPaint(painter: _HeartsPainter(hearts, color, empty), size: Size.infinite),
    );
  }
}

class _HeartsPainter extends CustomPainter {
  final double hearts;
  final Color color;
  final Color empty;

  _HeartsPainter(this.hearts, this.color, this.empty);

  static Path _heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s * 0.85)
    ..cubicTo(c.dx - s * 1.1, c.dy + s * 0.1, c.dx - s * 0.75, c.dy - s * 0.9, c.dx, c.dy - s * 0.35)
    ..cubicTo(c.dx + s * 0.75, c.dy - s * 0.9, c.dx + s * 1.1, c.dy + s * 0.1, c.dx, c.dy + s * 0.85)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 10;
    final s = (size.height / 2).clamp(0.0, step * 0.45);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = empty;
    final fill = Paint()..color = color;
    for (var i = 0; i < 10; i++) {
      final c = Offset(step * i + s + 1, size.height / 2);
      final path = _heart(c, s);
      final f = (hearts - i).clamp(0.0, 1.0);
      if (f >= 1) {
        canvas.drawPath(path, fill);
      } else {
        canvas.drawPath(path, outline);
        if (f > 0) {
          canvas.save();
          canvas.clipRect(Rect.fromLTRB(c.dx - s * 1.2, 0, c.dx, size.height));
          canvas.drawPath(path, fill);
          canvas.restore();
        }
      }
      final extra = (hearts - 10 - i).clamp(0.0, 1.0);
      if (extra > 0) {
        canvas.save();
        if (extra < 1) canvas.clipRect(Rect.fromLTRB(c.dx - s * 1.2, 0, c.dx, size.height));
        canvas.drawPath(path, _gold);
        canvas.restore();
      }
    }
  }

  static final Paint _gold = Paint()..color = const Color(0xFFFFC83D);

  @override
  bool shouldRepaint(_HeartsPainter old) => old.hearts != hearts || old.color != color || old.empty != empty;
}
