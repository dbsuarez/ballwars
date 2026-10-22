import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/fan_line.dart';
import '../domain/simulation_ball.dart';

/// One row per ball: name, lines held (and round wins in a series), and a
/// thin bar of its share of the rim in the ball's line color.
class ScoreboardOverlay extends StatelessWidget {
  final List<SimulationBall> balls;

  /// Round wins by ball id; null for a single-round match.
  final Map<String, int>? wins;

  const ScoreboardOverlay({super.key, required this.balls, this.wins});

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
    final lines = ball.isEliminated ? 'out' : '${ball.lineCount} lines';
    final w = wins;
    if (w == null) return lines;
    final n = w[ball.config.id] ?? 0;
    return '$lines · $n ${n == 1 ? 'win' : 'wins'}';
  }
}
