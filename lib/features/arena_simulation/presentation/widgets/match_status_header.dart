import 'package:flutter/material.dart';

class MatchStatusHeader extends StatelessWidget {
  final bool isSlowMotion;
  final String round;

  const MatchStatusHeader({
    super.key,
    required this.isSlowMotion,
    this.round = 'ROUND 1',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'WHO WINS?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        Text(
          round,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        if (isSlowMotion) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.circle, color: Colors.redAccent, size: 8),
              SizedBox(width: 4),
              Text(
                'SLOW MOTION',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
