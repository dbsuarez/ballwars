import 'package:flutter/material.dart';
import '../../../ball_management/domain/custom_ball.dart';
import '../../../ball_management/presentation/widgets/circular_ball_preview.dart';

class BallSelectionCarousel extends StatelessWidget {
  final List<CustomBall> availableBalls;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const BallSelectionCarousel({
    super.key,
    required this.availableBalls,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableBalls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final ball = availableBalls[index];
          final isSelected = selectedIds.contains(ball.id);
          return GestureDetector(
            onTap: () => onToggle(ball.id),
            child: Column(
              children: [
                Opacity(
                  opacity: isSelected ? 1.0 : 0.4,
                  child: CircularBallPreview(ball: ball, size: 72),
                ),
                const SizedBox(height: 4),
                Text(ball.name, style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }
}
