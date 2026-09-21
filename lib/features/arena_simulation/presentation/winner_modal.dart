import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';

class WinnerModal extends StatelessWidget {
  final CustomBall winner;
  final VoidCallback onReplay;
  final VoidCallback onExit;

  const WinnerModal({
    super.key,
    required this.winner,
    required this.onReplay,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          CircularBallPreview(ball: winner, size: 140),
          const SizedBox(height: 16),
          Text(
            winner.name,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeonButton(label: 'REPLAY', onPressed: onReplay, color: winner.primaryColor),
              const SizedBox(width: 16),
              NeonButton(label: 'EXIT', onPressed: onExit),
            ],
          ),
        ],
      ),
    );
  }
}
