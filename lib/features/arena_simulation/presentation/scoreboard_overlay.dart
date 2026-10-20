import 'package:flutter/material.dart';
import '../domain/simulation_ball.dart';

class ScoreboardOverlay extends StatelessWidget {
  final List<SimulationBall> balls;

  const ScoreboardOverlay({super.key, required this.balls});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: balls.map((ball) {
        final percent = ((ball.lineCount / 360) * 100).round();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${ball.config.name}: $percent%', style: TextStyle(color: ball.config.primaryColor)),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ball.lineCount / 360,
                  color: ball.config.primaryColor,
                  backgroundColor: Colors.white12,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
