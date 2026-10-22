import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/scoreboard_overlay.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

SimulationBall _ball(String id, int lines) => SimulationBall(
      config: CustomBall(id: id, name: id.toUpperCase(), primaryColor: Colors.red, glowColor: Colors.pink),
      position: Offset.zero,
      velocity: Offset.zero,
      radius: 20,
      lineCount: lines,
    );

void main() {
  testWidgets('shows each ball with its lines, and round wins in a series', (tester) async {
    final balls = [_ball('a', 90), _ball('b', 45)..isEliminated = true];

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScoreboardOverlay(balls: balls))));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('90 lines'), findsOneWidget);
    expect(find.text('out'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ScoreboardOverlay(balls: balls, wins: const {'a': 1}))),
    );
    expect(find.text('90 lines · 1 win'), findsOneWidget);
    expect(find.text('out · 0 wins'), findsOneWidget);
  });
}
