import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/scoreboard_overlay.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  testWidgets('renders a percentage label per ball', (tester) async {
    final balls = [
      SimulationBall(
        config: const CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        position: Offset.zero,
        velocity: Offset.zero,
        radius: 20,
        lineCount: 90,
      ),
      SimulationBall(
        config: const CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
        position: Offset.zero,
        velocity: Offset.zero,
        radius: 20,
        lineCount: 45,
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ScoreboardOverlay(balls: balls)),
    ));

    expect(find.text('A: 50%'), findsOneWidget);
    expect(find.text('B: 25%'), findsOneWidget);
  });
}
