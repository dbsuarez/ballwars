import 'package:flutter/material.dart';

class MatchStatusHeader extends StatelessWidget {
  final bool isSlowMotion;
  final String round;
  final bool showIntro;
  final bool isWinScreen;

  const MatchStatusHeader({
    super.key,
    required this.isSlowMotion,
    this.round = 'ROUND 1',
    this.showIntro = true,
    this.isWinScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isWinScreen ? 0.4 : 1.0;

    final children = <Widget>[
      if (showIntro)
        const Text(
          'WHO WINS?',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
      Text(
        round,
        style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
      ),
    ];

    if (isSlowMotion) {
      children.add(const SizedBox(height: 4));
      children.add(const SlowMotionBadge());
    }

    return Opacity(
      opacity: opacity,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// "SLOW MOTION" pill (red dot + label), shown while the match is slowed.
class SlowMotionBadge extends StatelessWidget {
  const SlowMotionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.redAccent, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text(
            'SLOW MOTION',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}
